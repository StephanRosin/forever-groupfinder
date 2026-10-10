local ADDON, ns = ...

-- Short names for activities, for the player rows' chips (more of them fit);
-- the tooltips keep the full names. Pure: works on Activities.Info tables.
-- Order: (1) the instance's mapID (language independent), split by wing
-- where one instance has several (by the English name); (2) the English
-- full name, which also covers WoW Forever's new dungeons; (3) the client's
-- shortName when it is short, else the initials of the significant words.
local Abbrev = {}
ns.Abbrev = Abbrev

Abbrev.MAX_SHORT = 8

-- A wing table: { pattern in the lower-cased name, abbreviation }, and the
-- instance's plain abbreviation when no wing matches.
local BY_MAP = {
    [389] = "RFC", [43] = "WC", [36] = "DM", [33] = "SFK", [48] = "BFD", [34] = "Stocks",
    [90] = "Gnomer", [47] = "RFK", [129] = "RFD", [70] = "Ulda", [209] = "ZF", [349] = "Mara",
    [109] = "ST", [230] = "BRD", [289] = "Scholo",
    [189] = { "SM", { "graveyard", "SM GY" }, { "library", "SM Lib" }, { "armory", "SM Arm" }, { "cathedral", "SM Cath" } },
    [229] = { "BRS", { "lower", "LBRS" }, { "upper", "UBRS" } },
    [429] = { "DiM", { "east", "DME" }, { "west", "DMW" }, { "north", "DMN" } },
    [329] = { "Strat", { "undead", "Strat UD" }, { "live", "Strat Live" } },
    [409] = "MC", [249] = "Ony", [469] = "BWL", [309] = "ZG", [509] = "AQ20", [531] = "AQ40", [533] = "Naxx",
}

-- English full names (lower case); patterns where the name carries a wing.
local BY_NAME = {
    ["ragefire chasm"] = "RFC", ["wailing caverns"] = "WC", ["the deadmines"] = "DM", ["deadmines"] = "DM",
    ["shadowfang keep"] = "SFK", ["blackfathom deeps"] = "BFD", ["the stockade"] = "Stocks",
    ["the stormwind stockade"] = "Stocks", ["stormwind stockade"] = "Stocks", ["gnomeregan"] = "Gnomer",
    ["razorfen kraul"] = "RFK", ["razorfen downs"] = "RFD", ["uldaman"] = "Ulda", ["zul'farrak"] = "ZF",
    ["maraudon"] = "Mara", ["the temple of atal'hakkar"] = "ST", ["temple of atal'hakkar"] = "ST",
    ["sunken temple"] = "ST", ["blackrock depths"] = "BRD", ["lower blackrock spire"] = "LBRS",
    ["upper blackrock spire"] = "UBRS", ["scholomance"] = "Scholo", ["molten core"] = "MC",
    ["onyxia's lair"] = "Ony", ["blackwing lair"] = "BWL", ["zul'gurub"] = "ZG",
    ["ruins of ahn'qiraj"] = "AQ20", ["temple of ahn'qiraj"] = "AQ40", ["ahn'qiraj temple"] = "AQ40",
    ["naxxramas"] = "Naxx",
    -- WoW Forever's own dungeons (no community names yet).
    ["ruins of lordaeron"] = "RoL", ["hall of thanes"] = "Thanes", ["excavation site"] = "Excav",
    ["city of dalaran"] = "Dala", ["the drowned city"] = "Drowned", ["krol'dok stronghold"] = "Krol'dok",
    ["alcaz island prison"] = "Alcaz", ["blackmaw hold"] = "Blackmaw", ["shaper's terrace"] = "Shaper's",
}
local NAME_WINGS = {
    { "scarlet monastery", BY_MAP[189] }, { "dire maul", BY_MAP[429] }, { "stratholme", BY_MAP[329] },
}

local SKIP = { ["of"] = true, ["the"] = true }

local function wing(entry, name)
    for i = 2, #entry do
        if name:find(entry[i][1], 1, true) then return entry[i][2] end
    end
    return entry[1]
end

-- "Hall of Thanes" -> "HT": the first letters of the significant words.
function Abbrev.Initials(name)
    local out = {}
    for word in name:gmatch("[^%s%-:,]+") do
        if not SKIP[word:lower()] then out[#out + 1] = word:sub(1, 1):upper() end
    end
    return table.concat(out)
end

-- The short name of an activity (an Activities.Info table); nil for nil.
function Abbrev.For(info)
    if type(info) ~= "table" then return nil end
    local name = type(info.name) == "string" and info.name or ""   -- plain: our own cache entry
    local lower = name:lower()
    local byMap = BY_MAP[info.mapID]
    if type(byMap) == "string" then return byMap end
    if type(byMap) == "table" then return wing(byMap, lower) end
    if BY_NAME[lower] then return BY_NAME[lower] end
    for _, w in ipairs(NAME_WINGS) do
        if lower:find(w[1], 1, true) then return wing(w[2], lower) end
    end
    local short = info.shortName
    if type(short) == "string" and short ~= "" and short ~= name and #short <= Abbrev.MAX_SHORT then return short end   -- plain: our own cache entry
    if #name <= Abbrev.MAX_SHORT then return name end
    local initials = Abbrev.Initials(name)
    return initials ~= "" and initials or name
end

-- The chip text for an activity id: abbreviated while the setting is on.
function Abbrev.Chip(id)
    local info = ns.Activities.Info(id)
    if not info then return ns.L.UNKNOWN_ACTIVITY end
    if ns.Settings.Get("abbreviate") then return Abbrev.For(info) end
    return info.name
end
