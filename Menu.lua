local ADDON, ns = ...
local L, Controls = ns.L, ns.Controls

-- Context menus: Blizzard's MenuUtil when the client has it, else a small
-- menu of our own. Builders use MenuUtil's description API either way
-- (CreateTitle, CreateButton, CreateCheckbox, CreateRadio, CreateDivider;
-- a button's own CreateButton makes a submenu), so one builder serves both.
local Menu = {}
ns.Menu = Menu

-- Our own menu ------------------------------------------------------------------------

local ITEM_H, MENU_W, INDENT = 18, 200, 12

-- Records what a builder adds, in MenuUtil's shape.
local function newDescription()
    local d = { items = {} }
    local function add(kind, text, isSelected, onSelect, data)
        local item = newDescription()
        item.kind, item.text, item.isSelected, item.onSelect, item.data = kind, text, isSelected, onSelect, data
        d.items[#d.items + 1] = item
        return item
    end
    function d.CreateTitle(_, text) return add("title", text) end
    function d.CreateDivider() return add("divider") end
    function d.CreateButton(_, text, fn, data) return add("button", text, nil, fn, data) end
    function d.CreateCheckbox(_, text, isSel, setSel, data) return add("checkbox", text, isSel, setSel, data) end
    function d.CreateRadio(_, text, isSel, setSel, data) return add("radio", text, isSel, setSel, data) end
    function d.SetEnabled(self, on) self.disabled = not on end
    function d.SetTooltip() end
    function d.SetScrollMode() end
    return d
end
Menu.NewDescription = newDescription

-- Every item in order; submenus follow their parent, indented.
local function flatten(d, depth, out)
    for _, item in ipairs(d.items) do
        out[#out + 1] = { item = item, depth = depth }
        if #item.items > 0 then flatten(item, depth + 1, out) end
    end
    return out
end
Menu.Flatten = function(d) return flatten(d, 0, {}) end

local own   -- our menu frame, built on first use

local function closeOwn()
    if own then own:Hide() end
end
Menu.CloseOwn = closeOwn

local function ownLine(i)
    local line = own.lines[i]
    if line then return line end
    line = CreateFrame("Button", nil, own)
    line:SetHeight(ITEM_H)
    line:RegisterForClicks("LeftButtonUp")
    line.hover = line:CreateTexture(nil, "BACKGROUND")
    line.hover:SetAllPoints()
    line.hover:SetColorTexture(1, 1, 1, 0.08)
    line.hover:Hide()
    line.text = Controls.Text(line, "comment")
    line.text:SetPoint("LEFT", 6, 0)
    line.text:SetPoint("RIGHT", -6, 0)
    line.mark = line:CreateTexture(nil, "ARTWORK")
    line.mark:SetSize(10, 10)
    line.mark:SetTexture(ns.Media.Icon("Check"))
    line:SetScript("OnEnter", function(self) if self.clickable then self.hover:Show() end end)
    line:SetScript("OnLeave", function(self) self.hover:Hide() end)
    line:SetScript("OnClick", function(self)
        local item = self.item
        if not (self.clickable and item.onSelect) then return end
        closeOwn()
        item.onSelect(item.data)
    end)
    own.lines[i] = line
    return line
end

local function showOwn(owner, d)
    if not own then
        own = CreateFrame("Frame", "ForeverGroupFinderMenu", UIParent)
        own:SetFrameStrata("FULLSCREEN_DIALOG")
        own:SetClampedToScreen(true)
        own:EnableMouse(true)
        own.bg = own:CreateTexture(nil, "BACKGROUND")
        own.bg:SetAllPoints()
        own.bg:SetColorTexture(0.05, 0.05, 0.06, 0.97)
        own.edges = Controls.Outline(own, Controls.EDGE)
        own.lines = {}
        if UISpecialFrames then table.insert(UISpecialFrames, "ForeverGroupFinderMenu") end
    end
    local list = flatten(d, 0, {})
    for _, line in ipairs(own.lines) do line:Hide() end
    for i, entry in ipairs(list) do
        local item, line = entry.item, ownLine(i)
        line.item = item
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", own, "TOPLEFT", 1, -1 - (i - 1) * ITEM_H)
        line:SetWidth(MENU_W - 2)
        local x = 6 + entry.depth * INDENT
        local marked = (item.kind == "checkbox" or item.kind == "radio")
        line.text:ClearAllPoints()
        line.text:SetPoint("LEFT", line, "LEFT", x + (marked and 14 or 0), 0)
        line.text:SetPoint("RIGHT", line, "RIGHT", -6, 0)
        line.text:SetText(item.kind == "divider" and "" or (item.text or ""))
        Controls.Color(line.text, item.kind == "title" and Controls.GOLD or Controls.TEXT)
        line.mark:ClearAllPoints()
        line.mark:SetPoint("LEFT", line, "LEFT", x, 0)
        line.mark:SetShown(marked and item.isSelected and item.isSelected(item.data) and true or false)
        line.clickable = item.onSelect ~= nil and not item.disabled
        line:SetAlpha(item.disabled and Controls.DISABLED_ALPHA or 1)
        line:Show()
    end
    own:SetSize(MENU_W, #list * ITEM_H + 2)
    own:ClearAllPoints()
    own:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    own:Show()
    return own
end

-- Opens a menu at owner; build(root) adds the entries.
function Menu.Open(owner, build)
    if MenuUtil and MenuUtil.CreateContextMenu then
        return MenuUtil.CreateContextMenu(owner, function(_, root) build(root) end)
    end
    local d = newDescription()
    build(d)
    return showOwn(owner, d)
end

-- The row menu ------------------------------------------------------------------------

-- The whisper templates, expanded for the row's first activity; each one
-- whispers the leader and marks the row seen.
function Menu.AddWhisperTemplates(parent, row)
    local leader = row.leader
    local firstActivity = type(row.activityIDs) == "table" and row.activityIDs[1] or nil   -- plain: Finder converted the row
    for _, text in ipairs(ns.Settings.Get("whisperTemplates")) do
        local expanded = ns.Listing.Expand(text, firstActivity)
        local item = parent:CreateButton(expanded, function()
            ns.Finder.Whisper(leader, expanded)
            ns.Memory.MarkSeen(row.key)
            ns.Window.RefreshRows()
        end)
        if type(leader) ~= "string" and item.SetEnabled then item:SetEnabled(false) end
    end
end

-- row: a row from Results.Build. Every entry acts on its leader / key.
function Menu.BuildRowMenu(root, row)
    local Finder, Memory, Listing = ns.Finder, ns.Memory, ns.Listing
    local leader = row.leader
    local hasName = type(leader) == "string" and leader ~= ""
    root:CreateTitle(hasName and leader or L.UNKNOWN_PLAYER)
    local whisper = root:CreateButton(L.MENU_WHISPER, function()
        Finder.Whisper(leader)
        Memory.MarkSeen(row.key)
        ns.Window.RefreshRows()
    end)
    local templates = root:CreateButton(L.MENU_WHISPER_TEMPLATE)
    Menu.AddWhisperTemplates(templates, row)
    -- Invite only for a solo player: a group is joined by whispering its leader.
    local invite = row.kind ~= "GROUP" and root:CreateButton(L.MENU_INVITE, function() Finder.Invite(leader) end) or nil
    root:CreateDivider()
    root:CreateButton(L.MENU_MARK_SEEN, function()
        Memory.MarkSeen(row.key)
        ns.Window.RefreshRows()
    end)
    -- Both offer "Undo" for a few seconds (Undo.lua).
    root:CreateButton(L.MENU_HIDE, function() ns.Undo.Hide(row) end)
    local ignore = root:CreateButton(L.MENU_IGNORE, function() ns.Undo.Ignore(leader) end)
    if not hasName then
        for _, item in pairs({ whisper, templates, invite, ignore }) do
            if item.SetEnabled then item:SetEnabled(false) end
        end
    end
end

function Menu.OpenRowMenu(owner, row)
    return Menu.Open(owner, function(root) Menu.BuildRowMenu(root, row) end)
end
