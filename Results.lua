local ADDON, ns = ...

-- Results: Finder's plain results become rows for the window. Pure: no
-- client calls. Every field of a result may be nil (a secret that Finder
-- converted), so every read is checked by type.

local Results = {}
ns.Results = Results

local Memory = ns.Memory

local FIT_RANK = { FITS = 0, HIGH = 1, LOW = 2 }
local NO_FIT = 3

local ROLE_NAMES = { TANK = true, HEALER = true, DAMAGER = true }

function Results.MyRole()
    local override = ns.Settings.Get("roleOverride")
    if ROLE_NAMES[override] then return override end
    if type(GetSpecialization) == "function" and type(GetSpecializationRole) == "function" then
        local ok, role = pcall(function() return GetSpecializationRole(GetSpecialization()) end)
        if ok and ROLE_NAMES[role] then return role end
    end
    if type(UnitGroupRolesAssigned) == "function" then
        local role = UnitGroupRolesAssigned("player")
        if ROLE_NAMES[role] then return role end
    end
    return "DAMAGER"
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

local function buildRow(r, myRole)
    local members = type(r.members) == "table" and r.members or {}
    local player = isPlayer(r)
    local first = members[1] or {}
    local counts = type(r.counts) == "table" and r.counts or {}
    local remaining = counts[myRole .. "_REMAINING"]
    local leader = r.leaderName
    if player and type(leader) ~= "string" then leader = first.name end
    local key = Memory.Key(r)
    return {
        id = r.id, kind = player and "PLAYER" or "GROUP",
        activityIDs = r.activityIDs, leader = leader, comment = r.comment, age = r.age,
        members = members, counts = counts,
        freeForMe = type(remaining) == "number" and remaining > 0,
        friend = r.friends, guild = r.guild,
        seen = Memory.IsSeen(key),
        area = player and first.area or nil,
        roles = player and first.lfgRoles or nil,
        delisted = r.isDelisted,
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

function Results.Build(results, ctx)
    local filters = ctx.filters or {}
    local text = type(filters.text) == "string" and filters.text ~= "" and filters.text:lower() or nil
    local out = { groups = {}, players = {} }
    for _, r in ipairs(results or {}) do
        local row = buildRow(r, ctx.myRole)
        row.fit = bestFit(row.activityIDs, ctx.activityFit)
        local keep = not Memory.IsIgnored(row.leader) and not Memory.IsHidden(row.key)
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
