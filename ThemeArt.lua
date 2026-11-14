local _, ns = ...
local S = ns.Settings.Get

-- The theme's art beyond settings (Themes.lua), as Forever Unit Frames'
-- (Elements/ThemeArt.lua), on every frame that wears the window's look
-- (Window.ApplyLook: the window, the details panel, the activity popup):
-- a tiled backdrop under the frame reaching `padding` out of it, the
-- border ring round the backdrop (so the art frames the window), corner
-- ornaments at the ring's outer corners and a solid shadow behind it.
-- The body below the header keeps the dark body colour, so the list
-- reads as before; the header shows the art (unless art.header is false).
-- Everything is a child of its frame: it shows, hides and resizes with it.
-- Plain textures only, nothing clickable. The textures come from Forever
-- Unit Frames (tools/make_themes.py there).
local ThemeArt = {}
ns.ThemeArt = ThemeArt

local PATH = "Interface\\AddOns\\ForeverGroupFinder\\Media\\Themes\\"
local OVER_LEVELS = 20   -- the ornaments lie above every part of the frame
local SHADOW_COLOR = { 0, 0, 0, 1 }

local function build(frame)
    local art = {}
    -- Below the body colour (sublevel 0) and the soft shadow (-8 too, but
    -- drawn outside the ring).
    art.shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
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
    texture:SetTexture(PATH .. look.back, "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
    local tint = look.tint or { 1, 1, 1, 1 }
    texture:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    texture:Show()
end

-- Ornaments at the ring's outer corners (extent: the ring's width),
-- look.ornamentInset inwards.
local function placeOrnaments(art, look, extent)
    local wanted = {}
    for _, i in ipairs(look.ornament and look.corners or {}) do wanted[i] = true end
    local size, inset = look.ornamentSize or 12, (look.ornamentInset or 0) - extent
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

local function placeShadow(art, look, extent)
    local shadow, offset = art.shadow, look.hardShadow
    shadow:SetShown(offset ~= nil)
    if not offset then return end
    shadow:ClearAllPoints()
    shadow:SetPoint("TOPLEFT", art.back, "TOPLEFT", offset - extent, extent - offset)
    shadow:SetPoint("BOTTOMRIGHT", art.back, "BOTTOMRIGHT", offset + extent, -offset - extent)
    shadow:SetColorTexture(SHADOW_COLOR[1], SHADOW_COLOR[2], SHADOW_COLOR[3], SHADOW_COLOR[4])
end

-- How far the current theme's art and ring reach out of a frame: the
-- details panel docks this much further away, twice (its own and the
-- window's), so the two rings never cross.
function ThemeArt.Reach()
    local look = ns.Themes.Spec(ns.Themes.Current()).art
    if not look then return 0 end
    local ring = S("borderStyle") ~= "NONE" and ns.Border.Snap(S("borderSize"), 1) or 0
    return (look.padding or 0) + ring
end

-- The current theme's art on frame (with .bg and .header). radius: the
-- frame's corner radius. Returns the box the border goes round and its
-- radius: the frame itself for CLASSIC, the backdrop for a theme.
function ThemeArt.Style(frame, radius)
    local look = ns.Themes.Spec(ns.Themes.Current()).art
    local art = frame.themeArt or build(frame)
    frame.bg:ClearAllPoints()
    if not look then
        frame.bg:SetAllPoints()
        art.back:Hide()
        art.shadow:Hide()
        for _, piece in ipairs(art.ornaments) do piece:Hide() end
        ns.Corners.Fit(art.clip, art.back, 0, { art.back })
        return frame, radius
    end
    if look.header == false then
        frame.bg:SetAllPoints()
    else
        frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -ns.Header.HEIGHT)
        frame.bg:SetPoint("BOTTOMRIGHT")
    end
    local pad = look.padding or 0
    art.back:ClearAllPoints()
    art.back:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
    art.back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
    paintBack(art.back, look)
    local outer = radius > 0 and ns.Corners.Clamp(radius + pad) or 0
    ns.Corners.Fit(art.clip, art.back, outer, { art.back })
    local extent = S("borderStyle") ~= "NONE" and ns.Border.Snap(S("borderSize"), 1) or 0
    placeOrnaments(art, look, extent)
    placeShadow(art, look, extent)
    return art.back, outer
end
