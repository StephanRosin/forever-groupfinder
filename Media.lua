local ADDON, ns = ...

-- Fonts, background textures and bar textures: the game's own, the
-- themes' fonts (Themes.lua), plus every one another addon registers with
-- LibSharedMedia (the library itself is not shipped).
local Media = {}
ns.Media = Media

local ICONS = "Interface\\AddOns\\ForeverGroupFinder\\Media\\"
function Media.Icon(name) return ICONS .. "Icon" .. name .. ".tga" end

Media.BLIZZARD = {
    font = {
        { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",        path = "Fonts\\SKURRI.TTF" },
        { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
    },
    background = {
        { name = "Blizzard Dialog Background Dark", path = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark" },
        { name = "Blizzard Dialog Background", path = "Interface\\DialogFrame\\UI-DialogBox-Background" },
        { name = "Blizzard Dialog Background Gold", path = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background" },
        { name = "Blizzard Tooltip", path = "Interface\\Tooltips\\UI-Tooltip-Background" },
        { name = "Blizzard Parchment", path = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal" },
        { name = "Blizzard Rock", path = "Interface\\FrameGeneral\\UI-Background-Rock" },
        { name = "Blizzard Marble", path = "Interface\\FrameGeneral\\UI-Background-Marble" },
    },
    statusbar = {
        { name = "Solid", path = "Interface\\Buttons\\WHITE8X8" },
        { name = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
        { name = "Blizzard Raid Bar", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    },
}
-- The themes' fonts, shipped in Media/Fonts (SIL Open Font License, see
-- OFL.txt and FONTS.txt there). Latin letters only.
local FONTS = ICONS .. "Fonts\\"
Media.OWN = {
    font = {
        { name = "Bangers", path = FONTS .. "Bangers-Regular.ttf" },
        { name = "Cinzel", path = FONTS .. "Cinzel-Bold.ttf" },
        { name = "Cormorant SC", path = FONTS .. "CormorantSC-Bold.ttf" },
        { name = "IM Fell English SC", path = FONTS .. "IMFeENsc28P.ttf" },
        { name = "Marcellus", path = FONTS .. "Marcellus-Regular.ttf" },
        { name = "Space Grotesk", path = FONTS .. "SpaceGrotesk-Bold.ttf" },
        { name = "VT323", path = FONTS .. "VT323-Regular.ttf" },
    },
    background = {},
    statusbar = {},
}
local SOURCES = { Media.BLIZZARD, Media.OWN }

-- Our font files loaded while the addon loads: a file used for the first
-- time can be refused (ApplyText tries again), so the first restyle
-- should not be its first use.
do
    local holder = CreateFrame("Frame")
    holder:Hide()
    for _, f in ipairs(Media.OWN.font) do holder:CreateFontString():SetFont(f.path, 12, "") end
end

Media.DEFAULT = {
    font = "Fonts\\FRIZQT__.TTF",
    background = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    statusbar = "Interface\\Buttons\\WHITE8X8",
}

local function sharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Every name of a kind ("font", "background", "statusbar"), Blizzard's
-- first, then ours, then LibSharedMedia's sorted.
function Media.Names(kind)
    local names, seen = {}, {}
    for _, source in ipairs(SOURCES) do
        for _, f in ipairs(source[kind]) do
            names[#names + 1] = f.name
            seen[f.name] = true
        end
    end
    local lsm = sharedMedia()
    if lsm then
        local extra = {}
        for _, name in ipairs(lsm:List(kind) or {}) do
            if not seen[name] then extra[#extra + 1] = name end
        end
        table.sort(extra)
        for _, name in ipairs(extra) do names[#names + 1] = name end
    end
    return names
end

-- The file for a name; unknown names get the kind's default.
function Media.Path(kind, name)
    for _, source in ipairs(SOURCES) do
        for _, f in ipairs(source[kind]) do
            if f.name == name then return f.path end
        end
    end
    local lsm = sharedMedia()
    local path = lsm and lsm:Fetch(kind, name, true)
    return path or Media.DEFAULT[kind]
end

function Media.FontPath(name) return Media.Path("font", name) end

-- Whether a text took the font file asked for. A file the client has not
-- loaded yet (our theme fonts) can be refused on first use and leave the
-- text without a font.
local function hasFont(fs, path)
    local got = fs:GetFont()
    if type(got) ~= "string" then return false end
    local function plain(p) return (p:lower():gsub("/", "\\")) end
    return plain(got) == plain(path)
end
-- How often, and how far apart, a refused font is tried again.
local FONT_RETRIES, FONT_RETRY_DELAY = 8, 0.25

-- A text style (Settings.TextStyle) on a font string. SHADOW is a drop
-- shadow, the other flags are outlines. A refused font: the default font
-- meanwhile, the wanted one tried again a few times, then a chat line.
function Media.ApplyText(fs, style, retries)
    local flag = style.flag
    local outline = (flag == "OUTLINE" or flag == "THICKOUTLINE") and flag or ""
    local path = Media.FontPath(style.font)
    local wanted = path .. "|" .. style.size .. "|" .. outline
    fs.fontWanted = wanted
    if not (fs:SetFont(path, style.size, outline) and hasFont(fs, path)) then
        fs:SetFont(Media.DEFAULT.font, style.size, outline)
        retries = retries or FONT_RETRIES
        if retries > 0 then
            C_Timer.After(FONT_RETRY_DELAY, function()
                -- Restyled since: that call has its own tries.
                if fs.fontWanted == wanted then Media.ApplyText(fs, style, retries - 1) end
            end)
        else
            ns.Print(ns.L.MSG_FONT_FAILED, style.font)
        end
    end
    if flag == "SHADOW" then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
    local c = style.color
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- A background texture: SOLID (colour), GRADIENT (colour fading down) or
-- TEXTURE (tiled, alpha only). alpha 0..1.
function Media.ApplyBackground(tex, mode, color, alpha, textureName)
    if mode == "TEXTURE" then
        tex:SetTexture(Media.Path("background", textureName), "REPEAT", "REPEAT")
        tex:SetHorizTile(true)
        tex:SetVertTile(true)
        tex:SetVertexColor(1, 1, 1, alpha)
        return
    end
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetColorTexture(1, 1, 1, 1)
    local c = color
    local top = CreateColor(c[1], c[2], c[3], alpha)
    local bottom = mode == "GRADIENT" and CreateColor(c[1], c[2], c[3], alpha * 0.35) or top
    tex:SetGradient("VERTICAL", bottom, top)
end
