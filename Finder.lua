local ADDON, ns = ...

-- Finder: the only file that calls C_LFGList. Everything the client hands out
-- may be a secret value, so every field is converted once, here, and the rest
-- of the addon only ever sees plain values or nil.

local Finder = {}
ns.Finder = Finder

local PENDING_TIMEOUT = 10     -- a search the client swallowed must not block us forever
local MAX_MEMBERS = 40

local pending, lastSearch = false, nil
local lastQuery = nil   -- QueryKey of the search in flight / last issued
local pendingSince = 0

-- A value as the addon may use it: secrets become nil.
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function plainList(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for i = 1, #list do out[i] = plain(list[i]) end
    return out
end

-- Events --------------------------------------------------------------------------
local listeners = {}
function Finder.On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

local function fire(event, ...)
    for _, fn in ipairs(listeners[event] or {}) do
        pcall(fn, ...)
    end
end

ns.On("LFG_LIST_SEARCH_RESULTS_RECEIVED", function()
    pending = false
    fire("RESULTS")
end)
ns.On("LFG_LIST_SEARCH_RESULT_UPDATED", function(_, id) fire("RESULT_UPDATED", plain(id)) end)
ns.On("LFG_LIST_SEARCH_FAILED", function(_, reason)
    pending = false
    fire("FAILED", plain(reason))
end)
ns.On("LFG_LIST_ACTIVE_ENTRY_UPDATE", function() fire("ACTIVE_ENTRY") end)
ns.On("LFG_LIST_AVAILABILITY_UPDATE", function() fire("AVAILABILITY") end)
ns.On("LFG_LIST_ENTRY_EXPIRED_TIMEOUT", function() fire("EXPIRED") end)
ns.On("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS", function() fire("EXPIRED") end)

-- Search ---------------------------------------------------------------------------
function Finder.IsSearching()
    return pending and (GetTime() - pendingSince) < PENDING_TIMEOUT
end

function Finder.LastSearchAge()
    if not lastSearch then return nil end
    return GetTime() - lastSearch
end

-- One string per query: category, sorted activities, sorted languages.
-- opts as Search takes them.
function Finder.QueryKey(opts)
    local ids, langs = {}, {}
    for _, id in ipairs(opts.activityIDs or {}) do ids[#ids + 1] = id end   -- plain: our own query
    table.sort(ids)
    for code, on in pairs(opts.languages or {}) do
        if on then langs[#langs + 1] = code end
    end
    table.sort(langs)
    return tostring(opts.categoryID) .. "|" .. table.concat(ids, ",") .. "|" .. table.concat(langs, ",")
end

-- The query of the search in flight, or of the last one issued; its
-- results are the next (or the last) RESULTS.
function Finder.LastQuery() return lastQuery end

-- Blizzard's finder issues a search in this click (Blizzard.lua): count it
-- as ours (pending, the interval) without a second C_LFGList.Search. Its
-- query is Blizzard's, unknown here: "blizzard" never equals ours.
function Finder.ExpectSearch()
    lastSearch = GetTime()
    pending, pendingSince = true, lastSearch
    lastQuery = "blizzard"
end

-- Call from a click or key press only: the client blocks Search otherwise.
-- opts = { categoryID, activityIDs (may be empty), languages (set of locale -> true, or nil) }
function Finder.Search(opts)
    if Finder.IsSearching() then return false, "pending" end
    if lastSearch and (GetTime() - lastSearch) < ns.Settings.Get("minInterval") then
        return false, "throttled"
    end
    local activityIDs = opts.activityIDs
    if activityIDs and #activityIDs == 0 then activityIDs = nil end   -- plain: our own list; nil searches the whole category
    local languageFilter
    if opts.languages and next(opts.languages) ~= nil then
        languageFilter = {}
        for locale, on in pairs(opts.languages) do
            if on then languageFilter[locale] = true end
        end
        if next(languageFilter) == nil then languageFilter = nil end
    end
    lastSearch = GetTime()
    pending, pendingSince = true, lastSearch
    lastQuery = Finder.QueryKey(opts)
    C_LFGList.Search(opts.categoryID, 0, 0, languageFilter, false, nil, activityIDs)
    return true
end

-- Results --------------------------------------------------------------------------
local function readMember(m)
    local roles = m.lfgRoles
    local wanted
    if type(roles) == "table" then
        wanted = { tank = plain(roles.tank), healer = plain(roles.healer), dps = plain(roles.dps) }
    end
    return {
        name = plain(m.name), level = plain(m.level), classFile = plain(m.classFilename),
        role = plain(m.assignedRole), lfgRoles = wanted, area = plain(m.areaName), isLeader = plain(m.isLeader),
    }
end

local COUNT_KEYS = { "TANK", "HEALER", "DAMAGER", "TANK_REMAINING", "HEALER_REMAINING", "DAMAGER_REMAINING" }

local function sum(a, b)
    if a == nil or b == nil then return nil end   -- plain: counts from count()
    return a + b
end

function Finder.Result(id)
    if not C_LFGList.HasSearchResultInfo(id) then return nil end
    local info = C_LFGList.GetSearchResultInfo(id)
    if not info then return nil end
    -- a missing number counts as zero, a secret one makes the sum unknown
    local function count(v)
        if issecretvalue and issecretvalue(v) then return nil end
        return v or 0
    end
    local r = {
        id = id,
        activityIDs = plainList(info.activityIDs),
        leaderName = plain(info.leaderName),
        comment = plain(info.comment),
        numMembers = plain(info.numMembers),
        age = plain(info.age),
        friends = sum(count(info.numCharFriends), count(info.numBNetFriends)),
        guild = count(info.numGuildMates),
        isDelisted = plain(info.isDelisted),
        voiceMode = plain(info.voiceMode),
        newPlayerFriendly = plain(info.newPlayerFriendly),
        members = {},
        counts = {},
    }
    -- A solo listing may carry its name only in the leader info (Blizzard's
    -- browse rows read GetSearchResultLeaderInfo too).
    local leader
    local function leaderInfo()
        if leader == nil then
            leader = (C_LFGList.GetSearchResultLeaderInfo and C_LFGList.GetSearchResultLeaderInfo(id)) or false
        end
        return leader or nil
    end
    if type(r.leaderName) ~= "string" then
        local li = leaderInfo()
        if li then r.leaderName = plain(li.name) end
    end
    local n = r.numMembers
    if type(n) == "number" then
        for i = 1, math.min(n, MAX_MEMBERS) do
            local m = C_LFGList.GetSearchResultPlayerInfo(id, i)
            if m then r.members[#r.members + 1] = readMember(m) end
        end
    end
    -- The first member without a name is the leader (solo listings).
    local first = r.members[1]
    if first and type(first.name) ~= "string" and type(r.leaderName) == "string" and r.numMembers == 1 then   -- plain: converted above
        first.name = r.leaderName
    end
    if first and r.numMembers == 1 and type(first.classFile) ~= "string" then   -- plain: converted above
        local li = leaderInfo()
        if li then
            local extra = readMember(li)
            for k, v in pairs(extra) do
                if first[k] == nil then first[k] = v end
            end
        end
    end
    if not first and r.numMembers == 1 then   -- plain: converted above
        local li = leaderInfo()
        if li then
            r.members[1] = readMember(li)
            if type(r.members[1].name) ~= "string" then r.members[1].name = r.leaderName end
        end
    end
    local counts = C_LFGList.GetSearchResultMemberCounts and C_LFGList.GetSearchResultMemberCounts(id)
    if type(counts) == "table" then
        for _, key in ipairs(COUNT_KEYS) do r.counts[key] = plain(counts[key]) end
    end
    return r
end

function Finder.Results()
    local out = {}
    local _, ids = C_LFGList.GetSearchResults()
    for _, id in ipairs(ids or {}) do
        local r = Finder.Result(id)
        if r then out[#out + 1] = r end
    end
    return out
end

-- Activities (read-only) -----------------------------------------------------------
function Finder.Categories()
    return plainList(C_LFGList.GetAvailableCategories()) or {}
end

function Finder.CategoryInfo(id)
    local info = C_LFGList.GetLfgCategoryInfo(id)
    if not info then return nil end
    return { name = plain(info.name) }
end

function Finder.ActivityGroupName(groupID)
    local name = C_LFGList.GetActivityGroupInfo(groupID)
    return plain(name)
end

-- groupID is optional: nil lists the whole category
function Finder.Activities(categoryID, groupID)
    return plainList(C_LFGList.GetAvailableActivities(categoryID, groupID)) or {}
end

function Finder.ActivityInfo(id)
    local a = C_LFGList.GetActivityInfoTable(id)
    if not a then return nil end
    return {
        categoryID = plain(a.categoryID), groupFinderActivityGroupID = plain(a.groupFinderActivityGroupID),
        fullName = plain(a.fullName), shortName = plain(a.shortName),
        minLevelSuggestion = plain(a.minLevelSuggestion), maxLevelSuggestion = plain(a.maxLevelSuggestion),
        maxNumPlayers = plain(a.maxNumPlayers),
    }
end

-- My listing ------------------------------------------------------------------------
function Finder.ActiveEntry()
    if not C_LFGList.HasActiveEntryInfo() then return nil end
    local e = C_LFGList.GetActiveEntryInfo()
    if not e then return nil end
    return {
        activityIDs = plainList(e.activityIDs) or {},
        comment = plain(e.comment),
        duration = plain(e.duration),
        newPlayerFriendly = plain(e.newPlayerFriendly),
        voiceMode = plain(e.voiceMode),
    }
end

-- Call from a click. entry = { activityIDs, newPlayerFriendly, generalPlaystyle, voiceMode, roles }
function Finder.CreateOrUpdate(entry)
    local ok
    if C_LFGList.HasActiveEntryInfo() then
        ok = C_LFGList.UpdateListing({
            activityIDs = entry.activityIDs,
            newPlayerFriendly = entry.newPlayerFriendly,
            voiceMode = entry.voiceMode,
        })
    else
        ok = C_LFGList.CreateListing({
            activityIDs = entry.activityIDs,
            newPlayerFriendly = entry.newPlayerFriendly,
            generalPlaystyle = entry.generalPlaystyle or 0,   -- plain: ours
            voiceMode = entry.voiceMode,
        })
    end
    ok = ok and true or false
    if ok and entry.roles and C_LFGListRoles and C_LFGListRoles.SetRoles then
        C_LFGListRoles.SetRoles(entry.roles)
    end
    return ok
end

-- The roles Blizzard's finder remembers for a solo listing (GetSavedRoles,
-- else GetRoles) as { tank, healer, dps }; nil when it has none.
function Finder.SavedRoles()
    if not C_LFGListRoles then return nil end
    for _, getter in ipairs({ C_LFGListRoles.GetSavedRoles, C_LFGListRoles.GetRoles }) do
        local ok, r = false, nil
        if type(getter) == "function" then ok, r = pcall(getter) end
        if ok and type(r) == "table" then
            local out = { tank = plain(r.tank) == true, healer = plain(r.healer) == true, dps = plain(r.dps) == true }
            if out.tank or out.healer or out.dps then return out end
        end
    end
    return nil
end

function Finder.Remove()
    C_LFGList.RemoveListing()
end

function Finder.CanComment(categoryID)
    if not C_LFGList.IsPlayerAuthenticatedForLFG then return false end
    return C_LFGList.IsPlayerAuthenticatedForLFG(categoryID) and true or false
end

-- Contact ---------------------------------------------------------------------------
function Finder.Invite(name)
    C_PartyInfo.InviteUnit(name)
end

function Finder.Whisper(name, text)
    if text and text ~= "" and ChatFrameUtil and ChatFrameUtil.SendTellWithMessage then
        ChatFrameUtil.SendTellWithMessage(name, text)
    elseif ChatFrameUtil and ChatFrameUtil.SendTell then
        ChatFrameUtil.SendTell(name)
    elseif ChatFrame_SendTell then
        ChatFrame_SendTell(name)
    end
end

function Finder.CanUse()
    if not (C_LFGInfo and C_LFGInfo.CanPlayerUsePremadeGroup) then return false, "unavailable" end
    local canUse, reason = C_LFGInfo.CanPlayerUsePremadeGroup()
    return canUse and true or false, plain(reason)
end
