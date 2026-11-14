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
Themes.IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL" }

-- Raised whenever SPECS change a look: theme sets stored before are made
-- anew from CLASSIC (Themes.Upgrade), so a changed theme shows as it is
-- now. CLASSIC is never touched.
Themes.REVISION = 3

-- The theme fonts have Latin letters only: on a client whose names are
-- written otherwise the header keeps its font.
local LATIN_CLIENTS = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true,
    ptBR = true }

-- look: settings the theme sets (Settings.DEFAULTS keys). font: the
-- header's font; fontSizeAdd: how much larger it must be to read like the
-- others. The header always has the client's outline (OUTLINE for
-- the comic): a hand-made soft outline under these fonts showed black
-- text in Forever Unit Frames.
-- art (ThemeArt.lua): back = backdrop file in Media/Themes, tint = its
-- colour (light papers toned down, so they do not glare), padding = the
-- width of the backdrop band inside the ring (band and ring fit in the
-- frames' inner padding of 8), header = false keeps the title on the body
-- colour; ornament = corner piece, corners = which ones (Corners.POINTS
-- order: 1 top left, 2 top right, 3 bottom left, 4 bottom right),
-- ornamentInset = how far in from the ring's outer corner. Nothing
-- reaches outside Classic's edge (ThemeArt.lua).
-- iconColor / iconHoverColor: the header's icons and note in dark ink, for
-- a header on light paper.
-- The body colour stays dark everywhere: the list's light text sits on it.
Themes.SPECS = {
    CLASSIC = {},
    -- Oak boards round the window, a brass rim, brass rivets.
    WOOD = {
        font = "Cinzel",
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.66, 0.48, 0.2, 1 }, cornerRadius = 3,
            bgMode = "SOLID", bgColor = { 0.1, 0.06, 0.02 }, bgAlpha = 100, shadowEnabled = true, shadowAlpha = 60,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 1, 0.86, 0.6 } },
        art = { back = "WoodBack", padding = 5, ornament = "Rivet", corners = { 1, 2, 3, 4 }, ornamentSize = 9,
            ornamentInset = 1 },
    },
    -- Dark navy with a faint grid, a thin cyan line.
    TECH = {
        font = "Space Grotesk",
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.25, 0.88, 0.94, 0.9 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.02, 0.05, 0.08 }, bgAlpha = 100, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.6, 0.95, 1 } },
        art = { back = "TechBack", padding = 4 },
    },
    -- Parchment round the window, a brown ink line, a wax seal.
    PARCHMENT = {
        font = "IM Fell English SC", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 }, cornerRadius = 2,
            bgMode = "SOLID", bgColor = { 0.13, 0.09, 0.05 }, bgAlpha = 100, shadowEnabled = true, shadowAlpha = 45,
            shadowSize = 5, headerFlag = "OUTLINE", headerColor = { 1, 0.93, 0.78 } },
        art = { back = "ParchmentBack", tint = { 0.82, 0.78, 0.72, 1 }, padding = 5, ornament = "Seal", corners = { 3 },
            ornamentSize = 20, ornamentInset = 0 },
    },
    -- Grey granite, a dark chiselled edge, glowing runes.
    RUNESTONE = {
        font = "Marcellus", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 2, borderColor = { 0.1, 0.1, 0.12, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.04, 0.05, 0.06 }, bgAlpha = 100, shadowEnabled = true, shadowAlpha = 70,
            shadowSize = 6, headerFlag = "OUTLINE", headerColor = { 0.55, 1, 0.9 } },
        art = { back = "StoneBack", padding = 5, ornament = "Rune", corners = { 1, 2 }, ornamentSize = 10,
            ornamentInset = 1, ornamentColor = { 0.35, 0.95, 0.85, 1 } },
    },
    -- A mosaic of coloured glass round the window, dark lead, a dark title.
    GLASS = {
        font = "Morpheus", fontSizeAdd = 1,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 0.07, 0.06, 0.05, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0.05, 0.04, 0.06 }, bgAlpha = 100, shadowEnabled = true, shadowAlpha = 55,
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
        font = "Cormorant SC", fontSizeAdd = 2,
        look = { borderStyle = "FLAT", borderSize = 1, borderColor = { 0.86, 0.96, 1, 0.8 }, cornerRadius = 6,
            bgMode = "SOLID", bgColor = { 0.04, 0.12, 0.22 }, bgAlpha = 100, shadowEnabled = true, shadowAlpha = 55,
            shadowSize = 8, headerFlag = "OUTLINE", headerColor = { 0.86, 0.96, 1 } },
        -- The cracks dimmed: the title sits on them.
        art = { back = "FrostBack", padding = 4, tint = { 0.6, 0.62, 0.66, 1 } },
    },
    -- A light pixel frame, scan lines.
    PIXEL = {
        font = "VT323", fontSizeAdd = 4,
        look = { borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 }, cornerRadius = 0,
            bgMode = "SOLID", bgColor = { 0, 0, 0 }, bgAlpha = 100, shadowEnabled = false,
            headerFlag = "OUTLINE", headerColor = { 0.6, 1, 0.5 } },
        art = { back = "PixelBack", padding = 4 },
    },
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

-- A theme's settings made from base (a set): base with the theme's look.
-- Stores only what differs from the defaults, as a profile does.
function Themes.Seed(id, base)
    local spec = Themes.Spec(id)
    local set = settingsOf(base)
    for key, value in pairs(spec.look or {}) do set[key] = copy(value) end
    if spec.font and LATIN_CLIENTS[GetLocale()] then set.headerFont = spec.font end
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
}
