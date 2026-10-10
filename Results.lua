local ADDON, ns = ...

-- Results: Finder's plain results become rows for the window. Pure: no
-- client calls. Every field of a result may be nil (a secret that Finder
-- converted), so every read is checked by type.

local Results = {}
ns.Results = Results

local Memory = ns.Memory

local FIT_RANK = { FITS = 0, HIGH = 1, LOW = 2 }
local NO_FIT = 3

-- Room for me: a free place for any of my roles ("TANK", "HEALER", "DAMAGER").
local function roomFor(counts, myRoles)
    for _, role in ipairs(myRoles) do
        local remaining = counts[role .. "_REMAINING"]
        if type(remaining) == "number" and remaining > 0 then return true end
    end
    return false
end

-- No room for me: the counts name every one of my roles and none has a
-- free place. Unknown counts are not "no room".
local function noRoomFor(counts, myRoles)
    if #myRoles == 0 then return false end
    for _, role in ipairs(myRoles) do
        local remaining = counts[role .. "_REMAINING"]
        if type(remaining) ~= "number" or remaining > 0 then return false end
    end
    return true
end

-- The best (lowest rank) fit of the activities; nil when none is known.
local function bestFit(ids, activityFit)
    local best, rank = nil, NO_FIT
    if type(ids) ~= "table" or not activityFit then return nil end
    for _, id in ipairs(ids) do
        local fit = activityFit(id)
        local r = FIT_RANK[fit]
        if r and r < rank then best, rank = fit, r end
    end
    return best
end

local function activityText(ids)
    local names = {}
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            local name = ns.Activities and ns.Activities.Name(id)
            if type(name) == "string" then names[#names + 1] = name:lower() end
        end
    end
    return table.concat(names, "\n")
end

local function isPlayer(r)
    local members = type(r.members) == "table" and r.members or {}
    return r.numMembers == 1 and #members <= 1
end

local function buildRow(r, myRoles)
    local members = type(r.members) == "table" and r.members or {}
    local player = isPlayer(r)
    local first = members[1] or {}
    local counts = type(r.counts) == "table" and r.counts or {}
    local leader = r.leaderName
    if player and type(leader) ~= "string" then leader = first.name end
    local key = Memory.Key(r)
    return {
        id = r.id, kind = player and "PLAYER" or "GROUP",
        activityIDs = r.activityIDs, leader = leader, comment = r.comment, age = r.age,
        members = members, counts = counts,
        freeForMe = not player and roomFor(counts, myRoles),
        noRoom = not player and noRoomFor(counts, myRoles),
        friend = r.friends, guild = r.guild,
        seen = Memory.IsSeen(key),
        area = player and first.area or nil,
        roles = player and first.lfgRoles or nil,
        delisted = r.isDelisted,
        voice = r.voiceMode, newPlayerFriendly = r.newPlayerFriendly,
        key = key,
    }
end

local function matchesText(row, text)
    if type(row.comment) == "string" and row.comment:lower():find(text, 1, true) then return true end
    if type(row.leader) == "string" and row.leader:lower():find(text, 1, true) then return true end
    return activityText(row.activityIDs):find(text, 1, true) ~= nil
end

local function positive(n) return type(n) == "number" and n > 0 end

-- Friends or guild members listed: the two sort together.
local function known(row) return positive(row.friend) or positive(row.guild) end

local function sorter(friendsFirst)
    return function(a, b)
        if friendsFirst then
            local ka, kb = known(a), known(b)
            if ka ~= kb then return ka end
        end
        if a.freeForMe ~= b.freeForMe then return a.freeForMe end
        local fa, fb = FIT_RANK[a.fit] or NO_FIT, FIT_RANK[b.fit] or NO_FIT
        if fa ~= fb then return fa < fb end
        local ga, gb = a.age or math.huge, b.age or math.huge   -- plain: our row, Finder already cleaned it
        if ga ~= gb then return ga < gb end
        return (a.id or 0) < (b.id or 0)   -- plain: our row
    end
end

-- The checked activities (a set): a row matches when any of its activities
-- is checked; with none checked, when any is in the category (an activity
-- of unknown category counts as in it).
local function matchesActivities(row, checked, categoryID, categoryOf)
    local ids = type(row.activityIDs) == "table" and row.activityIDs or {}   -- plain: Finder converted the row
    if next(checked) ~= nil then
        for _, id in ipairs(ids) do
            if checked[id] then return true end
        end
        return false
    end
    if not (categoryID and categoryOf) then return true end
    if #ids == 0 then return true end
    for _, id in ipairs(ids) do
        local c = categoryOf(id)
        if c == nil or c == categoryID then return true end
    end
    return false
end

function Results.Build(results, ctx)
    local filters = ctx.filters or {}
    local text = type(filters.text) == "string" and filters.text ~= "" and filters.text:lower() or nil
    local out = { groups = {}, players = {} }
    -- ctx.myRoles: my selected roles; ns.Roles.List() by default.
    local myRoles = ctx.myRoles or ns.Roles.List()
    for _, r in ipairs(results or {}) do
        local row = buildRow(r, myRoles)
        row.fit = bestFit(row.activityIDs, ctx.activityFit)
        local keep = not Memory.IsIgnored(row.leader) and not Memory.IsHidden(row.key)
        if keep and filters.activities and not matchesActivities(row, filters.activities, filters.categoryID, ctx.activityCategory) then keep = false end
        if keep and filters.myRole and row.kind == "GROUP" and not row.freeForMe then keep = false end
        if keep and filters.levelFits and row.fit ~= nil and row.fit ~= "FITS" then keep = false end
        if keep and filters.hideSeen and row.seen then keep = false end
        if keep and text and not matchesText(row, text) then keep = false end
        if keep then
            local list = row.kind == "PLAYER" and out.players or out.groups
            list[#list + 1] = row
        end
    end
    local sort = sorter(ns.Settings.Get("sortFriendsFirst"))
    table.sort(out.groups, sort)
    table.sort(out.players, sort)
    return out
end
