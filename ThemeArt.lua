local _, ns = ...
local S = ns.Settings.Get

-- The theme's art beyond settings (Themes.lua), as Forever Unit Frames'
-- (Elements/ThemeArt.lua), on every frame that wears the window's look
-- (Window.ApplyLook: the window, the details panel, the activity popup):
-- a tiled backdrop under the frame, the border ring round it, and corner
-- ornaments inside the ring's outer corners. A theme never draws outside
-- the edge Classic has (frame plus Classic's ring; only the soft shadow
-- reaches further): windows stacked edge to edge in Classic must not
-- overlap under a theme. So the ring sits inside that edge, the backdrop
-- shows as a band `padding` wide inside the ring, and the dark body
-- colour starts within it; the frames' inner padding (8) hosts the band,
-- the content keeps its place. The header shows the art too (unless
-- art.header is false). No solid shadow: it would reach outside.
-- Everything is a child of its frame: it shows, hides and resizes with it.
-- Plain textures only, nothing clickable. The textures come from Forever
-- Unit Frames (tools/make_themes.py there).
local ThemeArt = {}
ns.ThemeArt = ThemeArt

local PATH = "Interface\\AddOns\\ForeverGroupFinder\\Media\\Themes\\"
local OVER_LEVELS = 20   -- the ornaments lie above every part of the frame

local function build(frame)
    local art = {}
    -- Below the body colour (sublevel 0).
    art.back = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    -- Its own rounding, concentric with the ring.
    art.clip = { mask = frame:CreateMaskTexture() }
    art.over = CreateFrame("Frame", nil, frame)
    art.over:SetAllPoints(frame)
    art.over:SetFrameLevel(frame:GetFrameLevel() + OVER_LEVELS)
    art.ornaments = {}
    for i = 1, 4 do art.ornaments[i] = art.over:CreateTexture(nil, "OVERLAY") end
    frame.themeArt = art
    return art
end

local function paintBack(texture, look)
    texture:SetTexture(PATH .. ns.Themes.Back(look), "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    local tint = ns.Themes.Tint(look) or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    texture:Show()
end

-- Ornaments inside the ring's outer corners (ring: its width; the
-- backdrop's corner is the ring's inner one), look.ornamentInset inwards.
local function placeOrnaments(art, look, ring)
    local wanted = {}
    for _, i in ipairs(look.ornament and look.corners or {}) do wanted[i] = true end
    local size, inset = look.ornamentSize or 12, math.max(0, look.ornamentInset or 0) - ring
    local c = look.ornamentColor or { 1, 1, 1, 1 }
    for i, piece in ipairs(art.ornaments) do
        piece:SetShown(wanted[i] == true)
        if wanted[i] then
            local point = ns.Corners.POINTS[i]
            local dx = (i == 1 or i == 3) and inset or -inset
            local dy = (i <= 2) and -inset or inset
            piece:ClearAllPoints()
            piece:SetPoint(point, art.back, point, dx, dy)
            piece:SetSize(size, size)
            piece:SetTexture(PATH .. look.ornament)
            local m = ns.Corners.COORDS[i]
            piece:SetTexCoord(m[1], m[2], m[3], m[4])
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

local function ringWidth(style, size)
    return style ~= "NONE" and ns.Border.Snap(size, 1) or 0
end

-- Classic's ring width: Classic's edge is the frame plus that.
local function classicRing()
    local set, D = ns.Themes.ClassicSet() or {}, ns.Settings.DEFAULTS
    return ringWidth(set.borderStyle or D.borderStyle, set.borderSize or D.borderSize)
end

-- The current theme's art on frame (with .bg). radius: the frame's corner
-- radius. Returns the box the border goes round and its radius: the
-- frame itself for CLASSIC, the backdrop for a theme.
function ThemeArt.Style(frame, radius)
    local look = ns.Themes.Spec(ns.Themes.Current()).art
    local art = frame.themeArt or build(frame)
    frame.bg:ClearAllPoints()
    if not look then
        frame.bg:SetAllPoints()
        art.back:Hide()
        for _, piece in ipairs(art.ornaments) do piece:Hide() end
        ns.Corners.Fit(art.clip, art.back, 0, { art.back })
        return frame, radius
    end
    -- The ring's outer edge on Classic's: the backdrop (its inner edge)
    -- that much inside the frame; negative for a ring thinner than Classic's.
    local ring = ringWidth(S("borderStyle"), S("borderSize"))
    local inset = ring - classicRing()
    art.back:ClearAllPoints()
    art.back:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    art.back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    paintBack(art.back, look)
    ns.Corners.Fit(art.clip, art.back, radius, { art.back })
    local body = inset + (look.padding or 0)
    local top = look.header == false and body or ns.Header.HEIGHT
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", body, -top)
    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -body, body)
    placeOrnaments(art, look, ring)
    return art.back, radius
end
