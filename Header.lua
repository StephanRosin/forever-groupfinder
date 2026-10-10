local ADDON, ns = ...
local Settings, Media, Controls = ns.Settings, ns.Media, ns.Controls
local S = Settings.Get

-- The header bar of our frames, built as Forever Quest Log's tracker header
-- (Tracker.lua): 32 high, a gold shine from the bottom up (clipped by the
-- frame's rounded corners: Window.ApplyLook passes header.shine to
-- Corners.Fit), a gold line at the bottom (the headerLine setting), the
-- blue grip at the left while the frame can be moved, the title in the
-- header text style (10 from the left, 26 with the grip), a small grey note
-- after the title (the quest log's count; our list's age), and flat icon
-- buttons from the right edge: 22 square, a 14 icon, 5 in, 1 apart,
-- idle / hover / on / off colours as the quest log's. Used by the window,
-- the details panel and the activity popup.
local Header = {}
ns.Header = Header

Header.HEIGHT = 32
Header.BUTTON = 22
local ICON = 14
local RIGHT_IN, BUTTON_GAP = 5, 1
local TITLE_X, TITLE_X_GRIP = 10, 26
Header.IDLE = { 0.73, 0.64, 0.48 }
Header.HOVER = { 1, 0.88, 0.54 }
Header.ON = { 1, 0.82, 0.29 }
Header.OFF = { 0.45, 0.42, 0.36 }
Header.NOTE = { 0.56, 0.54, 0.5 }   -- the note after the title

local function tooltip(owner, tip)
    if type(tip) == "function" then tip = tip(owner) end
    if type(tip) ~= "string" or tip == "" then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

-- Buttons ---------------------------------------------------------------------------------------

-- The resting colour: on / off for a toggle (isActive), idle otherwise;
-- activeColor / offColor override them (the lock: blue while unlocked;
-- the refresh button: gold while the list is outdated, idle otherwise).
function Header.ButtonColor(b)
    if b.isActive and b.isActive() then return b.activeColor or Header.ON end
    if b.isActive then return b.offColor or Header.OFF end
    return Header.IDLE
end

function Header.Paint(b, color)
    color = color or (b.hover and Header.HOVER) or Header.ButtonColor(b)
    b.paintColor = color
    if b.icon then b.icon:SetVertexColor(color[1], color[2], color[3]) end
    for _, t in ipairs(b.lines or {}) do t:SetColorTexture(color[1], color[2], color[3], 1) end
end

local function newButton(h, tip, onClick, isActive)
    local b = CreateFrame("Button", nil, h)
    b:SetSize(Header.BUTTON, Header.BUTTON)
    b.tip, b.isActive = tip, isActive
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self, mouse) onClick(self, mouse) end)
    b:SetScript("OnEnter", function(self)
        self.hover = true
        Header.Paint(self)
        tooltip(self, self.tip)
    end)
    b:SetScript("OnLeave", function(self)
        self.hover = false
        Header.Paint(self)
        GameTooltip:Hide()
    end)
    h.buttons[#h.buttons + 1] = b
    return b
end

-- A flat icon button (Media icon name), placed right to left in the order
-- the buttons are made.
function Header.Button(h, icon, tip, onClick, isActive)
    local b = newButton(h, tip, onClick, isActive)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(Media.Icon(icon))
    Header.Paint(b)
    return b
end

-- The close button: a drawn cross (Media has no close icon), as the
-- options window's, in the header buttons' size and colours.
function Header.CloseButton(h, tip, onClick)
    local b = newButton(h, tip, onClick)
    b.lines = {}
    for i, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetSize(ICON, 2)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    Header.Paint(b)
    return b
end

-- The note's style: the small text's font, 3 smaller than the header, no
-- outline, grey (the quest log's count).
function Header.NoteStyle()
    local style = Settings.TextStyle("small")
    style.size = math.max(8, S("headerSize") - 3)
    style.flag = ""
    style.color = Header.NOTE
    return style
end

-- Building --------------------------------------------------------------------------------------

-- A header on frame (frame.header). opts.movable: shows the grip while
-- movable() is true.
function Header.Create(frame, opts)
    opts = opts or {}
    local h = CreateFrame("Button", nil, frame)
    frame.header = h
    h:SetHeight(Header.HEIGHT)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:RegisterForClicks("LeftButtonUp")
    h:EnableMouse(true)
    h.shine = h:CreateTexture(nil, "BACKGROUND", nil, 1)
    h.shine:SetAllPoints()
    h.shine:SetColorTexture(1, 1, 1, 1)
    h.shine:SetGradient("VERTICAL", CreateColor(1, 0.79, 0.19, 0), CreateColor(1, 0.79, 0.19, 0.10))
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT")
    h.line:SetPoint("BOTTOMRIGHT")
    h.line:SetColorTexture(0.78, 0.59, 0.13, 0.45)
    h.grip = h:CreateTexture(nil, "OVERLAY")
    h.grip:SetSize(12, 12)
    h.grip:SetPoint("LEFT", 8, 0)
    h.grip:SetTexture(Media.Icon("Grip"))
    h.grip:SetVertexColor(Controls.ACCENT[1], Controls.ACCENT[2], Controls.ACCENT[3])
    h.grip:Hide()
    h.movable = opts.movable
    h.title = Controls.Text(h, "header")
    h.note = h:CreateFontString(nil, "OVERLAY")
    h.note:SetPoint("BOTTOMLEFT", h.title, "BOTTOMRIGHT", 6, 1)
    h.note:SetJustifyH("LEFT")
    h.note:SetWordWrap(false)
    Media.ApplyText(h.note, Header.NoteStyle())
    h.buttons = {}
    return h
end

-- Fonts, the grip, the title's place, the line, the buttons' places and
-- colours, from the settings. width (the header's): the title is cut off
-- before its note and the buttons.
function Header.Layout(h, width)
    local movable = h.movable ~= nil and h.movable()
    h.grip:SetShown(movable)
    Controls.Restyle(h.title)
    Media.ApplyText(h.note, Header.NoteStyle())
    local left = movable and TITLE_X_GRIP or TITLE_X
    h.title:ClearAllPoints()
    h.title:SetPoint("LEFT", h, "LEFT", left, 0)
    h.line:SetShown(S("headerLine"))
    local x = RIGHT_IN
    for _, b in ipairs(h.buttons) do
        b:ClearAllPoints()
        b:SetPoint("RIGHT", h, "RIGHT", -x, 0)
        x = x + Header.BUTTON + BUTTON_GAP
        Header.Paint(b)
    end
    if width then
        local note = h.note:GetText()
        local noteW = (note and note ~= "") and h.note:GetStringWidth() + 6 or 0
        local room = math.max(20, width - left - x - 4 - noteW)
        h.title:SetWidth(math.min(room, h.title:GetStringWidth() + 2))
    end
end
