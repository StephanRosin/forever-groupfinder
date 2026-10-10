local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Group Finder"
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."
L.MSG_IMPORTED = "Profile imported."
L.MSG_IMPORT_FAILED = "That is not a Forever Group Finder profile string."
L.MINIMAP_LEFT_CLICK = "Left-click: open or close the group finder"
L.MINIMAP_RIGHT_CLICK = "Right-click: lock or unlock the window"
L.MINIMAP_DRAG = "Drag: move this button"
L.OPEN_OPTIONS = "Open the options"
L.OPT_LANGUAGE = "Language"
L.LANGUAGE_AUTO = "Game language"
L.PAGE_GENERAL = "General"
L.PAGE_PROFILES = "Profiles"

-- Widgets, resizing
L.INHERITED = "(inherited)"
L.RESET_OVERRIDE = "Reset"
L.TIP_RESIZE = "Drag: width and height"

-- Commands, messages
L.MSG_LOCKED = "Window locked."
L.MSG_UNLOCKED = "Window unlocked: drag the title to move it, the corners to resize it."
L.MSG_USAGE = "/fgf (open or close the finder), options, lock, unlock, reset"
L.MSG_WINDOW_SOON = "The group finder window is not built yet."
L.MSG_RESET = "Window position and size reset."
L.OPT_UNLOCK_FRAME = "Unlock the window"
L.OPT_LOCK_FRAME = "Lock the window"

-- General page
L.OPT_GENERAL = "General"
L.OPT_REPLACE_BLIZZARD = "Open this finder instead of Blizzard's"
L.OPT_REPLACE_BLIZZARD_HINT = "The keybinding and the micro menu button then open this window. Blizzard's own finder is not loaded by us."
L.OPT_MINIMAP = "Minimap"
L.OPT_MINIMAP_SHOW = "Minimap button"
L.OPT_COMPARTMENT = "Entry in the addon list by the minimap"
L.OPT_LOCK = "Locked"

-- Profiles page
L.OPT_PROFILES = "Profiles"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Delete the profile \"%s\"?"
L.OPT_SHARE = "Share"
L.OPT_SHARE_HINT = "Export copies the active profile as a string; paste a string and click Import to take it over."
L.OPT_EXPORT = "Export"
L.OPT_IMPORT = "Import"
L.OPT_RESET = "Reset"
L.OPT_RESET_HINT = "Back to the defaults for the active profile."
L.OPT_RESET_BUTTON = "Reset the profile"

-- Settings, for the pages the next tasks build
L.OPT_POSITION = "Position and size"
L.OPT_POS_X = "Horizontal (from the centre)"
L.OPT_POS_Y = "Vertical (from the top)"
L.OPT_SCALE = "Scale"
L.OPT_WIDTH = "Width"
L.OPT_HEIGHT = "Height"
L.OPT_SIDE_WIDTH = "Width of the side panel"
L.OPT_SEARCH = "Search"
L.OPT_MIN_INTERVAL = "Seconds between searches"
L.OPT_LEVEL_RANGE_ONLY = "Only groups for my level"
L.OPT_CATEGORY = "Category"
L.OPT_SORT_FRIENDS_FIRST = "Friends and guild first"
L.OPT_FILTER_MY_ROLE = "Only groups that need my role"
L.OPT_FILTER_LEVEL_FITS = "Only groups my level fits"
L.OPT_HIDE_SEEN = "Hide groups I have already seen"
L.OPT_LANGUAGES = "Languages of the groups"
L.OPT_ROLE_OVERRIDE = "My role"
L.ROLE_AUTO = "Automatic"
L.ROLE_TANK = "Tank"
L.ROLE_HEALER = "Healer"
L.ROLE_DAMAGER = "Damage"
L.OPT_MARK_OPEN_SLOT = "Mark the slot I would fill"
L.OPT_SHOW_PLAYERS = "Show players looking for a group"
L.OPT_ROW_HEIGHT = "Height of a group row"
L.OPT_PLAYER_ROW_HEIGHT = "Height of a player row"
L.OPT_MEMORY_MINUTES = "Minutes to remember groups"
L.OPT_LISTING = "My listing"
L.OPT_EXPIRY_WARN = "Warn minutes before the listing ends"
L.OPT_TEMPLATES = "Templates"
L.OPT_WHISPER_TEMPLATES = "Whisper templates"
L.OPT_BACKGROUND = "Background"
L.OPT_BG_MODE = "Kind"
L.BG_SOLID = "Solid"
L.BG_GRADIENT = "Gradient"
L.BG_TEXTURE = "Texture"
L.OPT_BG_COLOR = "Colour"
L.OPT_BG_TEXTURE = "Texture"
L.OPT_BG_ALPHA = "Opacity"
L.OPT_HEADER_LINE = "Line under the header"
L.OPT_BORDER = "Border"
L.OPT_BORDER_STYLE = "Style"
L.BORDER_GOLD = "Gold"
L.BORDER_FLAT = "Flat"
L.BORDER_NONE = "None"
L.OPT_BORDER_SIZE = "Thickness"
L.OPT_BORDER_COLOR = "Colour (flat)"
L.OPT_CORNER_RADIUS = "Corner radius"
L.OPT_SHADOW = "Shadow"
L.OPT_SHADOW_SHOW = "Drop shadow"
L.OPT_SHADOW_SIZE = "Size"
L.OPT_SHADOW_ALPHA = "Strength"
L.STYLE_HEADER = "Header"
L.STYLE_ACTIVITY = "Activity"
L.STYLE_NAME = "Names"
L.STYLE_COMMENT = "Comments"
L.STYLE_SMALL = "Small print"
L.OPT_FONT = "Font"
L.OPT_FONT_SIZE = "Size"
L.OPT_OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_SHADOW = "Shadow"
L.OUTLINE_NORMAL = "Outline"
L.OUTLINE_THICK = "Thick outline"
L.OPT_COLOR = "Colour"
