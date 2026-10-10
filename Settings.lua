local ADDON, ns = ...

-- Every user setting, its default and its range. The active profile
-- (Profiles.lua) stores only what differs from the default; Get falls back to
-- DEFAULTS. Set writes the profile and tells the listeners (the window, the
-- minimap button, the options window).
local Settings = {}
ns.Settings = Settings

-- The text styles; each has <prefix>Font, Size, Flag and Color.
Settings.TEXT_STYLES = { "header", "activity", "name", "comment", "small", "level", "location", "chip", "age" }
-- The styles of the result list, on the "List look" page; the others on "Text".
Settings.LIST_STYLES = { "activity", "name", "level", "location", "chip", "comment", "age" }

-- Tables (languages, whisperTemplates) are stored whole, and
-- only when they differ from the default.
Settings.DEFAULTS = {
    -- General
    replaceBlizzard = true, -- our window answers the keybinding and the micro menu
    minimapShow = true,
    minimapAngle = 215,
    compartment = true,     -- the addon list by the minimap

    -- Window
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 40,
    width = 720,
    height = 460,
    scale = 100,            -- percent
    locked = false,
    sideWidth = 190,        -- the side panel of the window
    -- The arrangement (Layouts.lua): SIDEBAR (activity column), STACKED
    -- (narrow, activities in a dropdown) or DETAILS (list and a details
    -- column). Each has its own size: width / height are the SIDEBAR's.
    layout = "SIDEBAR",
    stackedWidth = 480,
    stackedHeight = 560,
    detailsWidth = 880,
    detailsHeight = 480,

    -- Search and list
    minInterval = 1,        -- seconds between two searches (Blizzard: none, one in flight)
    levelRangeOnly = true,
    category = 2,
    sortFriendsFirst = true,
    filterMyRole = true,    -- "Only room for me": groups without room for my roles are hidden
    filterLevelFits = false,
    hideSeen = false,
    languages = {},         -- empty: all languages
    markOpenSlot = true,
    showPlayers = true,
    rowHeight = 22,
    playerRowHeight = 34,
    -- List look
    playerRoleIconSize = 0, -- 0: the player row's height minus 6
    groupRoleIconSize = 16, -- a member slot in a group row
    classIconSize = 14,
    classColorNames = true, -- else nameColor
    abbreviate = true,      -- short activity names in the player rows' chips (Abbrev.lua)
    chipBorderColor = { 0.36, 0.29, 0.13 },
    openEdgeColor = { 0.25, 0.75, 0.37 },
    seenAlpha = 45,         -- percent: how visible a seen row stays
    noRoomAlpha = 45,       -- percent: a group without room for my roles
    memoryMinutes = 30,

    -- Listing
    expiryWarnMinutes = 5,
    whisperTemplates = { "Hi! Still looking for {role}? I'm a level {level} {class}." },

    -- Frame look (as the combat meter's FOREVER style)
    borderStyle = "NONE",   -- NONE, FLAT or GOLD
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    cornerRadius = 10,
    shadowEnabled = true,
    shadowSize = 9,
    shadowAlpha = 65,       -- percent
    bgMode = "SOLID",       -- SOLID, GRADIENT or TEXTURE
    bgColor = { 0.047, 0.047, 0.055 },
    bgAlpha = 85,           -- percent
    bgTexture = "Blizzard Dialog Background Gold",
    headerLine = true,
    buttonHeight = 22,      -- every button of the window, panel and popup
    chipHeight = 20,        -- chips (filters, activities, players)
    buttonTextSize = 12,    -- the text on buttons, chips and check boxes

    -- Text styles. Flags: "" none, OUTLINE, THICKOUTLINE, SHADOW.
    headerFont = "Friz Quadrata",
    headerSize = 18,        -- as Forever Quest Log
    headerFlag = "SHADOW",
    headerColor = { 1, 0.82, 0.29 },
    activityFont = "Friz Quadrata",
    activitySize = 12,
    activityFlag = "SHADOW",
    activityColor = { 1, 0.82, 0.29 },
    nameFont = "Friz Quadrata",
    nameSize = 12,
    nameFlag = "SHADOW",
    nameColor = { 1, 1, 1 },
    commentFont = "Friz Quadrata",
    commentSize = 11,
    commentFlag = "SHADOW",
    commentColor = { 0.79, 0.76, 0.69 },
    levelFont = "Friz Quadrata",
    levelSize = 15,
    levelFlag = "SHADOW",
    levelColor = { 1, 1, 1 },
    locationFont = "Friz Quadrata",
    locationSize = 12,
    locationFlag = "SHADOW",
    locationColor = { 1, 0.82, 0.29 },
    chipFont = "Friz Quadrata",
    chipSize = 10,
    chipFlag = "SHADOW",
    chipColor = { 0.79, 0.76, 0.69 },
    ageFont = "Friz Quadrata",
    ageSize = 10,
    ageFlag = "SHADOW",
    ageColor = { 0.55, 0.54, 0.5 },
    smallFont = "Friz Quadrata",
    smallSize = 10,
    smallFlag = "SHADOW",
    smallColor = { 0.55, 0.54, 0.5 },
}

-- Slider ranges, used by the options window and to clamp typed values.
Settings.RANGES = {
    minimapAngle = { 0, 360 },
    x = { -4000, 4000 },
    y = { -4000, 4000 },
    width = { 560, 1100 },
    height = { 320, 800 },
    scale = { 50, 150 },
    sideWidth = { 150, 280 },
    stackedWidth = { 420, 900 },
    stackedHeight = { 360, 1000 },
    detailsWidth = { 720, 1300 },
    detailsHeight = { 360, 900 },
    minInterval = { 1, 15 },
    rowHeight = { 16, 36 },
    playerRowHeight = { 26, 50 },
    playerRoleIconSize = { 0, 48 },
    groupRoleIconSize = { 10, 28 },
    classIconSize = { 8, 28 },
    seenAlpha = { 10, 100 },
    noRoomAlpha = { 10, 100 },
    levelSize = { 8, 24 },
    locationSize = { 8, 20 },
    chipSize = { 7, 16 },
    ageSize = { 7, 16 },
    memoryMinutes = { 5, 240 },
    expiryWarnMinutes = { 1, 15 },
    borderSize = { 1, 8 },
    cornerRadius = { 0, 12 },
    shadowSize = { 1, 20 },
    shadowAlpha = { 0, 100 },
    bgAlpha = { 0, 100 },
    buttonHeight = { 18, 32 },
    chipHeight = { 14, 28 },
    buttonTextSize = { 9, 18 },
    headerSize = { 8, 24 },
    activitySize = { 8, 20 },
    nameSize = { 8, 20 },
    commentSize = { 8, 18 },
    smallSize = { 7, 16 },
}

local listeners = {}

function Settings.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- key nil: everything may have changed (profile switch, reset).
function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

-- A deep copy: a table setting handed out must not be the shared default.
local function copy(t)
    if type(t) ~= "table" then return t end
    local new = {}
    for k, v in pairs(t) do new[k] = copy(v) end
    return new
end

function Settings.Get(key)
    local v = ns.DB()[key]
    if v == nil then v = copy(Settings.DEFAULTS[key]) end
    return v
end

local function sameValue(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not sameValue(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

Settings.SameValue = sameValue

-- A number inside its range, as a whole number; anything else unchanged.
function Settings.Clamp(key, value)
    local range = Settings.RANGES[key]
    if not range or type(value) ~= "number" then return value end
    value = math.floor(value + 0.5)
    return math.max(range[1], math.min(range[2], value))
end

function Settings.Set(key, value)
    value = Settings.Clamp(key, value)
    if sameValue(value, Settings.DEFAULTS[key]) then value = nil end
    ns.DB()[key] = copy(value)
    Settings.Changed(key)
end

-- Several values in one go, one change for all (dragging writes position
-- and size together).
function Settings.SetMany(values)
    local db = ns.DB()
    for key, value in pairs(values) do
        value = Settings.Clamp(key, value)
        if sameValue(value, Settings.DEFAULTS[key]) then value = nil end
        db[key] = copy(value)
    end
    Settings.Changed(nil)
end

-- Locks or unlocks the window (the options footer, the minimap button's
-- right click, /fgf lock / unlock).
function Settings.SetLocked(locked)
    Settings.Set("locked", locked and true or false)
end

-- A text style as one table: font, size, flag, color.
function Settings.TextStyle(name)
    return {
        font = Settings.Get(name .. "Font"),
        size = Settings.Get(name .. "Size"),
        flag = Settings.Get(name .. "Flag"),
        color = Settings.Get(name .. "Color"),
    }
end

-- Back to the defaults (the language is not in the profile).
function Settings.ResetProfile()
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    Settings.Changed(nil)
end
