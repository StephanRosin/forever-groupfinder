local ADDON, ns = ...
local L = ns.L

-- My roles: the role toggles in "My listing" are the one source of them.
-- Only roles the class can play are offered (UnitGetAvailableRoles, else a
-- table per class). The selection is stored per character; until the player
-- picks one it comes from Blizzard's saved listing roles, else the group
-- role assigned to me, else the first role the class can play.
local Roles = {}
ns.Roles = Roles

Roles.KEYS = { "tank", "healer", "dps" }
Roles.ID = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }
Roles.KEY = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
Roles.LABEL = { tank = "ROLE_TANK", healer = "ROLE_HEALER", dps = "ROLE_DAMAGER" }

-- What a class can play when the client cannot tell us.
Roles.CLASS = {
    WARRIOR = { tank = true, dps = true },
    PALADIN = { tank = true, healer = true, dps = true },
    DRUID = { tank = true, healer = true, dps = true },
    PRIEST = { healer = true, dps = true },
    SHAMAN = { healer = true, dps = true },
    ROGUE = { dps = true }, MAGE = { dps = true }, WARLOCK = { dps = true }, HUNTER = { dps = true },
}

local function store()
    ForeverGroupFinderChar = ForeverGroupFinderChar or {}
    return ForeverGroupFinderChar
end

local function any(set)
    return set.tank == true or set.healer == true or set.dps == true
end

-- { tank, healer, dps } = true for every role the class can play.
function Roles.Allowed()
    if type(UnitGetAvailableRoles) == "function" then
        local ok, tank, healer, dps = pcall(UnitGetAvailableRoles, "player")
        if ok then
            local set = { tank = tank == true, healer = healer == true, dps = dps == true }
            if any(set) then return set end
        end
    end
    local class = UnitClass and select(2, UnitClass("player"))
    local fixed = type(class) == "string" and Roles.CLASS[class]
    if fixed then
        return { tank = fixed.tank == true, healer = fixed.healer == true, dps = fixed.dps == true }
    end
    return { tank = true, healer = true, dps = true }
end

local function firstAllowed(allowed)
    for _, k in ipairs(Roles.KEYS) do
        if allowed[k] then return { [k] = true } end
    end
    return { dps = true }
end

local function clean(set, allowed)
    local out = {}
    for _, k in ipairs(Roles.KEYS) do out[k] = (type(set) == "table" and set[k] == true and allowed[k]) and true or false end
    return out
end

local function default(allowed)
    local saved = ns.Finder.SavedRoles()
    if saved then
        local set = clean(saved, allowed)
        if any(set) then return set end
    end
    if UnitGroupRolesAssigned then
        local key = Roles.KEY[UnitGroupRolesAssigned("player")]
        if key and allowed[key] then return clean({ [key] = true }, allowed) end
    end
    return clean(firstAllowed(allowed), allowed)
end

-- My selected roles as { tank, healer, dps } (a copy), never empty.
function Roles.Selected()
    local allowed = Roles.Allowed()
    local set = clean(store().roles, allowed)
    if not any(set) then set = default(allowed) end
    return set
end

-- Toggles a role; the last one stays (a listing needs a role).
function Roles.Toggle(key)
    local allowed = Roles.Allowed()
    if not allowed[key] then return false end
    local set = Roles.Selected()
    set[key] = not set[key]
    if not any(set) then return false end
    store().roles = set
    return true
end

function Roles.Set(set)
    local cleaned = clean(set, Roles.Allowed())
    if any(cleaned) then store().roles = cleaned end
end

-- "TANK", "HEALER", "DAMAGER" in that order.
function Roles.List()
    local out = {}
    for _, k in ipairs(Roles.KEYS) do
        if Roles.Selected()[k] then out[#out + 1] = Roles.ID[k] end
    end
    return out
end

-- "Tank" or "Tank/Damage".
function Roles.Text()
    local names = {}
    for _, id in ipairs(Roles.List()) do names[#names + 1] = L["ROLE_" .. id] end
    return table.concat(names, "/")
end

function Roles.Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for _, k in ipairs(Roles.KEYS) do
        if (a[k] == true) ~= (b[k] == true) then return false end
    end
    return true
end
