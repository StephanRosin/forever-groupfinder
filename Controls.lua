local ADDON, ns = ...
local Settings, Media = ns.Settings, ns.Media

-- Small controls of the finder window in the FOREVER look (gold on dark,
-- Friz Quadrata): text, buttons, chips, check boxes, edit boxes, a scroll
-- area. Plain frames only; nothing here is protected.
local Controls = {}
ns.Controls = Controls

Controls.GOLD = { 1, 0.83, 0.35 }
Controls.EDGE = { 0.66, 0.48, 0.13 }
Controls.DIM = { 0.55, 0.54, 0.5 }
Controls.TEXT = { 0.91, 0.89, 0.82 }
Controls.GREEN = { 0.25, 0.75, 0.37 }
Controls.RED = { 0.82, 0.38, 0.31 }
Controls.GREY = { 0.47, 0.47, 0.47 }
Controls.ACCENT = { 0.31, 0.76, 0.97 }
Controls.DISABLED_ALPHA = 0.4
local WHITE = "Interface\\Buttons\\WHITE8X8"
local WHEEL_STEP = 40

-- A font string in one of the text styles (Settings.TEXT_STYLES); restyle
-- with Controls.Restyle after a settings change.
function Controls.Text(parent, styleName, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs.styleName = styleName
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    Controls.Restyle(fs)
    return fs
end

-- color overrides the style's colour (kept until the next call); a font
-- string with sizeKey takes its size from that setting (button text).
function Controls.Restyle(fs, color)
    local style = Settings.TextStyle(fs.styleName)
    if color then style.color = color end
    if fs.sizeKey then style.size = Settings.Get(fs.sizeKey) end
    Media.ApplyText(fs, style)
end

function Controls.Color(fs, c)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- A one pixel outline inside frame.
function Controls.Outline(frame, c, layer)
    local edges = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, layer or "BORDER")
        t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    return edges
end

function Controls.PaintOutline(edges, c)
    for _, t in ipairs(edges) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

function Controls.Tooltip(owner, text, anchor)
    if type(text) ~= "string" or text == "" then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function hideTooltip() GameTooltip:Hide() end

-- Buttons -----------------------------------------------------------------------

local function paintButton(b)
    local hover = b.hover and not b.off
    local c = (b.on or b.primary) and Controls.GOLD or Controls.EDGE
    Controls.PaintOutline(b.edges, hover and Controls.GOLD or c)
    if b.primary then
        -- The main action of a block: a brighter gold face.
        b.bg:SetGradient("VERTICAL", CreateColor(0.42, 0.3, 0.07, 0.95),
            hover and CreateColor(0.78, 0.58, 0.16, 0.95) or CreateColor(0.62, 0.46, 0.12, 0.95))
    else
        b.bg:SetGradient("VERTICAL", CreateColor(0.13, 0.1, 0.04, 0.95),
            hover and CreateColor(0.3, 0.23, 0.09, 0.95) or CreateColor(0.23, 0.17, 0.06, 0.95))
    end
    b:SetAlpha(b.off and Controls.DISABLED_ALPHA or 1)
end

-- Sizes: every button and chip takes its height and text size from the
-- settings (buttonHeight, chipHeight, buttonTextSize; Appearance page) and
-- follows them live (Controls.ApplySizes). size = "button" (default),
-- "chip", "row" (in a list row: no taller than the row allows) or "fixed"
-- (opts.height).
local sized = setmetatable({}, { __mode = "k" })

function Controls.ButtonHeight() return Settings.Get("buttonHeight") end
function Controls.ChipHeight() return Settings.Get("chipHeight") end

local function heightOf(b)
    if b.size == "fixed" then return b.fixedHeight end
    if b.size == "chip" then return Controls.ChipHeight() end
    if b.size == "row" then return math.min(Controls.ButtonHeight(), Settings.Get("playerRowHeight") - 8) end
    return Controls.ButtonHeight()
end

-- Height and text size from the settings; the label keeps its colour.
function Controls.Resize(b)
    b:SetHeight(heightOf(b))
    Controls.Restyle(b.label, b.labelColor)
    local icon = math.max(8, math.floor(Settings.Get("buttonTextSize") - 2))
    if b.icon then b.icon:SetSize(icon, icon) end
    if b.Fit and b.fitted then b:Fit() end
end

function Controls.ApplySizes()
    for b in pairs(sized) do Controls.Resize(b) end
end

-- opts = { text, width, height, size, icon, onClick(self, mouse), tip (string or function),
--         primary (the block's main action: a gold face) }.
-- SetOff(true, tip) greys the button out: clicks do nothing, the tooltip
-- still explains why (a disabled client button would not show it).
function Controls.Button(parent, opts)
    local b = CreateFrame("Button", nil, parent)
    b.size = opts.size or (opts.height and "fixed") or "button"
    b.fixedHeight = opts.height
    b:SetSize(opts.width or 60, heightOf(b))
    sized[b] = true
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(WHITE)
    b.edges = Controls.Outline(b, Controls.EDGE)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label.styleName, b.label.sizeKey = "small", "buttonTextSize"
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(false)
    b.label:SetPoint("CENTER", opts.icon and 6 or 0, 0)
    b.labelColor = Controls.GOLD
    Controls.Restyle(b.label, b.labelColor)
    if opts.icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        local icon = math.max(8, math.floor(Settings.Get("buttonTextSize") - 2))
        b.icon:SetSize(icon, icon)
        b.icon:SetTexture(Media.Icon(opts.icon))
        b.icon:SetVertexColor(Controls.GOLD[1], Controls.GOLD[2], Controls.GOLD[3])
    end
    b.tip, b.onClick, b.primary = opts.tip, opts.onClick, opts.primary
    function b.SetLabel(self, text)
        self.label:SetText(text or "")
        if self.icon then
            self.icon:ClearAllPoints()
            self.icon:SetPoint("RIGHT", self.label, "LEFT", -3, 0)
        end
    end
    function b.SetOff(self, off, offTip)
        self.off, self.offTip = off and true or false, offTip
        paintButton(self)
    end
    function b.SetOn(self, on)
        self.on = on and true or false
        self.labelColor = on and Controls.GOLD or Controls.TEXT
        Controls.Color(self.label, self.labelColor)
        paintButton(self)
    end
    b:SetScript("OnClick", function(self, mouse)
        if self.off then return end
        if self.onClick then self.onClick(self, mouse) end
    end)
    b:SetScript("OnEnter", function(self)
        self.hover = true
        paintButton(self)
        local tip = self.off and self.offTip or self.tip
        if type(tip) == "function" then tip = tip(self) end
        Controls.Tooltip(self, tip)
    end)
    b:SetScript("OnLeave", function(self)
        self.hover = false
        paintButton(self)
        hideTooltip()
    end)
    b:SetLabel(opts.text)
    paintButton(b)
    return b
end

-- A chip: a small toggle with a gold edge when on. Width follows the text.
function Controls.Chip(parent, opts)
    local c = Controls.Button(parent, { text = opts.text, size = opts.size or "chip", onClick = opts.onClick,
        tip = opts.tip, icon = opts.icon })
    function c.Fit(self)
        self.fitted = true
        local icon = self.icon and (self.icon:GetWidth() + 16) or 14
        self:SetWidth(math.floor(self.label:GetStringWidth() + icon + 0.5))
        return self:GetWidth()
    end
    c:SetOn(false)
    c:Fit()
    return c
end

-- A tag: read-only information (an activity of my listing), not a
-- button: a faint fill, no border, normal text. Hovering may show a tip;
-- clicks go through. opts = { text, tip }. SetLabel, Fit like a chip.
Controls.TAG_FILL = { 1, 1, 1, 0.08 }
function Controls.Tag(parent, opts)
    local t = CreateFrame("Frame", nil, parent)
    t.size = "chip"
    t:SetSize(40, Controls.ChipHeight())
    sized[t] = true
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetColorTexture(Controls.TAG_FILL[1], Controls.TAG_FILL[2], Controls.TAG_FILL[3], Controls.TAG_FILL[4])
    t.label = t:CreateFontString(nil, "OVERLAY")
    t.label.styleName, t.label.sizeKey = "chip", "buttonTextSize"
    t.label:SetWordWrap(false)
    t.label:SetPoint("CENTER")
    t.labelColor = Controls.TEXT
    Controls.Restyle(t.label, t.labelColor)
    t.tip = opts and opts.tip
    function t.SetLabel(self, text) self.label:SetText(text or "") end
    function t.Fit(self)
        self.fitted = true
        self:SetWidth(math.floor(self.label:GetStringWidth() + 12 + 0.5))
        return self:GetWidth()
    end
    if t.SetMouseMotionEnabled then
        t:SetMouseMotionEnabled(true)
        if t.SetMouseClickEnabled then t:SetMouseClickEnabled(false) end
    end
    t:SetScript("OnEnter", function(self)
        local tip = self.tip
        if type(tip) == "function" then tip = tip(self) end
        Controls.Tooltip(self, tip)
    end)
    t:SetScript("OnLeave", hideTooltip)
    t:SetLabel(opts and opts.text)
    return t
end

-- Check boxes ------------------------------------------------------------------------

-- A square with a check mark; the whole row is the click target (the caller's).
function Controls.CheckMark(parent, size)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(size, size)
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    box.bg:SetColorTexture(0.07, 0.07, 0.07, 1)
    box.edges = Controls.Outline(box, Controls.EDGE)
    box.check = box:CreateTexture(nil, "ARTWORK")
    box.check:SetPoint("CENTER")
    box.check:SetSize(size, size)
    box.check:SetTexture(Media.Icon("Check"))
    box.check:SetVertexColor(Controls.GOLD[1], Controls.GOLD[2], Controls.GOLD[3])
    function box.SetChecked(self, on)
        self.checked = on and true or false
        self.check:SetShown(self.checked)
    end
    function box.GetChecked(self) return self.checked end
    box:SetChecked(false)
    return box
end

-- A check box with its label; the whole line is the click target.
-- opts = { text, onClick, tip }. SetChecked / .on; Fit() sizes it.
function Controls.CheckLabel(parent, opts)
    local b = CreateFrame("Button", nil, parent)
    b:RegisterForClicks("LeftButtonUp")
    b.box = Controls.CheckMark(b, 11)
    b.box:SetPoint("LEFT", 0, 0)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text.styleName, b.text.sizeKey = "small", "buttonTextSize"
    b.text:SetWordWrap(false)
    b.text:SetPoint("LEFT", b.box, "RIGHT", 4, 0)
    Controls.Restyle(b.text, Controls.TEXT)
    b.text:SetText(opts.text or "")
    b.tip = opts.tip
    function b.SetChecked(self, on)
        self.on = on and true or false
        self.box:SetChecked(self.on)
    end
    function b.SetLabel(self, text) self.text:SetText(text or "") end
    function b.Fit(self)
        Controls.Restyle(self.text, Controls.TEXT)
        self:SetSize(math.floor(11 + 4 + self.text:GetStringWidth() + 2 + 0.5), Controls.ChipHeight())
        return self:GetWidth()
    end
    b:SetScript("OnClick", function(self, mouse) if opts.onClick then opts.onClick(self, mouse) end end)
    b:SetScript("OnEnter", function(self)
        local tip = self.tip
        if type(tip) == "function" then tip = tip(self) end
        Controls.Tooltip(self, tip)
    end)
    b:SetScript("OnLeave", hideTooltip)
    b:Fit()
    return b
end

-- Edit boxes -------------------------------------------------------------------------

-- A one-line edit box with a dark field and a grey placeholder.
function Controls.EditBox(parent, placeholder, maxLetters)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetAutoFocus(false)
    e:SetHeight(18)
    e:SetTextInsets(5, 5, 0, 0)
    e:SetMaxLetters(maxLetters or 60)
    local style = Settings.TextStyle("comment")
    e:SetFont(Media.FontPath(style.font), style.size, "")
    e:SetTextColor(Controls.TEXT[1], Controls.TEXT[2], Controls.TEXT[3], 1)
    e.bg = e:CreateTexture(nil, "BACKGROUND")
    e.bg:SetAllPoints()
    e.bg:SetColorTexture(0.06, 0.06, 0.06, 0.95)
    e.edges = Controls.Outline(e, { 0.2, 0.2, 0.2, 1 })
    e.hint = Controls.Text(e, "small")
    e.hint:SetPoint("LEFT", 6, 0)
    e.hint:SetText(placeholder or "")
    local function updateHint(self)
        local text = self:GetText()
        self.hint:SetShown(text == nil or text == "")
    end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) Controls.PaintOutline(self.edges, Controls.EDGE) end)
    e:SetScript("OnEditFocusLost", function(self) Controls.PaintOutline(self.edges, { 0.2, 0.2, 0.2, 1 }) end)
    e.updateHint = updateHint
    e:HookScript("OnTextChanged", updateHint)
    return e
end

-- Scrolling --------------------------------------------------------------------------

-- A scroll frame with a child and a thin thumb. area.child holds the
-- content; call area:SetContentHeight(h) after a layout.
function Controls.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    scroll.thumb = scroll:CreateTexture(nil, "OVERLAY")
    scroll.thumb:SetWidth(2)
    scroll.thumb:SetColorTexture(Controls.EDGE[1], Controls.EDGE[2], Controls.EDGE[3], 0.7)
    scroll.thumb:Hide()
    scroll.contentHeight = 0
    function scroll.ViewHeight(self) return self.viewHeight or self:GetHeight() end
    function scroll.UpdateThumb(self)
        local view, content = self:ViewHeight(), self.contentHeight
        local range = math.max(0, content - view)
        if range <= 0 or view <= 0 then
            self.thumb:Hide()
            return
        end
        local thumbH = math.max(16, view * view / content)
        self.thumb:SetHeight(thumbH)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(view - thumbH) * self:GetVerticalScroll() / range)
        self.thumb:Show()
    end
    function scroll.SetContentHeight(self, h)
        self.contentHeight = h
        child:SetHeight(math.max(1, h))
        local range = math.max(0, h - self:ViewHeight())
        if self:GetVerticalScroll() > range then self:SetVerticalScroll(range) end
        self:UpdateThumb()
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, self.contentHeight - self:ViewHeight())
        local v = self:GetVerticalScroll() - delta * WHEEL_STEP
        self:SetVerticalScroll(math.max(0, math.min(range, v)))
        self:UpdateThumb()
    end)
    return scroll
end

-- Times ------------------------------------------------------------------------------

-- "4 s", "3 min", "2 h" from seconds; nil for anything but a number.
function Controls.Age(seconds)
    if type(seconds) ~= "number" then return nil end
    local L = ns.L
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return L.AGE_SECONDS:format(seconds) end
    if seconds < 3600 then return L.AGE_MINUTES:format(math.floor(seconds / 60)) end
    return L.AGE_HOURS:format(math.floor(seconds / 3600))
end
