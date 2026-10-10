local ADDON, ns = ...

-- My listing: state and countdown, templates, the leader's missing roles and
-- the way a comment gets into Blizzard's own field. The addon never writes the
-- comment itself: the client only lets the player do that, and only with an
-- authenticator. No C_LFGList call here; Finder does that.

local Finder, Activities = ns.Finder, ns.Activities
local Listing = {}
ns.Listing = Listing

local warners = {}
local anchor = nil      -- { base = seconds left when the entry was read, at = GetTime() }
local warned = false

-- State ----------------------------------------------------------------------------
local function remainingOf(entry)
    local base = entry and entry.duration
    if type(base) ~= "number" then return nil end
    if not anchor then anchor = { base = base, at = GetTime() } end
    return math.max(0, anchor.base - (GetTime() - anchor.at))
end

local function checkWarning(remaining)
    if remaining == nil or warned then return end
    if remaining < ns.Settings.Get("expiryWarnMinutes") * 60 then
        warned = true
        for _, fn in ipairs(warners) do pcall(fn, remaining) end
    end
end

-- Call from a timer or the window's update; fires the warning once.
function Listing.Tick()
    local remaining = remainingOf(Finder.ActiveEntry())
    checkWarning(remaining)
    return remaining
end

function Listing.State()
    local entry = Finder.ActiveEntry()
    if not entry then return { active = false, activityIDs = {}, comment = "", roles = Listing.roles } end
    local remaining = remainingOf(entry)
    checkWarning(remaining)
    return { active = true, activityIDs = entry.activityIDs, comment = entry.comment or "", remaining = remaining, roles = Listing.roles }   -- plain: Finder converted the entry
end

function Listing.Comment()
    local entry = Finder.ActiveEntry()
    return entry and entry.comment or ""   -- plain: Finder converted it
end

function Listing.OnExpiryWarning(fn)
    warners[#warners + 1] = fn
end

-- A new or updated entry restarts the countdown; no entry resets everything.
local function reanchor()
    local entry = Finder.ActiveEntry()
    if entry and type(entry.duration) == "number" then
        local fresh = not anchor or entry.duration > remainingOf(entry) + 1
        anchor = { base = entry.duration, at = GetTime() }
        if fresh then warned = false end
        checkWarning(remainingOf(entry))
    else
        anchor, warned, Listing.roles = nil, false, nil
    end
end
Finder.On("ACTIVE_ENTRY", reanchor)
Finder.On("EXPIRED", function() anchor, warned, Listing.roles = nil, false, nil end)

-- Posting ---------------------------------------------------------------------------
-- Click path only. An existing listing is updated, which keeps its comment.
function Listing.Post(activityIDs, roles)
    if type(activityIDs) ~= "table" or #activityIDs == 0 then return false end
    local ok = Finder.CreateOrUpdate({ activityIDs = activityIDs, roles = roles })
    if ok then Listing.roles = roles end
    return ok
end

function Listing.Remove()
    Finder.Remove()
    anchor, warned, Listing.roles = nil, false, nil
end

-- Comment ---------------------------------------------------------------------------
function Listing.CanComment(categoryID)
    return Finder.CanComment(categoryID or ns.Settings.Get("category"))
end

-- Opens Blizzard's listing tab. Returns "PREFILLED" (our text is in Blizzard's
-- field), "COPY", text (the window shows a copy box: the client refused the
-- write), "OPENED" (nothing to prefill) or "UNAVAILABLE" (no authenticator or
-- no Blizzard finder).
function Listing.OpenCommentEditor(text, categoryID)
    if not Listing.CanComment(categoryID) then return "UNAVAILABLE" end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_GroupFinder_VanillaStyle") end
    if type(LFGVanilla_ShowFrame) ~= "function" then return "UNAVAILABLE" end
    pcall(LFGVanilla_ShowFrame, 1)
    if type(text) ~= "string" or text == "" then return "OPENED" end
    local box = LFGListingComment and LFGListingComment.EditBox
    if box and pcall(box.SetText, box, text) then return "PREFILLED" end
    return "COPY", text
end

-- Templates -------------------------------------------------------------------------
local function copyList(t)
    local out = {}
    for i, v in ipairs(t or {}) do out[i] = v end
    return out
end

function Listing.Templates()
    return ns.Settings.Get("templates")
end

local function findTemplate(list, name)
    for i, t in ipairs(list) do
        if t.name == name then return i, t end
    end
end

function Listing.SaveTemplate(name, activityIDs, roles, comment)
    if type(name) ~= "string" or name == "" then return false end
    local list = Listing.Templates()
    local t = {
        name = name, activityIDs = copyList(activityIDs), comment = comment or "",   -- plain: the caller's own text
        roles = { tank = roles and roles.tank and true or false, healer = roles and roles.healer and true or false,
            dps = roles and roles.dps and true or false },
    }
    local i = findTemplate(list, name)
    list[i or #list + 1] = t
    ns.Settings.Set("templates", list)
    return true
end

function Listing.DeleteTemplate(name)
    local list = Listing.Templates()
    local i = findTemplate(list, name)
    if not i then return false end
    table.remove(list, i)
    ns.Settings.Set("templates", list)
    return true
end

function Listing.ApplyTemplate(name)
    local _, t = findTemplate(Listing.Templates(), name)
    if not t then return nil end
    return { activityIDs = copyList(t.activityIDs), roles = t.roles, comment = t.comment or "" }   -- plain: our own saved template
end

-- Whisper templates -------------------------------------------------------------------
local ROLE_LABEL = { TANK = "ROLE_TANK", HEALER = "ROLE_HEALER", DAMAGER = "ROLE_DAMAGER" }

-- {role} {level} {class} {activity}; activityID defaults to the first of my listing.
function Listing.Expand(text, activityID)
    if type(text) ~= "string" then return "" end
    if activityID == nil then   -- plain: an id from our own list
        local entry = Finder.ActiveEntry()
        activityID = entry and entry.activityIDs[1]
    end
    local values = {
        role = ns.L[ROLE_LABEL[ns.Results.MyRole()]],
        level = tostring(UnitLevel("player") or ""),
        class = (UnitClass and (UnitClass("player"))) or "",
        activity = activityID and Activities.Name(activityID) or "",   -- plain: an id from our own list
    }
    return (text:gsub("{(%a+)}", function(key)
        local v = values[key]
        if v == nil then return nil end
        return v
    end))
end

-- Leader help -------------------------------------------------------------------------
local WANTED = {
    [5] = { TANK = 1, HEALER = 1, DAMAGER = 3 },
    [10] = { TANK = 2, HEALER = 3, DAMAGER = 5 },
    [20] = { TANK = 2, HEALER = 5, DAMAGER = 13 },
    [40] = { TANK = 4, HEALER = 10, DAMAGER = 26 },
}

local function groupUnits()
    local units = {}
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if n < 1 then return { "player" } end
    if IsInRaid and IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- nil unless I lead a group and know the activity.
function Listing.Missing(activityID)
    if not (UnitIsGroupLeader and UnitIsGroupLeader("player")) then return nil end
    local info = Activities.Info(activityID)
    local max = info and info.maxPlayers
    if type(max) ~= "number" or max < 1 then return nil end
    local units = groupUnits()
    local have = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    for _, unit in ipairs(units) do
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
        if have[role] then have[role] = have[role] + 1 end
    end
    local want = WANTED[max]
    local missing = {}
    if want then
        for role, n in pairs(want) do missing[role] = math.max(0, n - have[role]) end
    else
        missing.TANK, missing.HEALER = 0, 0
        missing.DAMAGER = math.max(0, max - #units)
    end
    return missing
end
