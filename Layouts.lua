local ADDON, ns = ...
local L, Settings, Controls = ns.L, ns.Settings, ns.Controls
local S = Settings.Get

-- Where the window's parts sit. The parts are the same in every layout and
-- built once by Window.lua (all children of the window, never reparented):
-- the activity list (Side.lua), my listing (ListingPanel.lua), the filter
-- chips, the result list (Rows.lua), the group details (Detail.lua) and
-- the leader column (Column.lua). A layout only places them:
--
--   SIDEBAR  the activity list as a column on the left; listing, filters
--            and list on the right; details float beside the window.
--   STACKED  narrow: an activity button at the top opens the activity list
--            in a popup; listing, filters, list below; details float.
--   DETAILS  activity button, filters and list on the left; a fixed column
--            on the right with the open group's details (or, leading a
--            group, the missing roles and fitting players) over my listing.
--
-- Each layout has its own size settings, so switching keeps every size.
local Layouts = {}
ns.Layouts = Layouts

Layouts.ORDER = { "SIDEBAR", "STACKED", "DETAILS" }
local SIZE_KEYS = {
    SIDEBAR = { "width", "height" },
    STACKED = { "stackedWidth", "stackedHeight" },
    DETAILS = { "detailsWidth", "detailsHeight" },
}
Layouts.COLUMN_W = 300     -- the DETAILS layout's right column
local PAD, GAP = 8, 6
local BUTTON_H = 18        -- the activity button
local POPUP_W, POPUP_H, POPUP_HEADER = 250, 380, 24
local POPUP_NAME = "ForeverGroupFinderActivities"

function Layouts.Current()
    local mode = S("layout")
    return SIZE_KEYS[mode] and mode or "SIDEBAR"
end

function Layouts.EmbedsDetail() return Layouts.Current() == "DETAILS" end

-- The width and height settings of a layout (the current one by default).
function Layouts.SizeKeys(mode)
    local keys = SIZE_KEYS[mode or Layouts.Current()]
    return keys[1], keys[2]
end

function Layouts.Width() return S((Layouts.SizeKeys())) end
function Layouts.Height() return S(select(2, Layouts.SizeKeys())) end

function Layouts.Ranges()
    local w, h = Layouts.SizeKeys()
    return Settings.RANGES[w], Settings.RANGES[h]
end

-- The activity button and its popup (STACKED, DETAILS) -----------------------------------------

function Layouts.PopupShown(f)
    return f.popup ~= nil and f.popup:IsShown()
end

-- "Dungeons (2)": the category and how many activities are ticked.
function Layouts.ActivityLabel()
    local name = ns.Side.CategoryName(S("category"))
    local n = #ns.Window.CheckedList()
    if n > 0 then return L.ACTIVITY_BUTTON:format(name, n) end
    return name
end

local function updateButton(f)
    local b = f.activity
    b:SetLabel(Layouts.ActivityLabel())
    b:SetOn(Layouts.PopupShown(f))
    b:SetWidth(math.floor(b.label:GetStringWidth() + 32))
end

-- The activity list in the popup: above the window's other parts.
local function placeSideInPopup(f, height)
    local popup, side = f.popup, f.side
    local h = math.max(160, math.min(POPUP_H, height - 60))
    popup:SetSize(POPUP_W, h)
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", f.activity, "BOTTOMLEFT", 0, -4)
    ns.Window.ApplyLook(popup, POPUP_W, h)
    popup.header.title:SetText(L.ACTIVITIES)
    side:SetFrameStrata("DIALOG")
    side:SetFrameLevel(popup:GetFrameLevel() + 5)
    side:ClearAllPoints()
    side:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -POPUP_HEADER)
    side:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", 0, 0)
    ns.Side.SetSize(POPUP_W, h - POPUP_HEADER)
    side:SetShown(popup:IsShown())
end

function Layouts.OpenPopup(f)
    if Layouts.Current() == "SIDEBAR" then return end
    f.popup:Show()
    placeSideInPopup(f, f:GetHeight())
    ns.Side.Refresh()
    updateButton(f)
end

function Layouts.ClosePopup(f)
    if not f.popup then return end
    f.popup:Hide()
    if Layouts.Current() ~= "SIDEBAR" then f.side:Hide() end
    updateButton(f)
end

function Layouts.TogglePopup(f)
    if Layouts.PopupShown(f) then Layouts.ClosePopup(f) else Layouts.OpenPopup(f) end
end

-- The button and the popup frame (the activity list is placed into it).
function Layouts.Create(f)
    f.activity = Controls.Button(f, { text = "", height = BUTTON_H, icon = "ChevronDown",
        onClick = function() Layouts.TogglePopup(f) end, tip = function() return L.TIP_ACTIVITY_BUTTON end })
    local popup = CreateFrame("Frame", POPUP_NAME, f)
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetAllPoints()
    popup.clip = {}
    local h = CreateFrame("Frame", nil, popup)
    popup.header = h
    h:SetHeight(POPUP_HEADER)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    Controls.HeaderGlow(h)
    h.close = Controls.CloseButton(h, 16, function() Layouts.ClosePopup(f) end, function() return L.TIP_CLOSE end)
    h.close:SetPoint("RIGHT", h, "RIGHT", -4, 0)
    h.title = Controls.Text(h, "header")
    h.title:SetPoint("LEFT", h, "LEFT", 10, 0)
    h.title:SetPoint("RIGHT", h.close, "LEFT", -4, 0)
    popup:Hide()
    f.popup = popup
end

-- Arranging -------------------------------------------------------------------------------------

-- A part from the window's left edge (x) and top (y), w wide.
local function at(part, f, x, y, w, h)
    part:ClearAllPoints()
    part:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    if w then part:SetWidth(w) end
    if h then part:SetHeight(h) end
    part:Show()
end

local function hline(t, f, x, y, w)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    t:SetSize(w, 1)
    t:Show()
end

local function vline(t, f, x, top)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -top)
    t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
    t:Show()
end

local function placeColumn(f, width, height, top)
    local cw = Layouts.COLUMN_W
    local cx = width - cw
    vline(f.columnLine, f, cx - 1, top)
    local lw = cw - 2 * PAD
    local listingH = ns.ListingPanel.Layout(lw)
    at(f.listing, f, cx + PAD, height - PAD - listingH, lw, listingH)
    local ruleY = height - PAD - listingH - GAP
    hline(f.rule, f, cx, ruleY, cw)
    local upper = math.max(0, ruleY - top - PAD)
    at(f.detail, f, cx, top + PAD, cw, upper)
    f.detail:SetShown(ns.Detail.Row() ~= nil)
    ns.Detail.LayoutEmbedded(cw, upper)
    at(f.column, f, cx, top, cw, upper + PAD)
    ns.Column.Layout(cw, upper + PAD)
end

-- Places every part for the window's size; f.listWidth is the list's
-- inner width (rows are laid out for it).
function Layouts.Arrange(f, width, height, top)
    local mode = Layouts.Current()
    local x0, areaW = 0, width
    if mode == "SIDEBAR" then
        local sw = S("sideWidth")
        f.popup:Hide()
        f.side:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
        f.side:SetFrameLevel(f:GetFrameLevel() + 1)
        f.side:ClearAllPoints()
        f.side:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
        f.side:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        ns.Side.SetSize(sw, height - top)
        f.side:Show()
        vline(f.divider, f, sw, top)
        x0, areaW = sw + 1, width - sw - 1
    else
        f.divider:Hide()
        if mode == "DETAILS" then areaW = width - Layouts.COLUMN_W - 1 end
    end
    local inner = areaW - 2 * PAD
    local y = top + PAD
    if mode == "SIDEBAR" then
        f.activity:Hide()
    else
        at(f.activity, f, x0 + PAD, y)
        updateButton(f)
        placeSideInPopup(f, height)
        y = y + BUTTON_H + GAP
    end
    if mode == "DETAILS" then
        placeColumn(f, width, height, top)
    else
        f.columnLine:Hide()
        f.detail:Hide()
        f.column:Hide()
        local listingH = ns.ListingPanel.Layout(inner)
        at(f.listing, f, x0 + PAD, y, inner, listingH)
        y = y + listingH + GAP
        hline(f.rule, f, x0, y, areaW)
        y = y + GAP
    end
    at(f.filters, f, x0 + PAD, y, inner)
    ns.Window.LayoutFilters()
    y = y + ns.Window.FILTER_H + GAP
    f.list:ClearAllPoints()
    f.list:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + PAD, -y)
    f.list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(width - x0 - areaW + PAD), PAD)
    f.list.viewHeight = math.max(0, height - y - PAD)
    f.listWidth = inner
end
