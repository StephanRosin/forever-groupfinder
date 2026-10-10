local ADDON, ns = ...
local L, Settings, Controls, Activities, Listing = ns.L, ns.Settings, ns.Controls, ns.Activities, ns.Listing
local S = Settings.Get

-- "My listing" (Layouts.lua places it: above the list, or at the foot of
-- the details column): the checked activities
-- as chips, my roles (ns.Roles: only those my class can play) with the
-- "only groups with room for me" toggle, the current comment (read-only; "Comment..."
-- opens Blizzard's listing tab for players with an authenticator), the
-- template menu, remaining time, one Post / Update / Remove button, the expiry warning
-- with "Extend", the leader line ("Missing: ...") and the copy box for a
-- template comment the client would not let us prefill.
--
-- Posting needs a click: Post, Extend, Remove and the template entries run
-- from OnClick handlers / menu clicks only.
local Panel = {}
ns.ListingPanel = Panel

local ROW_H, GAP = 18, 4
local STATUS_H = 14       -- the status line under the title in a narrow panel
local MIN_COMMENT_W = 60  -- less room than this: the comment wraps to its own line
local BUTTON_GAP = 4
local ROLE_KEYS = { "tank", "healer", "dps" }
local ROLE_LABEL = { tank = "ROLE_TANK", healer = "ROLE_HEALER", dps = "ROLE_DAMAGER" }

local p
local templateComment = "" -- the applied template's comment, ready to copy
local warning = false      -- the expiry warning is showing
local copyText = nil       -- the copy box is showing this

-- State -------------------------------------------------------------------------------------

-- My selected roles (ns.Roles), the same everywhere.
function Panel.Roles() return ns.Roles.Selected() end

function Panel.TemplateComment() return templateComment end
function Panel.Warning() return warning end
function Panel.CopyText() return copyText end
function Panel.Frame() return p end

local function solo()
    return not (IsInGroup and IsInGroup())
end

-- { TANK = n, HEALER = n, DAMAGER = n } still missing while I lead a
-- group (for the first ticked activity, else my listing's); nil otherwise.
function Panel.LeaderMissing()
    if not (UnitIsGroupLeader and UnitIsGroupLeader("player")) then return nil end
    local ids = ns.Window.CheckedList()
    local id = ids[1]
    if not id then   -- plain: an id from our own list
        local entry = ns.Finder.ActiveEntry()
        id = entry and entry.activityIDs[1]   -- plain: Finder converted the entry
    end
    if not id then return nil end   -- plain: an id from our own list
    return Listing.Missing(id)
end

-- "Missing: 1 Healer, 2 Damage" while I lead a group; nil otherwise.
function Panel.LeaderText()
    local missing = Panel.LeaderMissing()
    if not missing then return nil end
    local parts = {}
    for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        local n = missing[role]
        if n and n > 0 then parts[#parts + 1] = L.MISSING_ROLE:format(n, L["ROLE_" .. role]) end
    end
    if #parts == 0 then return L.LEADER_COMPLETE end
    return L.LEADER_MISSING:format(table.concat(parts, ", "))
end

-- Click paths --------------------------------------------------------------------------------

function Panel.ToggleRole(key)
    ns.Roles.Toggle(key)
    ns.Window.Rebuild()          -- room for me depends on my roles
    ns.Window.ListingChanged()
end

local function sameActivities(a, b)
    local set = {}
    for _, id in ipairs(a) do set[id] = true end
    local n = 0
    for _, id in ipairs(b) do
        if not set[id] then return false end
        n = n + 1
    end
    return n == #a
end

-- My ticked activities or roles differ from the active listing.
function Panel.Changed()
    local state = Listing.State()
    if not state.active then return false end
    local ids = ns.Window.CheckedList()
    if #ids > 0 and not sameActivities(ids, state.activityIDs) then return true end
    if solo() and type(Listing.roles) == "table" and not ns.Roles.Same(Panel.Roles(), Listing.roles) then return true end
    return false
end

-- The one listing button: Post without a listing, Update when something
-- changed, Remove when nothing did. A right click always removes.
function Panel.Action(mouse)
    local state = Listing.State()
    if not state.active then return Panel.Post() end
    if mouse == "RightButton" or not Panel.Changed() then
        Panel.Remove()
        return true
    end
    return Panel.Post()
end

function Panel.Post()
    local ids = ns.Window.CheckedList()
    local ok = Listing.Post(ids, solo() and Panel.Roles() or nil)
    if ok then warning = false end
    ns.Window.ListingChanged()
    return ok
end

function Panel.Extend()
    local state = Listing.State()
    if not state.active then return false end
    local ok = Listing.Post(state.activityIDs, Listing.roles)
    if ok then warning = false end
    ns.Window.ListingChanged()
    return ok
end

function Panel.Remove()
    Listing.Remove()
    warning = false
    ns.Window.ListingChanged()
end

function Panel.OpenComment()
    local result, text = Listing.OpenCommentEditor(templateComment)
    if result == "COPY" then
        copyText = text
    end
    ns.Window.ListingChanged()
    if result == "COPY" and p then
        p.copy:SetText(copyText)
        p.copy:SetFocus()
        p.copy:HighlightText()
    end
    return result
end

function Panel.CloseCopy()
    copyText = nil
    if p then p.copy:ClearFocus() end
    ns.Window.ListingChanged()
end

function Panel.ApplyTemplate(name)
    local t = Listing.ApplyTemplate(name)
    if not t then return false end
    ns.Window.SetCheckedList(t.activityIDs)
    ns.Roles.Set(t.roles)
    templateComment = type(t.comment) == "string" and t.comment or ""   -- plain: our own saved template
    ns.Side.Refresh()
    ns.Window.ListingChanged()
    ns.Window.Search()
    return true
end

function Panel.SaveTemplate(name)
    return Listing.SaveTemplate(name, ns.Window.CheckedList(), Panel.Roles(), templateComment)
end

function Panel.DeleteTemplate(name)
    return Listing.DeleteTemplate(name)
end

if StaticPopupDialogs then
    StaticPopupDialogs["FOREVERGROUPFINDER_TEMPLATE_NAME"] = {
        text = "",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = 1,
        maxLetters = 40,
        OnAccept = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            Panel.SaveTemplate(box and box:GetText())
        end,
        EditBoxOnEnterPressed = function(editBox)
            Panel.SaveTemplate(editBox:GetText())
            editBox:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true,
    }
end

function Panel.AskTemplateName()
    if not StaticPopup_Show then return end
    StaticPopupDialogs["FOREVERGROUPFINDER_TEMPLATE_NAME"].text = L.POPUP_TEMPLATE_NAME
    StaticPopup_Show("FOREVERGROUPFINDER_TEMPLATE_NAME")
end

function Panel.BuildTemplateMenu(root)
    local list = Listing.Templates()
    root:CreateTitle(L.TEMPLATES)
    if #list == 0 then root:CreateTitle(L.NO_TEMPLATES) end
    for _, t in ipairs(list) do
        root:CreateButton(t.name, function(name) Panel.ApplyTemplate(name) end, t.name)
    end
    root:CreateDivider()
    root:CreateButton(L.SAVE_TEMPLATE, function() Panel.AskTemplateName() end)
    if #list > 0 then
        local delete = root:CreateButton(L.DELETE_TEMPLATE)
        for _, t in ipairs(list) do
            delete:CreateButton(t.name, function(name) Panel.DeleteTemplate(name) end, t.name)
        end
    end
end

-- Display --------------------------------------------------------------------------------------

local function statusText(state)
    if not state.active then return L.LISTING_NONE end
    local left = Controls.Age(state.remaining)
    if left then return L.LISTING_ACTIVE:format(left) end
    return L.LISTING_ACTIVE_NO_TIME
end

function Panel.UpdateClock()
    if not p then return end
    p.status:SetText(statusText(Listing.State()))
end

local function chip(i)
    local c = p.chips[i]
    if c then return c end
    c = Controls.Chip(p, { text = "", tip = function() return L.TIP_ACTIVITY_CHIP end,
        onClick = function(self) if self.activityID then ns.Side.Toggle(self.activityID) end end })   -- plain: our chip's id
    c:SetOn(true)
    p.chips[i] = c
    return c
end

-- Fills the texts and buttons (no layout).
function Panel.Refresh()
    if not p then return end
    local state = Listing.State()
    if not state.active then warning = false end
    p.title:SetText(L.MY_LISTING)
    p.status:SetText(statusText(state))
    local ids = ns.Window.CheckedList()
    local mode = not state.active and "POST" or (Panel.Changed() and "UPDATE" or "REMOVE")
    p.post.mode = mode
    p.post:SetLabel(L[mode])
    p.post:SetOff(mode == "POST" and #ids == 0, L.TIP_POST_NEEDS_ACTIVITY)
    p.post.tip = L["TIP_" .. mode]
    p.roomOnly:SetLabel(L.FILTER_ROOM_FOR_ME)
    p.roomOnly:SetOn(S("filterMyRole"))
    p.template:SetLabel(L.TEMPLATE)
    p.comment:SetLabel(L.COMMENT_BUTTON)
    p.comment:SetOff(not Listing.CanComment(), L.TIP_COMMENT_NEEDS_AUTH)
    p.extend:SetLabel(L.EXTEND)
    local comment = state.comment
    if type(comment) == "string" and comment ~= "" then
        Controls.Restyle(p.commentText)
        p.commentText:SetText(comment)
    else
        Controls.Restyle(p.commentText, Controls.DIM)
        p.commentText:SetText(templateComment ~= "" and L.TEMPLATE_COMMENT:format(templateComment) or L.NO_COMMENT)
    end
    local r = Panel.Roles()
    for _, k in ipairs(ROLE_KEYS) do
        p.roles[k]:SetLabel(L[ROLE_LABEL[k]])
        p.roles[k]:SetOn(r[k])
    end
    p.hint:SetText(L.HINT_TICK_ACTIVITIES)
    p.warningText:SetText(L.EXPIRY_WARNING)
    p.leader:SetText(Panel.LeaderText() or "")
    p.copyHint:SetText(L.COPY_HINT)
end

-- Places everything for width; returns the panel's height.
function Panel.Layout(width)
    if not p then return 0 end
    Panel.Refresh()
    local y = 0
    -- Line 1: title, status; Remove, Post, Template at the right.
    p.title:ClearAllPoints()
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - 3)
    local x = width
    for _, b in ipairs({ p.post, p.template }) do
        b:SetWidth(math.max(56, math.floor(b.label:GetStringWidth() + (b.icon and 30 or 18))))
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", p, "TOPLEFT", x, -y)
        x = x - b:GetWidth() - BUTTON_GAP
    end
    -- A narrow panel (the details column) puts the status under the title.
    local statusBelow = p.title:GetStringWidth() + 8 + p.status:GetStringWidth() + 8 > x
    p.status:ClearAllPoints()
    if statusBelow then
        p.status:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -2)
        y = y + STATUS_H
    else
        p.status:SetPoint("LEFT", p.title, "RIGHT", 8, 0)
    end
    y = y + ROW_H + GAP
    -- Line 2: the checked activities.
    local ids = ns.Window.CheckedList()
    local cx = 0
    for i, id in ipairs(ids) do
        local c = chip(i)
        c.activityID = id
        c:SetLabel(Activities.Name(id) or L.UNKNOWN_ACTIVITY)
        local w = c:Fit()
        if cx + w > width and i > 1 then
            c:Hide()
        else
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", p, "TOPLEFT", cx, -y)
            c:Show()
            cx = cx + w + BUTTON_GAP
        end
    end
    for i = #ids + 1, #p.chips do p.chips[i]:Hide() end
    p.hint:ClearAllPoints()
    p.hint:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - 2)
    p.hint:SetShown(#ids == 0)
    y = y + 16 + GAP
    -- Line 3: my roles (only those my class can play), "only groups with
    -- room for me", the comment, "Comment...".
    local rx = 0
    local allowed = ns.Roles.Allowed()
    for _, k in ipairs(ROLE_KEYS) do
        local b = p.roles[k]
        b:SetShown(allowed[k])
        if allowed[k] then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", p, "TOPLEFT", rx, -y)
            rx = rx + b:Fit() + BUTTON_GAP
        end
    end
    p.roomOnly:ClearAllPoints()
    p.roomOnly:SetPoint("TOPLEFT", p, "TOPLEFT", rx + 2, -y)
    rx = rx + 2 + p.roomOnly:Fit() + BUTTON_GAP
    p.comment:SetWidth(math.max(70, math.floor(p.comment.label:GetStringWidth() + 18)))
    -- Too little room left for the comment: it goes to a line of its own.
    if width - rx - 4 - p.comment:GetWidth() - 8 < MIN_COMMENT_W then
        y = y + ROW_H + GAP
        rx = -4
    end
    p.comment:ClearAllPoints()
    p.comment:SetPoint("TOPRIGHT", p, "TOPLEFT", width, -y)
    p.commentText:ClearAllPoints()
    p.commentText:SetPoint("TOPLEFT", p, "TOPLEFT", rx + 4, -y - 3)
    p.commentText:SetWidth(math.max(20, width - rx - 4 - p.comment:GetWidth() - 8))
    y = y + ROW_H + GAP
    -- Expiry warning with "Extend".
    p.warningText:SetShown(warning)
    p.extend:SetShown(warning)
    if warning then
        p.warningText:ClearAllPoints()
        p.warningText:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - 3)
        p.extend:SetWidth(math.max(56, math.floor(p.extend.label:GetStringWidth() + 18)))
        p.extend:ClearAllPoints()
        p.extend:SetPoint("LEFT", p.warningText, "RIGHT", 8, 0)
        y = y + ROW_H + GAP
    end
    -- Leader line.
    local leader = Panel.LeaderText()
    p.leader:SetShown(leader ~= nil)
    if leader then
        p.leader:ClearAllPoints()
        p.leader:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - 2)
        y = y + 16 + GAP
    end
    -- The copy box.
    local copying = copyText ~= nil
    p.copy:SetShown(copying)
    p.copyHint:SetShown(copying)
    p.copyClose:SetShown(copying)
    if copying then
        p.copy:ClearAllPoints()
        p.copy:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
        p.copy:SetWidth(math.max(60, width - 220))
        p.copyHint:ClearAllPoints()
        p.copyHint:SetPoint("LEFT", p.copy, "RIGHT", 6, 0)
        p.copyClose:ClearAllPoints()
        p.copyClose:SetPoint("TOPRIGHT", p, "TOPLEFT", width, -y)
        y = y + ROW_H + 2 + GAP
    end
    return y - GAP
end

-- Building -------------------------------------------------------------------------------------

function Panel.Create(parent)
    p = CreateFrame("Frame", nil, parent)
    p.title = Controls.Text(p, "small")
    Controls.Restyle(p.title, Controls.GOLD)
    p.status = Controls.Text(p, "small")
    p.post = Controls.Button(p, { text = "", height = 18, onClick = function(_, mouse) Panel.Action(mouse) end })
    p.template = Controls.Button(p, { text = "", height = 18, icon = "ChevronDown", tip = function() return L.TIP_TEMPLATE end,
        onClick = function(self) ns.Menu.Open(self, Panel.BuildTemplateMenu) end })
    p.chips = {}
    p.hint = Controls.Text(p, "small")
    p.roles = {}
    for _, k in ipairs(ROLE_KEYS) do
        p.roles[k] = Controls.Chip(p, { text = "", onClick = function() Panel.ToggleRole(k) end, tip = function() return L.TIP_ROLES end })
    end
    p.roomOnly = Controls.Chip(p, { text = "", onClick = function() ns.Window.ToggleFilter("filterMyRole") end,
        tip = function() return L.TIP_FILTER_ROOM_FOR_ME end })
    p.commentText = Controls.Text(p, "comment")
    p.comment = Controls.Button(p, { text = "", height = 18, onClick = function() Panel.OpenComment() end,
        tip = function() return L.TIP_COMMENT end })
    p.warningText = Controls.Text(p, "comment")
    Controls.Restyle(p.warningText, Controls.RED)
    p.extend = Controls.Button(p, { text = "", height = 18, onClick = function() Panel.Extend() end, tip = function() return L.TIP_EXTEND end })
    p.leader = Controls.Text(p, "comment")
    Controls.Restyle(p.leader, Controls.GOLD)
    -- Our own copy box: the template comment, highlighted for Ctrl+C.
    p.copy = Controls.EditBox(p, "", 255)
    p.copy:SetHeight(ROW_H + 2)
    Controls.PaintOutline(p.copy.edges, Controls.GOLD)
    p.copy.bg:SetColorTexture(0.2, 0.16, 0.05, 0.95)
    p.copy:SetScript("OnEscapePressed", function() Panel.CloseCopy() end)
    p.copy:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    p.copy:SetScript("OnEditFocusLost", function() end)
    -- The text is not ours to edit: typing puts it back.
    p.copy:SetScript("OnTextChanged", function(self, user)
        if user and copyText then
            self:SetText(copyText)
            self:HighlightText()
        end
    end)
    p.copyHint = Controls.Text(p, "small")
    p.copyClose = Controls.Button(p, { text = L.CLOSE, width = 50, height = 18, onClick = function() Panel.CloseCopy() end })
    Panel.Refresh()
    return p
end

-- The expiry warning, once per listing (Listing.lua decides when).
Listing.OnExpiryWarning(function(remaining)
    warning = true
    ns.Print(L.MSG_EXPIRING, Controls.Age(remaining) or "")
    if ns.Window.IsShown() then ns.Window.ListingChanged() end
end)
