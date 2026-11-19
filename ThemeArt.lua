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
-- art.header is false). No solid shadow: it would reach outside. A
-- framed theme (Azeroth, Goblin) puts its frame round the ring's outside,
-- still within that edge, the ornaments on the frame's corners, and its
-- banner over the header (a texture instead of the strip's colour).
-- Everything is a child of its frame: it shows, hides and resizes with it.
-- Plain textures only, nothing clickable. The textures come with the
-- embedded LibForeverThemes, as Pitwall's wedge rule.
local ThemeArt = {}
ns.ThemeArt = ThemeArt

local Lib = LibForeverThemes
local OVER_LEVELS = 20   -- the ornaments lie above every part of the frame
local BANNER_GAP = 4     -- the grip or title past the banner's end

local function build(frame)
    local art = {}
    -- Below the body colour (sublevel 0).
    art.back = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    art.strip = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    art.wedge = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    art.ends = {}
    for i = 1, 2 do art.ends[i] = frame:CreateTexture(nil, "BACKGROUND", nil, -5) end
    -- Its own rounding, concentric with the ring.
    art.clip = { mask = frame:CreateMaskTexture() }
    art.over = CreateFrame("Frame", nil, frame)
    art.over:SetAllPoints(frame)
    art.over:SetFrameLevel(frame:GetFrameLevel() + OVER_LEVELS)
    -- The frame below the ornaments; it lies outside the backdrop, nothing covers it.
    art.frame = {}
    for i = 1, 4 do art.frame[i] = art.over:CreateTexture(nil, "ARTWORK") end
    art.ornaments = {}
    for i = 1, 4 do art.ornaments[i] = art.over:CreateTexture(nil, "OVERLAY") end
    art.rule = art.over:CreateTexture(nil, "OVERLAY")
    frame.themeArt = art
    return art
end

local function paintBack(texture, look)
    texture:SetTexture(Lib.Texture(ns.Themes.Back(look)), "REPEAT", "REPEAT")
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
            piece:SetTexture(Lib.Texture(look.ornament))
            local m = ns.Corners.COORDS[i]
            piece:SetTexCoord(m[1], m[2], m[3], m[4])
            piece:SetVertexColor(c[1], c[2], c[3], c[4])
        end
    end
end

-- The rule along the top, over the ring, inside the edge.
local function placeRule(art, look, ring)
    art.rule:SetShown(look.rule ~= nil)
    if not look.rule then return end
    art.rule:ClearAllPoints()
    art.rule:SetPoint("TOPLEFT", art.back, "TOPLEFT", -ring, ring)
    art.rule:SetPoint("TOPRIGHT", art.back, "TOPRIGHT", ring, ring)
    art.rule:SetHeight(look.ruleSize)
    art.rule:SetColorTexture(look.rule[1], look.rule[2], look.rule[3], look.rule[4])
end

-- A banner end's width per height (the file is half as wide as high).
local BANNER_END = 0.5
local function bannerEndWidth(height) return math.floor(height * BANNER_END + 0.5) end

-- The banner's two ends (left as drawn, right mirrored) at the strip's
-- ends; returns how far in the strip's middle starts on each side.
local function placeEnds(art, look, height)
    local shown = look.banner ~= nil and look.bannerEnd ~= nil
    for _, e in ipairs(art.ends) do e:SetShown(shown) end
    if not shown then return 0 end
    local w = bannerEndWidth(height)
    for i, e in ipairs(art.ends) do
        local point = i == 1 and "TOPLEFT" or "TOPRIGHT"
        e:ClearAllPoints()
        e:SetPoint(point, art.back, point, 0, 0)
        e:SetSize(w, height)
        e:SetTexture(Lib.Texture(look.bannerEnd))
        if i == 1 then e:SetTexCoord(0, 1, 0, 1) else e:SetTexCoord(1, 0, 0, 1) end
        e:SetVertexColor(1, 1, 1, 1)
    end
    return w
end

-- The strip's fill: the banner (stretched, or repeated at its own size) or the colour.
local function paintStrip(strip, look)
    local tile = look.banner ~= nil and look.bannerTile == true
    strip:SetHorizTile(tile)
    strip:SetVertTile(tile)
    if look.banner then
        strip:SetTexture(Lib.Texture(look.banner), tile and "REPEAT" or nil, tile and "REPEAT" or nil)
        strip:SetTexCoord(0, 1, 0, 1)
        strip:SetVertexColor(1, 1, 1, 1)
    else
        strip:SetColorTexture(look.strip[1], look.strip[2], look.strip[3], look.strip[4])
    end
end

-- The header's strip (or banner) over the backdrop (inset: the backdrop's
-- from the frame) and the wedge at its left. stripHeight: a thinner strip
-- (Goblin's warning stripes, no text on them).
local function placeStrip(art, look, inset)
    local height = ns.Header.HEIGHT - inset
    local shown = look.strip ~= nil or look.banner ~= nil
    art.strip:SetShown(shown)
    local endW = placeEnds(art, look, height)
    if shown then
        art.strip:ClearAllPoints()
        art.strip:SetPoint("TOPLEFT", art.back, "TOPLEFT", endW, 0)
        art.strip:SetPoint("TOPRIGHT", art.back, "TOPRIGHT", -endW, 0)
        art.strip:SetHeight(look.stripHeight or height)
        paintStrip(art.strip, look)
    end
    art.wedge:SetShown(look.wedge ~= nil)
    if look.wedge then
        art.wedge:ClearAllPoints()
        art.wedge:SetPoint("TOPLEFT", art.back, "TOPLEFT", 0, 0)
        art.wedge:SetSize(height, height)
        art.wedge:SetTexture(Lib.Texture(look.wedge))
        art.wedge:SetTexCoord(0, Lib.WEDGE_PART, 0, 1)
        local c = ns.Themes.WedgeColor(look)
        art.wedge:SetVertexColor(c[1], c[2], c[3], c[4])
    end
end

-- The frame's four strips round the ring's outside (ring: its width from
-- the backdrop), the top and bottom ones across the corners; its material
-- repeats at its own size.
local function placeFrame(art, look, ring, frameW)
    for _, s in ipairs(art.frame) do s:SetShown(frameW > 0) end
    if frameW == 0 then return end
    local o = ring + frameW
    local spots = {
        { "TOPLEFT", -o, o, "TOPRIGHT", o, ring },
        { "BOTTOMLEFT", -o, -ring, "BOTTOMRIGHT", o, -o },
        { "TOPLEFT", -o, ring, "BOTTOMLEFT", -ring, -ring },
        { "TOPRIGHT", ring, ring, "BOTTOMRIGHT", o, -ring },
    }
    for i, s in ipairs(art.frame) do
        local p = spots[i]
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", art.back, p[1], p[2], p[3])
        s:SetPoint("BOTTOMRIGHT", art.back, p[4], p[5], p[6])
        s:SetTexture(Lib.Texture(look.frame), "REPEAT", "REPEAT")
        s:SetHorizTile(true)
        s:SetVertTile(true)
        s:SetVertexColor(1, 1, 1, 1)
    end
end

-- The frame's width under a framed theme (look: its art), else 0.
local function frameWidth(look)
    return look and look.frame and ns.Border.Snap(look.frameSize, 1) or 0
end

local function ringWidth(style, size)
    return style ~= "NONE" and ns.Border.Snap(size, 1) or 0
end

-- Classic's ring width: Classic's edge is the frame plus that.
local function classicRing()
    local set, D = ns.Themes.ClassicSet() or {}, ns.Settings.DEFAULTS
    return ringWidth(set.borderStyle or D.borderStyle, set.borderSize or D.borderSize)
end

-- The backdrop's inset from the frame: the ring's (and a theme frame's)
-- outer edge on Classic's (negative for a ring thinner than Classic's).
local function backInset(look)
    return ringWidth(S("borderStyle"), S("borderSize")) + frameWidth(look) - classicRing()
end

-- Where the header's grip (else its title) starts under a theme with a
-- wedge or banner ends, from the header's left (= the frame's); nil without.
function ThemeArt.TitleLeft()
    local look = ns.Themes.Spec(ns.Themes.Current()).art
    if not (look and (look.wedge or look.banner and look.bannerEnd)) then return nil end
    local inset = backInset(look)
    if not look.wedge then return inset + bannerEndWidth(ns.Header.HEIGHT - inset) + BANNER_GAP end
    return inset + Lib.WedgeReach(ns.Header.HEIGHT - inset, ns.Header.HEIGHT / 2 - inset) + Lib.TITLE_GAP
end

-- How far the header's buttons start in from the right: past a banner's
-- end, else 0.
function ThemeArt.ButtonsRight()
    local look = ns.Themes.Spec(ns.Themes.Current()).art
    if not (look and look.banner and look.bannerEnd) then return 0 end
    local inset = backInset(look)
    return inset + bannerEndWidth(ns.Header.HEIGHT - inset)
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
        art.strip:Hide()
        art.wedge:Hide()
        art.rule:Hide()
        for _, piece in ipairs(art.ornaments) do piece:Hide() end
        for _, piece in ipairs(art.frame) do piece:Hide() end
        for _, piece in ipairs(art.ends) do piece:Hide() end
        ns.Corners.Fit(art.clip, art.back, 0, { art.back })
        return frame, radius
    end
    local ring = ringWidth(S("borderStyle"), S("borderSize"))
    local frameW = frameWidth(look)
    local inset = backInset(look)
    art.back:ClearAllPoints()
    art.back:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    art.back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    paintBack(art.back, look)
    ns.Corners.Fit(art.clip, art.back, radius, { art.back })
    local body = inset + (look.padding or 0)
    local top = look.header == false and body or ns.Header.HEIGHT
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", body, -top)
    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -body, body)
    placeFrame(art, look, ring, frameW)
    placeOrnaments(art, look, ring + frameW)
    placeRule(art, look, ring)
    placeStrip(art, look, inset)
    return art.back, radius
end
