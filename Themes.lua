local ADDON, ns = ...
local Settings = ns.Settings
local S = Settings.Get

-- Themes (beta): a look for our frames, and a whole set of settings each,
-- as Forever Unit Frames' (Core/Themes.lua), with a choice of its own.
-- The setting `theme` names the one in use; the active profile holds its
-- settings. The others wait in the profile's `themeSets`, one copy per
-- theme. CLASSIC is the player's own look as it was before themes: no
-- other theme changes it, so going back to it restores every setting.
--
-- A theme chosen the first time starts from the CLASSIC set (place, size,
-- list look: everything the player arranged) with the theme's look on top
-- (SPECS[id].look). Its art beyond settings (backdrop, ornaments, solid
-- shadow) is ThemeArt.lua's. The list rows keep their own fonts: group
-- comments are typed by players and must stay readable at small sizes.
local Themes = {}
ns.Themes = Themes

Themes.CLASSIC = "CLASSIC"
-- In the options' order; new themes go at the end.
Themes.IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL", "SWISS",
    "CONSOLE", "PITWALL" }

-- Raised whenever SPECS change a look: theme sets stored before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 10

-- The theme fonts have Latin letters only: on a client whose names are
-- written otherwise the header keeps its font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: settings the theme sets (Settings.DEFAULTS keys). font: the
-- header's font; bodyFont: every other text's (nil: as they are);
-- fontSizeAdd: how much larger the header must be to read like the others.
-- The header has the client's outline (OUTLINE for
-- the comic): a hand-made soft outline under these fonts showed black
-- text in Forever Unit Frames. Frost's has a soft drop shadow (SHADOW)
-- instead of an outline.
-- art (ThemeArt.lua): back = backdrop file in Media/Themes, tint = its
-- colour (light papers toned down, so they do not glare), padding = the
-- width of the backdrop band inside the ring (band and ring fit in the
-- frames' inner padding of 8), header = false keeps the title on the body
-- colour; ornament = corner piece, corners = which ones (Corners.POINTS
-- order: 1 top left, 2 top right, 3 bottom left, 4 bottom right),
-- ornamentInset = how far in from the ring's outer corner; rule = a line
-- ruleSize thick along the top, over the ring; strip = the header's colour
-- over the backdrop, wedge = a slanted band at its left in wedgeColor.
-- Nothing
-- reaches outside Classic's edge (ThemeArt.lua).
-- iconColor / iconHoverColor: the header's icons and note in dark ink, for
-- a header on light paper.
-- The body colour stays dark everywhere: the list's light text sits on it.
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards round the window, the family's gold ring, brass rivets.
    WOOD = {
        font = "Cinzel",
        look = { borderStyle = "GOLD", borderSize = 3, cornerRadius = 3,
            bgMode = "SOLID", bgColor = { 0.1, 0.06, 0.02 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 1, 0.86, 0.6 } },
        art = { back = "WoodBack", tint = { 0.5, 0.5, 0.5, 1 }, padding = 5, ornament = "Rivet", corners = { 1, 2, 3, 4 }, ornamentSize = 9,
            ornamentInset = 1 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        font = "Space Grotesk",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.25, 0.88, 0.94, 0.9 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.02, 0.05, 0.08 }, bgAlpha = 0, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.6, 0.95, 1 } },
        art = { back = "TechBack", padding = 4 },
    },
    -- Parchment round the window, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 }, cornerRadius = 2,
            bgMode = "SOLID", bgColor = { 0.13, 0.09, 0.05 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 45,
            shadowSize = 5, headerFlag = "OUTLINE", headerColor = { 1, 0.93, 0.78 } },
        art = { back = "ParchmentBack", tint = { 0.45, 0.45, 0.45, 1 }, padding = 5, ornament = "Seal", corners = { 3 },
            ornamentSize = 20, ornamentInset = 0 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.1, 0.1, 0.12, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.04, 0.05, 0.06 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 70,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 0.55, 1, 0.9 } },
        art = { back = "StoneBack", tint = { 0.55, 0.55, 0.55, 1 }, padding = 5, ornament = "Rune", corners = { 1, 2 }, ornamentSize = 10,
            ornamentInset = 1, ornamentColor = { 0.35, 0.95, 0.85, 1 } },
    },
    -- A mosaic of coloured glass round the window, dark lead, a dark title.
    GLASS = {
        font = "Morpheus", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.05, 0.04, 0.06 }, bgAlpha = 90, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 1, 0.82, 0.29 } },
        art = { back = "GlassBack", padding = 5, header = false },
    },
    -- Thick ink line, halftone paper.
    COMIC = {
        font = "Bangers", fontSizeAdd = 2,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.07, 0.07, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.1, 0.1, 0.12 }, bgAlpha = 100, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 1, 0.85, 0.1 } },
        -- The paper grey as in Forever Quest Log, the same in every Forever addon.
        art = { back = "ComicBack", tint = { 0.7, 0.7, 0.7, 1 }, padding = 4 },
        iconColor = { 0.1, 0.1, 0.1 }, iconHoverColor = { 0.4, 0.4, 0.4 },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        font = "Julius Sans One", bodyFont = "Julius Sans One",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.86, 0.96, 1, 0.8 }, cornerRadius = 6,
            bgMode = "SOLID", bgColor = { 0.02, 0.07, 0.15 }, bgAlpha = 45, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 8, headerFlag = "SHADOW", headerColor = { 0.86, 0.96, 1 } },
        -- The cracks dimmed: the title sits on them.
        art = { back = "FrostBack", padding = 4, tint = { 0.55, 0.55, 0.55, 0.85 } },
    },
    -- A light pixel frame, scan lines.
    PIXEL = {
        font = "VT323", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 0, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.6, 1, 0.5 } },
        art = { back = "PixelBack", padding = 4 },
    },
    -- Swiss style: flat black, a hairline, one white rule along the top,
    -- the title in the one red accent; the icons stay grey and white.
    SWISS = {
        font = "Inter Tight Bold",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.16, 0.16, 0.16, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 1, 0.18, 0.13 } },
        art = { back = "SwissBack", padding = 4, rule = { 0.95, 0.95, 0.95, 1 }, ruleSize = 3 },
        iconColor = { 0.55, 0.55, 0.55 }, iconHoverColor = { 0.95, 0.95, 0.95 },
    },
    -- A terminal: near black with faint scan lines, a thin mint line.
    CONSOLE = {
        font = "IBM Plex Sans Condensed",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.306, 0.929, 0.69, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.06, 0.06, 0.07 }, bgAlpha = 0, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.306, 0.929, 0.69 } },
        art = { back = "ConsoleBack", padding = 4 },
    },
    -- A timing screen: flat black, a carbon hairline, a black title strip with a red wedge.
    PITWALL = {
        font = "Titillium Web Bold Italic",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.043, 0.047, 0.055, 1 }, cornerRadius = 0,
            bgMode = "SOLID",
            bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false, headerFlag = "OUTLINE",
            headerColor = { 0.95, 0.95, 0.96 } },
        art = { back = "SwissBack", padding = 4, strip = { 0, 0, 0, 1 }, wedge = "PitwallWedge",
            wedgeColor = { 0.88, 0.02, 0, 1 } },
    },
}

-- Each theme's colours, the same in every Forever addon (none for CLASSIC).
-- The first is the theme as it is. Any other draws the backdrop from the
-- theme's grey texture (<back>Grey), tinted so its mean lands on `back`
-- (vertex colour = back / GREY_MEAN, at most 1), and brings its accent
-- (nil: the theme's own). Themes with one dark backdrop in every colour
-- (SWISS, CONSOLE, PITWALL) change only the accent, the ring or the wedge.
-- `rim` recolours the ring: only CONSOLE's colours and Pixel's HANDHELD,
-- the same in every Forever addon.
-- The comic keeps its paper tint (COMIC_PAINT).
local GREY_MEAN = { WoodBack = 0.800, TechBack = 0.705, ParchmentBack = 0.799, StoneBack = 0.800,
    GlassBack = 0.777, FrostBack = 0.796, PixelBack = 0.800 }
local function colour(id, back, accent, rim, wedge)
    return { id = id, back = back, accent = accent, rim = rim, wedge = wedge }
end
Themes.COLORS = {
    WOOD = {
        colour("OAK"),
        colour("WALNUT", { 0.15, 0.09, 0.06 }),
        colour("BIRCH", { 0.38, 0.32, 0.22 }),
        colour("CHERRY", { 0.3, 0.12, 0.08 }),
        colour("EBONY", { 0.08, 0.07, 0.07 }),
        colour("DRIFTWOOD", { 0.25, 0.24, 0.22 }),
    },
    TECH = {
        colour("CYAN"),
        colour("GREEN", { 0.02, 0.1, 0.05 }, { 0.3, 0.95, 0.45 }),
        colour("AMBER", { 0.1, 0.07, 0.02 }, { 1, 0.75, 0.2 }),
        colour("MAGENTA", { 0.09, 0.03, 0.1 }, { 0.95, 0.4, 0.95 }),
        colour("BLUE", { 0.03, 0.05, 0.13 }, { 0.45, 0.65, 1 }),
        colour("GREY", { 0.07, 0.07, 0.08 }, { 0.85, 0.88, 0.9 }),
    },
    PARCHMENT = {
        colour("CLASSIC"),
        colour("AGED", { 0.32, 0.25, 0.15 }),
        colour("ASH", { 0.33, 0.33, 0.31 }),
        colour("SEA", { 0.25, 0.3, 0.33 }),
        colour("ROSE", { 0.36, 0.27, 0.26 }),
        colour("DARK", { 0.2, 0.17, 0.13 }),
    },
    RUNESTONE = {
        colour("GRANITE"),
        colour("SANDSTONE", { 0.33, 0.27, 0.18 }, { 1, 0.8, 0.35 }),
        colour("SLATE", { 0.15, 0.18, 0.25 }, { 0.55, 0.75, 1 }),
        colour("MOSS", { 0.15, 0.22, 0.14 }, { 0.5, 1, 0.45 }),
        colour("OBSIDIAN", { 0.07, 0.06, 0.09 }, { 0.75, 0.5, 1 }),
    },
    GLASS = {
        colour("CATHEDRAL"),
        colour("BLUE", { 0.08, 0.12, 0.28 }),
        colour("GREEN", { 0.07, 0.2, 0.1 }),
        colour("AMBER", { 0.28, 0.17, 0.05 }),
        colour("VIOLET", { 0.18, 0.08, 0.26 }),
        colour("RUBY", { 0.26, 0.05, 0.08 }),
    },
    FROST = {
        colour("ICE"),
        colour("DEEP", { 0.1, 0.18, 0.32 }, { 0.6, 0.85, 1 }),
        colour("AURORA", { 0.1, 0.27, 0.24 }, { 0.55, 1, 0.8 }),
        colour("VIOLET", { 0.22, 0.18, 0.33 }, { 0.85, 0.75, 1 }),
        colour("SILVER", { 0.3, 0.31, 0.33 }, { 0.92, 0.92, 0.95 }),
        colour("NIGHT", { 0.06, 0.08, 0.14 }, { 0.7, 0.85, 1 }),
    },
    PIXEL = {
        colour("NAVY"),
        colour("PLUM", { 0.23, 0.08, 0.16 }, { 1, 0.93, 0.15 }),
        colour("FOREST", { 0, 0.2, 0.12 }, { 1, 0.93, 0.15 }),
        colour("BROWN", { 0.2, 0.12, 0.08 }, { 1, 0.64, 0 }),
        colour("GREY", { 0.18, 0.17, 0.16 }),
        colour("BLACK", { 0.03, 0.03, 0.04 }, { 0, 0.89, 0.21 }),
        colour("TEAL", { 0.02, 0.17, 0.22 }, { 0.16, 0.68, 1 }),
        colour("PURPLE", { 0.15, 0.1, 0.25 }, { 1, 0.47, 0.66 }),
        colour("HANDHELD", { 0.059, 0.122, 0.059 }, { 0.784, 0.941, 0.439 }, { 0.784, 0.941, 0.439, 1 }),
    },
    SWISS = {
        colour("RED"),
        colour("BLUE", nil, { 0.18, 0.42, 1 }),
        colour("YELLOW", nil, { 1, 0.82, 0 }),
        colour("WHITE", nil, { 0.95, 0.95, 0.95 }),
    },
    CONSOLE = {
        colour("MINT"),
        colour("AMBER", nil, { 1, 0.69, 0 }, { 1, 0.69, 0, 1 }),
        colour("PHOSPHOR", nil, { 0.224, 1, 0.078 }, { 0.224, 1, 0.078, 1 }),
        colour("VIOLET", nil, { 0.627, 0.471, 1 }, { 0.627, 0.471, 1, 1 }),
    },
    PITWALL = {
        colour("RED"),
        colour("ORANGE", nil, nil, nil, { 1, 0.54, 0, 1 }),
        colour("TEAL", nil, nil, nil, { 0, 0.63, 0.61, 1 }),
        colour("SILVER", nil, nil, nil, { 0.79, 0.81, 0.84, 1 }),
    },
    COMIC = { colour("GREY"), colour("DARKGREY"), colour("BLACK"), colour("WHITE"), colour("YELLOW"),
        colour("BLUE"), colour("RED"), colour("GREEN"), colour("PURPLE") },
}

-- The accent is the headers' colour. Colours are stored account wide,
-- outside profiles and theme sets (AccountDB().themeColors).
-- The comic's paper tint and accent per colour; GREY is the comic as it is
-- (accent nil: the set's own).
local COMIC_YELLOW = { 1, 0.9, 0.1 }
local COMIC_PAINT = {
    GREY = { paper = { 0.70, 0.70, 0.70 } },
    DARKGREY = { paper = { 0.38, 0.38, 0.38 }, accent = COMIC_YELLOW, dark = true },
    BLACK = { paper = { 0.16, 0.16, 0.16 }, accent = COMIC_YELLOW, dark = true },
    WHITE = { paper = { 1, 1, 1 }, accent = { 0.15, 0.45, 0.95 } },
    YELLOW = { paper = { 0.86, 0.76, 0.36 }, accent = { 0.15, 0.45, 0.95 } },
    BLUE = { paper = { 0.45, 0.60, 0.86 }, accent = COMIC_YELLOW },
    RED = { paper = { 0.86, 0.44, 0.40 }, accent = COMIC_YELLOW },
    GREEN = { paper = { 0.50, 0.76, 0.46 }, accent = COMIC_YELLOW },
    PURPLE = { paper = { 0.70, 0.52, 0.84 }, accent = COMIC_YELLOW },
}

-- What "Take positions from" copies: the window's place and every size.
Themes.PLACEMENT = { "point", "relPoint", "x", "y", "width", "height", "detailsWidth", "detailsHeight", "sideWidth",
    "scale" }

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

-- A theme's settings: the profile without the stored sets.
local function settingsOf(db)
    local set = copy(db)
    set.themeSets = nil
    return set
end

-- The active profile's stored sets; those of an older REVISION dropped.
local function storedSets()
    local db = ns.DB()
    if type(db.themeSets) ~= "table" then db.themeSets = { revision = Themes.REVISION } end
    local sets = db.themeSets
    if sets.revision ~= Themes.REVISION then
        for _, id in ipairs(Themes.IDS) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        sets.revision = Themes.REVISION
    end
    return sets
end

-- The stored CLASSIC set while a theme is in use, else nil.
function Themes.ClassicSet()
    return storedSets()[Themes.CLASSIC]
end

function Themes.Current()
    local id = S("theme")
    return Themes.SPECS[id] and id or Themes.CLASSIC   -- plain: a theme id
end

function Themes.Spec(id)
    return Themes.SPECS[id] or Themes.SPECS.CLASSIC
end

-- The stored colours, theme -> colour id; the comic's colour of before
-- moves in once.
local function storedColours()
    local db = ns.AccountDB()
    if type(db.themeColors) ~= "table" then db.themeColors = {} end
    if db.comicColor ~= nil then
        if db.themeColors.COMIC == nil then db.themeColors.COMIC = db.comicColor end
        db.comicColor = nil
    end
    return db.themeColors
end

local function colourOf(themeId, id)
    for _, c in ipairs(Themes.COLORS[themeId] or {}) do
        if c.id == id then return c end
    end
    return nil
end

-- A theme's colour ids in order (themeId defaults to the current theme;
-- CLASSIC has none).
function Themes.Colors(themeId)
    local list = {}
    for i, c in ipairs(Themes.COLORS[themeId or Themes.Current()] or {}) do list[i] = c.id end
    return list
end

-- A theme's colour chosen; an unknown one stored reads as its first.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    local colours = Themes.COLORS[themeId]
    if not colours then return nil end
    local id = storedColours()[themeId]
    return colourOf(themeId, id) and id or colours[1].id   -- plain: a colour id
end

-- The comic's paint in use, or nil under any other theme.
local function comicPaint()
    if Themes.Current() ~= "COMIC" then return nil end
    return COMIC_PAINT[Themes.Color("COMIC")]
end

-- Any other theme's colour in use when it is not the theme's own look.
local function themePaint()
    local id = Themes.Current()
    local c = colourOf(id, Themes.Color())
    return c and c ~= Themes.COLORS[id][1] and c or nil
end

-- The backdrop's texture (art: the theme's): the grey one under a colour
-- that tints it.
function Themes.Back(art)
    local c = themePaint()
    return c and c.back and art.back .. "Grey" or art.back
end

-- The backdrop's tint (art: the theme's): the comic's paper in its colour,
-- or the grey texture tinted to the colour at the theme's alpha.
function Themes.Tint(art)
    local paint = comicPaint()
    if paint and art.tint then return { paint.paper[1], paint.paper[2], paint.paper[3], art.tint[4] } end
    local c = themePaint()
    if c and c.back then
        local mean = GREY_MEAN[art.back]
        return { math.min(1, c.back[1] / mean), math.min(1, c.back[2] / mean), math.min(1, c.back[3] / mean),
            art.tint and art.tint[4] or 1 }
    end
    return art.tint
end

-- The headers' colour the theme's colour sets, else nil (the setting's).
function Themes.Accent()
    local paint = comicPaint() or themePaint()
    return paint and paint.accent
end

-- The ring's colour: the theme's colour's where it has one, else the setting.
function Themes.RingColor()
    local c = themePaint()
    return c and c.rim or S("borderColor")
end

-- The wedge's colour (art: the theme's): the colour's, else the theme's.
function Themes.WedgeColor(art)
    local c = themePaint()
    return c and c.wedge or art.wedgeColor
end

-- On a dark paper the header's dark ink (iconColor) turns light: icons
-- idle, hovered, off, on (the accent), and the note. nil on any other.
local DARK_INK = { idle = { 0.85, 0.85, 0.85 }, hover = { 1, 1, 1 }, off = { 0.55, 0.55, 0.55 },
    text = { 0.9, 0.9, 0.9 } }
function Themes.DarkInk()
    local paint = comicPaint()
    if not (paint and paint.dark) then return nil end
    return { idle = DARK_INK.idle, hover = DARK_INK.hover, off = DARK_INK.off, text = DARK_INK.text, on = paint.accent }
end

-- A theme's colour (themeId defaults to the current theme). Our frames
-- are not protected: no combat lock.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not colourOf(themeId, id) then return nil, "UNKNOWN" end
    storedColours()[themeId] = id ~= Themes.COLORS[themeId][1].id and id or nil   -- plain: a colour id
    if themeId == Themes.Current() then Settings.Changed(nil) end
    return true
end

-- A theme's settings made from base (a set): base with the theme's look.
-- Stores only what differs from the defaults, as a profile does.
function Themes.Seed(id, base)
    local spec = Themes.Spec(id)
    local set = settingsOf(base)
    for key, value in pairs(spec.look or {}) do set[key] = copy(value) end
    if spec.font and LATIN_CLIENTS[GetLocale()] then set.headerFont = spec.font end
    if spec.bodyFont and LATIN_CLIENTS[GetLocale()] then
        for _, name in ipairs(Settings.TEXT_STYLES) do
            if name ~= "header" then set[name .. "Font"] = spec.bodyFont end
        end
    end
    if spec.fontSizeAdd then
        local size = base.headerSize or Settings.DEFAULTS.headerSize
        set.headerSize = Settings.Clamp("headerSize", size + spec.fontSizeAdd)
    end
    set.theme = id
    for key, value in pairs(set) do
        if Settings.SameValue(value, Settings.DEFAULTS[key]) then set[key] = nil end
    end
    return set
end

-- set becomes the active profile's settings; the stored sets stay.
local function use(set)
    local db = ns.DB()
    local sets = db.themeSets
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(copy(set)) do db[k] = v end
    db.themeSets = sets
    Settings.Changed(nil)
end

-- Moves to theme id: the current settings are kept for the current
-- theme, id's come back (or are made, the first time). true, or nil and
-- why not. Our frames are not protected: no combat lock.
function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local current = Themes.Current()
    if id == current then return true end
    local sets = storedSets()
    sets[current] = settingsOf(ns.DB())
    local nextSet = sets[id]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one the
        -- settings stay as they are.
        local base = sets[Themes.CLASSIC] or settingsOf(ns.DB())
        nextSet = id == Themes.CLASSIC and copy(base) or Themes.Seed(id, base)
    end
    nextSet.theme = id ~= Themes.CLASSIC and id or nil   -- plain: a theme id
    -- The live set is the profile: no stale copy stays behind.
    sets[id] = nil
    use(nextSet)
    return true
end

-- The current theme made anew from CLASSIC. Not for CLASSIC itself.
function Themes.Reset()
    local id = Themes.Current()
    if id == Themes.CLASSIC then return nil, "CLASSIC" end
    local base = storedSets()[Themes.CLASSIC]
    if not base then return nil, "NO_CLASSIC" end
    use(Themes.Seed(id, base))
    return true
end

-- The themes with stored settings to copy from, in IDS order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Themes.IDS) do
        if sets[id] and id ~= Themes.Current() then list[#list + 1] = id end
    end
    return list
end

-- The place and sizes of theme `from` taken over into the current one.
-- Returns what it replaced (Themes.Restore puts it back), or nil and why.
function Themes.CopyPlacement(from)
    local source = storedSets()[from]
    if not source then return nil, "GONE" end
    local db, undo = ns.DB(), {}
    for i, key in ipairs(Themes.PLACEMENT) do
        undo[i] = { key, copy(db[key]) }
        db[key] = copy(source[key])
    end
    Settings.Changed(nil)
    return undo
end

function Themes.Restore(undo)
    local db = ns.DB()
    for _, saved in ipairs(undo) do db[saved[1]] = saved[2] end
    Settings.Changed(nil)
    return true
end

-- At login: a theme in use made under an older REVISION is made anew from
-- CLASSIC; the stale stored sets go.
function Themes.Upgrade()
    local sets = ns.DB().themeSets
    if type(sets) ~= "table" or sets.revision == Themes.REVISION then return end
    local current, base = Themes.Current(), sets[Themes.CLASSIC]
    storedSets()
    if current == Themes.CLASSIC or not base then return end
    use(Themes.Seed(current, base))
end

ns.On("PLAYER_LOGIN", Themes.Upgrade)

-- For a central theme picker in another addon: the same as choosing a
-- theme in our options (the window and an open options window follow
-- Settings.Changed).
_G.ForeverThemes = _G.ForeverThemes or {}
_G.ForeverThemes[ADDON] = {
    title = ns.L.ADDON_NAME,
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
}

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- in the list above. Each Forever addon has its own copy of this.
local function otherThemes()
    local list = {}
    for folder, entry in pairs(_G.ForeverThemes) do
        if folder ~= ADDON and type(entry) == "table" and type(entry.Switch) == "function" then
            list[#list + 1] = entry
        end
    end
    return list
end

function Themes.HasOthers() return #otherThemes() > 0 end

local function listed(ids, id)
    for _, v in ipairs(ids or {}) do
        if v == id then return true end
    end
    return false
end

-- Every other addon onto this theme and, where that theme has it, this
-- colour (else it keeps its own). One without the theme refuses the switch
-- and is skipped. Returns how many switched.
function Themes.ApplyToAll()
    local theme, color, switched = Themes.Current(), Themes.Color(), 0
    for _, entry in ipairs(otherThemes()) do
        if entry.Switch(theme) then
            switched = switched + 1
            if color and type(entry.Colors) == "function" and type(entry.SetColor) == "function"
                and listed(entry.Colors(theme), color) then
                entry.SetColor(color, theme)
            end
        end
    end
    return switched
end
