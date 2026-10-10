local ADDON, ns = ...
local L, Settings, Controls, Activities = ns.L, ns.Settings, ns.Controls, ns.Activities
local S = Settings.Get

-- The activity list: the categories as radio buttons, search box, the activity list with
-- check boxes coloured by level fit, and at the bottom the switch "Only in
-- my level range". One panel for every layout: the window's left column
-- (SIDEBAR) or the content of the activity dropdown (STACKED, DETAILS;
-- Layouts.lua places it). The checked activities are the window's
-- (ns.Window.Checked); this file only shows and toggles them. Every click
-- here is a user action and may search (ns.Window.Search); typing in the
-- search box only filters the list.
local Side = {}
ns.Side = Side

local PAD = 6
local ITEM_H = 18
local CHECK = 11
local FIT_COLOR = { FITS = nil, LOW = Controls.GREY, HIGH = Controls.RED }
local RADIO_H, RADIO_GAP = 16, 8

local panel
local items = {}
local filterText = ""
local width              -- set by the layout; the side width until then
local radioH = RADIO_H     -- the radios' height (one or more lines)
local height = 0           -- the panel's height from the layout

-- The activities shown: the category's, filtered by text and (with the
-- switch on) by level, but my active listing's and the checked ones stay,
-- even out of range (Blizzard keeps them too).
function Side.Visible()
    local category = S("category")
    local all = Activities.List(category, { text = filterText })
    if not S("levelRangeOnly") then return all end
    local keep = {}
    local entry = ns.Finder.ActiveEntry()
    for _, id in ipairs(entry and entry.activityIDs or {}) do keep[id] = true end   -- plain: Finder converted the entry
    for id in pairs(ns.Window.Checked()) do keep[id] = true end
    local out = {}
    for _, a in ipairs(all) do
        if a.fit == "FITS" or keep[a.id] then out[#out + 1] = a end
    end
    return out
end

function Side.CategoryName(id)
    for _, c in ipairs(Activities.Categories()) do
        if c.id == id then return c.name end
    end
    return L["CATEGORY_" .. id]
end

local function newItem(parent)
    local item = CreateFrame("Button", nil, parent)
    item:SetHeight(ITEM_H)
    item:RegisterForClicks("LeftButtonUp")
    item.hover = item:CreateTexture(nil, "BACKGROUND")
    item.hover:SetAllPoints()
    item.hover:SetColorTexture(1, 1, 1, 0.05)
    item.hover:Hide()
    item.on = item:CreateTexture(nil, "BACKGROUND", nil, 1)
    item.on:SetAllPoints()
    item.on:SetColorTexture(0.16, 0.13, 0.06, 1)
    item.box = Controls.CheckMark(item, CHECK)
    item.box:SetPoint("LEFT", 2, 0)
    item.range = Controls.Text(item, "small")
    item.range:SetJustifyH("RIGHT")
    item.range:SetPoint("RIGHT", -2, 0)
    item.name = Controls.Text(item, "comment")
    item.name:SetPoint("LEFT", item.box, "RIGHT", 4, 0)
    item:SetScript("OnEnter", function(self)
        self.hover:Show()
        local a = self.activity
        if a then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(a.name, Controls.GOLD[1], Controls.GOLD[2], Controls.GOLD[3])
            GameTooltip:AddLine(L.TIP_LEVELS:format(a.minLevel, a.maxLevel), 1, 1, 1)
            if a.fit ~= "FITS" then GameTooltip:AddLine(L["FIT_" .. a.fit], 1, 0.4, 0.3) end
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    item:SetScript("OnClick", function(self)
        if self.activity then Side.Toggle(self.activity.id) end
    end)
    return item
end

local function rangeText(a)
    if a.minLevel > 0 and a.maxLevel > 0 then return L.LEVEL_RANGE:format(a.minLevel, a.maxLevel) end
    if a.minLevel > 0 then return L.LEVEL_FROM:format(a.minLevel) end
    return ""
end

-- Lays the list out again (no search).
function Side.Refresh()
    if not panel then return end
    Side.LayoutCategories((width or S("sideWidth")) - 2 * PAD)
    panel.levelBox:SetChecked(S("levelRangeOnly"))
    panel.levelText:SetText(L.LEVEL_RANGE_ONLY)
    panel.search.hint:SetText(L.SEARCH_ACTIVITIES)
    panel.empty:SetText(L.NO_ACTIVITIES)
    local list = Side.Visible()
    local checked = ns.Window.Checked()
    local inner = (width or S("sideWidth")) - 2 * PAD
    local child = panel.scroll.child
    child:SetWidth(inner)
    for i, a in ipairs(list) do
        local item = items[i] or newItem(child)
        items[i] = item
        item.activity = a
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ITEM_H)
        item:SetWidth(inner - 4)
        Controls.Restyle(item.name, FIT_COLOR[a.fit])
        Controls.Restyle(item.range)
        item.range:SetText(rangeText(a))
        item.name:SetWidth(math.max(20, inner - 4 - CHECK - 8 - item.range:GetStringWidth() - 4))
        item.name:SetText(a.name)
        local on = checked[a.id] == true
        item.box:SetChecked(on)
        item.on:SetShown(on)
        item:Show()
    end
    for i = #list + 1, #items do
        items[i]:Hide()
        items[i].activity = nil
    end
    panel.empty:SetShown(#list == 0)
    panel.scroll:SetContentHeight(#list * ITEM_H)
end

-- Click paths --------------------------------------------------------------------------

function Side.Toggle(id)
    ns.Window.SetChecked(id, not ns.Window.Checked()[id])
    Side.Refresh()
    ns.Window.ListingChanged()
    ns.Window.Search()
end

function Side.SetCategory(id)
    if id == S("category") then return end
    Settings.Set("category", id)
    ns.Window.ResetChecked()
    Side.Refresh()
    ns.Window.ListingChanged()
    ns.Window.Search()
end

function Side.ToggleLevelRange()
    Settings.Set("levelRangeOnly", not S("levelRangeOnly"))
    Side.Refresh()
    ns.Window.Search()
end

function Side.SetFilterText(text)
    filterText = type(text) == "string" and text or ""
    Side.Refresh()
end

function Side.Items() return items end
function Side.Panel() return panel end

-- The categories: radio buttons side by side, wrapping to more lines.
local function radio(i)
    local r = panel.cats[i]
    if r then return r end
    r = CreateFrame("Button", nil, panel)
    r:SetHeight(RADIO_H)
    r:RegisterForClicks("LeftButtonUp")
    r.box = Controls.CheckMark(r, CHECK)
    r.box:SetPoint("LEFT", 0, 0)
    r.label = Controls.Text(r, "small")
    r.label:SetPoint("LEFT", r.box, "RIGHT", 4, 0)
    r:SetScript("OnClick", function(self) if self.categoryID then Side.SetCategory(self.categoryID) end end)
    r:SetScript("OnEnter", function(self) Controls.Tooltip(self, L.TIP_CATEGORY) end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.cats[i] = r
    return r
end

-- The width all category radios need side by side (and the panel's
-- margins), measured in the current language and font.
function Side.CategoriesWidth()
    if not panel then return 0 end
    local total = 0
    for i, c in ipairs(Activities.Categories()) do
        local r = radio(i)
        Controls.Restyle(r.label)
        r.label:SetText(c.name)
        total = total + CHECK + 4 + r.label:GetStringWidth() + (i > 1 and RADIO_GAP or 0)
    end
    return math.ceil(total + 2 * PAD + 2)
end

-- Lays the radios out in w; returns their height.
function Side.LayoutCategories(w)
    if not panel then return 0 end
    local x, line = 0, 0
    local cats = Activities.Categories()
    for i, c in ipairs(cats) do
        local r = radio(i)
        r.categoryID = c.id
        local on = S("category") == c.id
        r.box:SetChecked(on)
        Controls.Restyle(r.label, on and Controls.GOLD or Controls.TEXT)
        r.label:SetText(c.name)
        local rw = math.floor(CHECK + 4 + r.label:GetStringWidth() + 0.5)
        if x > 0 and x + rw > w then x, line = 0, line + 1 end
        r:SetWidth(math.min(rw, w))
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + x, -PAD - line * (RADIO_H + 2))
        r:Show()
        x = x + rw + RADIO_GAP
    end
    for i = #cats + 1, #panel.cats do panel.cats[i]:Hide() end
    radioH = (#cats > 0 and (line + 1) * (RADIO_H + 2) - 2) or 0
    panel.search:ClearAllPoints()
    panel.search:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD - radioH - 4)
    panel.search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PAD - radioH - 4)
    panel.scroll.viewHeight = math.max(0, height - 2 * PAD - radioH - 4 - 18 - 4 - ITEM_H - 2 - 4 - PAD)
    return radioH
end

-- Building -----------------------------------------------------------------------------

function Side.Create(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel.cats = {}
    panel.search = Controls.EditBox(panel, L.SEARCH_ACTIVITIES, 40)
    panel.search:SetPoint("TOPLEFT", PAD, -PAD - RADIO_H - 4)
    panel.search:SetPoint("TOPRIGHT", -PAD, -PAD - RADIO_H - 4)
    panel.search:HookScript("OnTextChanged", function(self) Side.SetFilterText(self:GetText()) end)
    panel.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- The switch at the bottom.
    panel.level = CreateFrame("Button", nil, panel)
    panel.level:SetHeight(ITEM_H + 2)
    panel.level:SetPoint("BOTTOMLEFT", PAD, PAD)
    panel.level:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    panel.level:RegisterForClicks("LeftButtonUp")
    panel.levelBox = Controls.CheckMark(panel.level, CHECK)
    panel.levelBox:SetPoint("LEFT", 2, 0)
    panel.levelText = Controls.Text(panel.level, "small")
    panel.levelText:SetPoint("LEFT", panel.levelBox, "RIGHT", 4, 0)
    panel.levelText:SetPoint("RIGHT", 0, 0)
    Controls.Restyle(panel.levelText, Controls.GOLD)
    panel.levelText:SetText(L.LEVEL_RANGE_ONLY)
    panel.level:SetScript("OnClick", function() Side.ToggleLevelRange() end)
    panel.level:SetScript("OnEnter", function(self) Controls.Tooltip(self, L.TIP_LEVEL_RANGE_ONLY) end)
    panel.level:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.levelLine = panel:CreateTexture(nil, "ARTWORK")
    panel.levelLine:SetHeight(1)
    panel.levelLine:SetPoint("BOTTOMLEFT", panel.level, "TOPLEFT", 0, 2)
    panel.levelLine:SetPoint("BOTTOMRIGHT", panel.level, "TOPRIGHT", 0, 2)
    panel.levelLine:SetColorTexture(0.78, 0.59, 0.13, 0.3)

    panel.scroll = Controls.Scroll(panel)
    panel.scroll:SetPoint("TOPLEFT", panel.search, "BOTTOMLEFT", 0, -4)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel.level, "TOPRIGHT", 0, 4)
    panel.empty = Controls.Text(panel.scroll, "small")
    panel.empty:SetPoint("TOPLEFT", 2, -2)
    panel.empty:SetText(L.NO_ACTIVITIES)
    return panel
end

-- The panel's size from the layout; the list's visible height for the
-- scroll thumb (the mock and the first layout know no anchored sizes).
function Side.SetSize(w, h)
    width = w
    if not panel then return end
    height = h
    panel:SetSize(w, h)
    Side.LayoutCategories(w - 2 * PAD)
end
