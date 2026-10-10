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
        playstyle = ns.Playstyle.Valid(r.generalPlaystyle) and r.generalPlaystyle or nil,   -- plain: Finder converted the row
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

-- Players: by role (Tank, Healer, DPS; several roles count as the first
-- of them; none last), then level, highest first; or by level only; or
-- newest first. Ties: level, then age, then id. Friends and guild first
-- with friendsFirst.
local ROLE_RANK = { tank = 1, healer = 2, dps = 3 }
Results.PLAYER_SORTS = { "ROLE", "LEVEL", "NEWEST" }

local function roleRank(row)
    local roles = type(row.roles) == "table" and row.roles or {}   -- plain: Finder converted the row
    local best = 4
    for key, rank in pairs(ROLE_RANK) do
        if roles[key] == true and rank < best then best = rank end
    end
    return best
end

local function levelOf(row)
    local m = type(row.members) == "table" and row.members[1] or nil   -- plain: Finder converted the row
    return m and type(m.level) == "number" and m.level or 0   -- plain: Finder converted the row
end

function Results.PlayerSorter(mode, friendsFirst)
    return function(a, b)
        if friendsFirst then
            local ka, kb = known(a), known(b)
            if ka ~= kb then return ka end
        end
        if mode == "ROLE" then
            local ra, rb = roleRank(a), roleRank(b)
            if ra ~= rb then return ra < rb end
        end
        if mode ~= "NEWEST" then
            local la, lb = levelOf(a), levelOf(b)
            if la ~= lb then return la > lb end
        end
        local ga, gb = a.age or math.huge, b.age or math.huge   -- plain: our row, Finder already cleaned it
        if ga ~= gb then return ga < gb end
        return (a.id or 0) < (b.id or 0)   -- plain: our row
    end
end

-- Group rows in one section per activity: { id = activityID or false,
-- rows = { ... } }. A group goes once, into the section of its first
-- activity that is checked (its first activity when nothing is checked).
-- Sections follow order (activity ids as the activity list shows them),
-- unknown ones after, by id; rows keep their order. Pure.
function Results.Sections(groups, checked, order)
    local checkedSet = {}
    for _, id in ipairs(checked or {}) do checkedSet[id] = true end
    local anyChecked = next(checkedSet) ~= nil
    local byID, sections = {}, {}
    for _, row in ipairs(groups or {}) do
        local ids = type(row.activityIDs) == "table" and row.activityIDs or {}   -- plain: Finder converted the row
        local key = false
        for _, id in ipairs(ids) do
            if not anyChecked or checkedSet[id] then key = id; break end
        end
        if key == false and ids[1] then key = ids[1] end
        local section = byID[key]
        if not section then
            section = { id = key, rows = {} }
            byID[key] = section
            sections[#sections + 1] = section
        end
        section.rows[#section.rows + 1] = row
    end
    local rank = {}
    for i, id in ipairs(order or {}) do rank[id] = i end
    table.sort(sections, function(a, b)
        local ra, rb = rank[a.id] or math.huge, rank[b.id] or math.huge
        if ra ~= rb then return ra < rb end
        local ia, ib = a.id or math.huge, b.id or math.huge   -- plain: our own value
        return ia < ib
    end)
    return sections
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
        -- filters.playstyles: a set of playstyles; nil or empty keeps all.
        if keep and type(filters.playstyles) == "table" and next(filters.playstyles) ~= nil
            and not (row.playstyle and filters.playstyles[row.playstyle]) then keep = false end   -- plain: our own value
        if keep and text and not matchesText(row, text) then keep = false end
        if keep then
            local list = row.kind == "PLAYER" and out.players or out.groups
            list[#list + 1] = row
        end
    end
    local sort = sorter(ns.Settings.Get("sortFriendsFirst"))
    table.sort(out.groups, sort)
    table.sort(out.players, Results.PlayerSorter(ns.Settings.Get("playerSort"), ns.Settings.Get("sortFriendsFirst")))
    return out
end
