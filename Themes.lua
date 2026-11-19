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

local Lib = LibForeverThemes
Themes.CLASSIC = Lib.CLASSIC

-- Raised whenever SPECS change a look: theme sets stored before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched. The library's part counts too: a change
-- there to what seeding copies (fonts, sizes, ring colour) reseeds as well
-- (Lib.NeedsReseed).
local OWN_REVISION = 10

-- Each theme's identity (backdrop, tint, ornament, wedge, ring colour,
-- fonts) is LibForeverThemes'; here only the window's part on top.
-- look: settings the theme sets (Settings.DEFAULTS keys). font: the
-- header's font; bodyFont: every other text's (false: as they are; the
-- list rows keep their own fonts: group comments are typed by players and
-- must stay readable at small sizes, so only Frost's is taken);
-- fontSizeAdd: how much larger the header must be to read like the others.
-- The header has the client's outline (OUTLINE for
-- the comic): a hand-made soft outline under these fonts showed black
-- text in Forever Unit Frames. Frost's has a soft drop shadow (SHADOW)
-- instead of an outline.
-- art (ThemeArt.lua), the library's back, tint, ornament, corners,
-- ornamentColor, rule, strip and wedge with: padding = the
-- width of the backdrop band inside the ring (band and ring fit in the
-- frames' inner padding of 8), header = false keeps the title on the body
-- colour; ornamentSize, ornamentInset = how far in from the ring's outer
-- corner. Nothing reaches outside Classic's edge (ThemeArt.lua).
-- iconColor / iconHoverColor (the library's comic ink): the header's icons
-- and note in dark ink, for a header on light paper.
-- The body colour stays dark everywhere: the list's light text sits on it.
-- The HD themes (WOOD_HD, ...) are their base's part here over a finer
-- backdrop of their own (Lib.Specs, withHd).
-- The framed themes' frame, narrower than the library's 7: frame and ring
-- stay inside Classic's edge, and the activity popup's list starts 6 in.
local FRAME = 4
Themes.SPECS = Lib.Specs({
    -- Oak boards round the window, the family's gold ring, brass rivets.
    WOOD = {
        bodyFont = false,
        look = { borderStyle = "GOLD", borderSize = 3, cornerRadius = 3,
            bgMode = "SOLID", bgColor = { 0.1, 0.06, 0.02 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 1, 0.86, 0.6 } },
        art = { padding = 5, ornamentSize = 9, ornamentInset = 1 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.TECH.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.02, 0.05, 0.08 }, bgAlpha = 0, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.6, 0.95, 1 } },
        art = { padding = 4 },
    },
    -- Parchment round the window, a brown ink line, a wax seal.
    PARCHMENT = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.PARCHMENT.rim, cornerRadius = 2,
            bgMode = "SOLID", bgColor = { 0.13, 0.09, 0.05 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 45,
            shadowSize = 5, headerFlag = "OUTLINE", headerColor = { 1, 0.93, 0.78 } },
        art = { padding = 5, ornamentSize = 20, ornamentInset = 0 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.RUNESTONE.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.04, 0.05, 0.06 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 70,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 0.55, 1, 0.9 } },
        art = { padding = 5, ornamentSize = 10, ornamentInset = 1 },
    },
    -- A mosaic of coloured glass round the window, dark lead, a dark title.
    GLASS = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.GLASS.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.05, 0.04, 0.06 }, bgAlpha = 90, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 1, 0.82, 0.29 } },
        art = { padding = 5, header = false },
    },
    -- Thick ink line, halftone paper.
    COMIC = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.COMIC.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.1, 0.1, 0.12 }, bgAlpha = 100, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 1, 0.85, 0.1 } },
        art = { padding = 4 },
    },
    -- Translucent ice, a pale rim, rounded.
    FROST = {
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.FROST.rim, cornerRadius = 6,
            bgMode = "SOLID", bgColor = { 0.02, 0.07, 0.15 }, bgAlpha = 45, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 8, headerFlag = "SHADOW", headerColor = { 0.86, 0.96, 1 } },
        art = { padding = 4 },
    },
    -- A light pixel frame, scan lines.
    PIXEL = {
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = Lib.THEMES.PIXEL.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 0, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.6, 1, 0.5 } },
        art = { padding = 4 },
    },
    -- Swiss style: flat black, a hairline, one white rule along the top,
    -- the title and the icons in the one red accent.
    SWISS = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.SWISS.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 1, 0.176, 0.125 } },
        art = { padding = 4 },
    },
    -- A terminal: near black with faint scan lines, a thin mint line.
    CONSOLE = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.CONSOLE.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.06, 0.06, 0.07 }, bgAlpha = 0, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.306, 0.929, 0.69 } },
        art = { padding = 4 },
    },
    -- A timing screen: flat black, a carbon hairline, a black title strip with a red wedge.
    PITWALL = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = Lib.THEMES.PITWALL.rim, cornerRadius = 0,
            bgMode = "SOLID",
            bgColor = { 0.039, 0.039, 0.039 }, bgAlpha = 100, shadowEnabled = false, headerFlag = "OUTLINE",
            headerColor = { 0.949, 0.953, 0.961 } },
        art = { padding = 4 },
    },
    -- A window of the game's own world: a walnut frame, a gold ring and
    -- corners, the title on a red banner in gold (never ink on the red).
    -- The parchment under a dark body, as Parchment's: the list's light
    -- text stays as it is.
    AZEROTH = {
        bodyFont = false,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.AZEROTH.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.09, 0.06, 0.03 }, bgAlpha = 82, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 1, 0.82, 0 }, headerLine = false },
        art = { padding = 1, frameSize = FRAME, ornamentSize = 16, ornamentInset = 0 },
    },
    -- A goblin workshop: sooty sheet metal in a copper frame with rivets, a
    -- thin strip of warning stripes along the top (never text on it).
    GOBLIN = {
        -- Bungee runs wide: a point smaller keeps the title on one line.
        bodyFont = false, fontSizeAdd = -1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = Lib.THEMES.GOBLIN.rim, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.05, 0.05, 0.05 }, bgAlpha = 0, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 0.95, 0.76, 0.19 }, headerLine = false },
        art = { padding = 1, frameSize = FRAME, ornamentSize = 9, ornamentInset = 1, stripHeight = 5 },
    },
}, true)
-- Glass HD is there to show its glass: the dark fill over it at 60 % (Glass: 90 %).
Themes.SPECS.GLASS_HD.look.bgAlpha = 60

-- The theme colours are the library's (Lib.COLORS), the same in every
-- Forever addon; which one is chosen is stored account wide, outside
-- profiles and theme sets (AccountDB().themeColors). The accent is the
-- headers' colour.

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

-- The active profile's stored sets; those of an older revision dropped.
local function storedSets()
    local db = ns.DB()
    if type(db.themeSets) ~= "table" then db.themeSets = {} end
    local sets = db.themeSets
    if Lib.NeedsReseed(sets, OWN_REVISION) then
        for id in pairs(Themes.SPECS) do
            if id ~= Themes.CLASSIC then sets[id] = nil end
        end
        Lib.MarkSeeded(sets, OWN_REVISION)
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

-- A theme's colour ids in order (themeId defaults to the current theme;
-- CLASSIC has none).
function Themes.Colors(themeId)
    return Lib.Colors(themeId or Themes.Current())
end

-- A theme's colour chosen; an unknown one stored reads as its first.
function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    return Lib.ValidColor(themeId, storedColours()[themeId])
end

-- The backdrop's texture (art: the theme's): the grey one under a colour
-- that tints it.
function Themes.Back(art)
    return Lib.Back(art, Themes.Current(), Themes.Color())
end

-- The backdrop's tint (art: the theme's): the comic's paper in its colour,
-- or the grey texture tinted to the colour at the theme's alpha.
function Themes.Tint(art)
    return Lib.Tint(art, Themes.Current(), Themes.Color())
end

-- The headers' colour the theme's colour sets, else nil (the setting's).
function Themes.Accent()
    return Lib.Accent(Themes.Current(), Themes.Color())
end

-- Whether the theme's title band is a banner (Azeroth's red): the
-- header's title, icons and grip in its gold, notes in HEADER_INK.
function Themes.Banner()
    local art = Themes.Spec(Themes.Current()).art
    return art ~= nil and art.banner ~= nil and art.bannerEnd ~= nil
end
Themes.HEADER_INK = { 0.96, 0.89, 0.72 }

-- The ring's colour: the theme's colour's where it has one, else the setting.
function Themes.RingColor()
    return Lib.Rim(Themes.Current(), Themes.Color()) or S("borderColor")
end

-- The wedge's colour (art: the theme's): the colour's, else the theme's.
function Themes.WedgeColor(art)
    return Lib.WedgeColor(art, Themes.Current(), Themes.Color())
end

-- The header icons in the colour's accent (the title's; on Pitwall the
-- wedge's), as in every Forever addon. nil under CLASSIC and a theme with
-- its own ink (iconColor, COMIC).
function Themes.IconTones()
    local id = Themes.Current()
    local c = Lib.IconColor(Themes.Spec(id), id, Themes.Color(), S("headerColor"))
    return c and Lib.IconTones(c)
end

-- On a dark paper the header's dark ink (iconColor) turns light: icons
-- idle, hovered, off, on (the accent), and the note. nil on any other.
local DARK_INK = { idle = { 0.85, 0.85, 0.85 }, hover = { 1, 1, 1 }, off = { 0.55, 0.55, 0.55 },
    text = { 0.9, 0.9, 0.9 } }
function Themes.DarkInk()
    local id = Themes.Current()
    if not Lib.DarkPaper(id, Themes.Color()) then return nil end
    return { idle = DARK_INK.idle, hover = DARK_INK.hover, off = DARK_INK.off, text = DARK_INK.text,
        on = Lib.Accent(id, Themes.Color()) }
end

-- A theme's colour (themeId defaults to the current theme). Our frames
-- are not protected: no combat lock.
function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not Lib.Colour(themeId, id) then return nil, "UNKNOWN" end
    storedColours()[themeId] = id ~= Lib.COLORS[themeId][1].id and id or nil   -- plain: a colour id
    if themeId == Themes.Current() then Settings.Changed(nil) end
    return true
end

-- A theme's settings made from base (a set): base with the theme's look.
-- Stores only what differs from the defaults, as a profile does.
function Themes.Seed(id, base)
    local spec = Themes.Spec(id)
    local set = settingsOf(base)
    for key, value in pairs(spec.look or {}) do set[key] = copy(value) end
    if spec.font and Lib.LatinClient() then set.headerFont = spec.font end
    if spec.bodyFont and Lib.LatinClient() then
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
    -- A base and its HD theme share their settings: only the look changes.
    if Lib.SetKey(id) == Lib.SetKey(current) then
        ns.DB().theme = id
        Settings.Changed(nil)
        return true
    end
    local sets = storedSets()
    sets[Lib.SetKey(current)] = settingsOf(ns.DB())
    local nextSet = sets[Lib.SetKey(id)]
    if not nextSet then
        -- CLASSIC is never made from a theme: without a stored one the
        -- settings stay as they are.
        local base = sets[Themes.CLASSIC] or settingsOf(ns.DB())
        nextSet = id == Themes.CLASSIC and copy(base) or Themes.Seed(id, base)
    end
    nextSet.theme = id ~= Themes.CLASSIC and id or nil   -- plain: a theme id
    -- The live set is the profile: no stale copy stays behind.
    sets[Lib.SetKey(id)] = nil
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

-- The themes with stored settings to copy from, in the menu's order.
function Themes.Stored()
    local sets, list = storedSets(), {}
    for _, id in ipairs(Lib.MenuIds(Lib.SpecIds(Themes.SPECS))) do
        if sets[id] and id ~= Lib.SetKey(Themes.Current()) then list[#list + 1] = id end
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

-- Whether two sets hold the same settings; the theme field does not count.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if k ~= "theme" and not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if k ~= "theme" and a[k] == nil then return false end
    end
    return true
end

-- At login and on a profile change: a base and its HD theme, kept apart
-- before LibForeverThemes 9, made one set (a customised HD set wins); then a theme in
-- use made under an older revision is made anew from CLASSIC and the stale
-- stored sets go.
function Themes.Upgrade()
    local sets = ns.DB().themeSets
    if type(sets) ~= "table" then return end
    local merged = Lib.MergeHD(sets, Themes.Current(), settingsOf(ns.DB()), function(hdId, set)
        local classic = sets[Themes.CLASSIC] or (Themes.Current() == Themes.CLASSIC and settingsOf(ns.DB()))
        return not (classic and same(set, Themes.Seed(hdId, classic)))
    end)
    if merged then use(merged) end
    if not Lib.NeedsReseed(sets, OWN_REVISION) then return end
    local current, base = Themes.Current(), sets[Themes.CLASSIC]
    storedSets()
    if current == Themes.CLASSIC or not base then return end
    use(Themes.Seed(current, base))
end

ns.On("PLAYER_LOGIN", Themes.Upgrade)

-- For a central theme picker in another addon: the same as choosing a
-- theme in our options (the window and an open options window follow
-- Settings.Changed).
Lib.Register(ADDON, {
    title = ns.L.ADDON_NAME,
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
})

-- "Apply to all Forever addons" (the options' theme rows): the other addons
-- registered above.
function Themes.HasOthers() return #Lib.Others(ADDON) > 0 end

-- Every other addon onto this theme and, where that theme has it, this
-- colour. Returns how many switched.
function Themes.ApplyToAll()
    return Lib.ApplyToAll(ADDON, Themes.Current(), Themes.Color())
end
