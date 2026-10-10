local ADDON, ns = ...
local L, Settings, Controls, Activities, Listing = ns.L, ns.Settings, ns.Controls, ns.Activities, ns.Listing
local S = Settings.Get

-- "My listing" (Layouts.lua places it above the filters), three lines:
--   1. the title, a status pill (Not listed / Listed · 27 min / Changed –
--      click Update), Template and the one gold Post / Update / Remove button;
--   2. "My roles": a large role icon per role my class can play (ns.Roles),
--      and the "Only groups with room for me" check box;
--   3. "For:" with the ticked activities as read-only chips (abbreviated),
--      the comment (read-only; "Comment..." opens Blizzard's listing tab for
--      players with an authenticator).
-- Below: the expiry warning with "Extend", the leader line ("Missing: ...")
-- and the copy box for a template comment the client would not let us
-- prefill.
--
-- Posting needs a click: Post, Extend, Remove and the template entries run
-- from OnClick handlers / menu clicks only.
local Panel = {}
ns.ListingPanel = Panel

local ROW_H, GAP = 18, 4
local PILL_H, PILL_PAD = 16, 6   -- the status pill
local ROLE_SIZE = 28              -- a role icon toggle
local CHECK = 11
local ROLE_ATLAS = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }
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

local PILL = {   -- the status pill: text colour, fill
    NONE = { Controls.DIM, { 0.35, 0.35, 0.35, 0.25 } },
    LISTED = { Controls.GREEN, { 0.25, 0.75, 0.37, 0.18 } },
    CHANGED = { Controls.GOLD, { 1, 0.83, 0.35, 0.18 } },
}

-- "Not listed" / "Listed · 27 min" / "Changed – click Update", and its look.
local function pillState(state, mode)
    if not state.active then return "NONE", L.LISTING_NONE end
    if mode == "UPDATE" then return "CHANGED", L.LISTING_CHANGED end
    local left = Controls.Age(state.remaining)
    if left then return "LISTED", L.LISTING_ACTIVE:format(left) end
    return "LISTED", L.LISTING_ACTIVE_NO_TIME
end

local function paintPill(kind, text)
    local look = PILL[kind]
    p.status:SetText(text)
    Controls.Color(p.status, look[1])
    p.pill.bg:SetColorTexture(look[2][1], look[2][2], look[2][3], look[2][4])
    Controls.PaintOutline(p.pill.edges, { look[1][1], look[1][2], look[1][3], 0.6 })
    p.pill:SetSize(math.floor(p.status:GetStringWidth() + PILL_PAD * 2 + 0.5), PILL_H)
    p.pill.kind = kind
end

function Panel.UpdateClock()
    if not p then return end
    paintPill(pillState(Listing.State(), p.post.mode))
end

local function chip(i)
    local c = p.chips[i]
    if c then return c end
    -- Display only: the activities are chosen in the activity list; the
    -- tooltip names the full activity.
    c = Controls.Chip(p, { text = "", tip = function(self)
        local name = self.activityID and Activities.Name(self.activityID) or L.UNKNOWN_ACTIVITY   -- plain: our chip's id
        return name .. "\n" .. L.TIP_ACTIVITY_CHIP
    end })
    c:SetOn(true)
    p.chips[i] = c
    return c
end

local function paintRole(b)
    b.icon:SetDesaturated(not b.on)
    b.icon:SetAlpha(b.on and 1 or 0.4)
    Controls.PaintOutline(b.ring, b.on and Controls.GOLD or { 0, 0, 0, 0 })
end

-- Fills the texts and buttons (no layout).
function Panel.Refresh()
    if not p then return end
    local state = Listing.State()
    if not state.active then warning = false end
    p.title:SetText(L.MY_LISTING)
    local ids = ns.Window.CheckedList()
    local mode = not state.active and "POST" or (Panel.Changed() and "UPDATE" or "REMOVE")
    p.post.mode = mode
    p.post:SetLabel(L[mode])
    p.post:SetOff(mode == "POST" and #ids == 0, L.TIP_POST_NEEDS_ACTIVITY)
    p.post.tip = L["TIP_" .. mode]
    paintPill(pillState(state, mode))
    p.rolesLabel:SetText(L.MY_ROLES)
    p.forLabel:SetText(L.LISTING_FOR)
    p.roomOnly.text:SetText(L.FILTER_ROOM_FOR_ME)
    p.roomOnly.on = S("filterMyRole")
    p.roomOnly.box:SetChecked(p.roomOnly.on)
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
        p.roles[k].on = r[k] == true
        paintRole(p.roles[k])
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
    -- Line 1: title and status pill; Template and the main button at the right.
    local x = width
    for _, b in ipairs({ p.post, p.template }) do
        b:SetWidth(math.max(64, math.floor(b.label:GetStringWidth() + (b.icon and 30 or 22))))
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", p, "TOPLEFT", x, -y)
        x = x - b:GetWidth() - BUTTON_GAP
    end
    p.title:ClearAllPoints()
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - 3)
    local pillBelow = p.title:GetStringWidth() + 8 + p.pill:GetWidth() + 8 > x
    p.pill:ClearAllPoints()
    if pillBelow then
        -- A narrow panel puts the pill under the title.
        p.pill:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - ROW_H - 2)
        y = y + PILL_H + 2
    else
        p.pill:SetPoint("LEFT", p.title, "RIGHT", 8, 0)
    end
    y = y + ROW_H + GAP
    -- Line 2: "My roles", a large icon per role my class can play, then the
    -- "only groups with room for me" check box.
    p.rolesLabel:ClearAllPoints()
    p.rolesLabel:SetPoint("LEFT", p, "TOPLEFT", 0, -y - ROLE_SIZE / 2)
    local rx = p.rolesLabel:GetStringWidth() + 6
    local allowed = ns.Roles.Allowed()
    for _, k in ipairs(ROLE_KEYS) do
        local b = p.roles[k]
        b:SetShown(allowed[k])
        if allowed[k] then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", p, "TOPLEFT", rx, -y)
            rx = rx + ROLE_SIZE + BUTTON_GAP
        end
    end
    local roomW = math.floor(CHECK + 4 + p.roomOnly.text:GetStringWidth() + 0.5)
    p.roomOnly:SetSize(roomW, ROLE_SIZE)
    p.roomOnly:ClearAllPoints()
    if rx + 8 + roomW > width then
        y = y + ROLE_SIZE + GAP
        p.roomOnly:SetSize(roomW, ROW_H)
        p.roomOnly:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
        y = y + ROW_H + GAP
    else
        p.roomOnly:SetPoint("TOPLEFT", p, "TOPLEFT", rx + 8, -y)
        y = y + ROLE_SIZE + GAP
    end
    -- Line 3: "For:" and the ticked activities (read-only), then the
    -- comment and "Comment..." at the right (a line of its own when narrow).
    p.forLabel:ClearAllPoints()
    p.forLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y - 3)
    local cx0 = p.forLabel:GetStringWidth() + 6
    p.comment:SetWidth(math.max(70, math.floor(p.comment.label:GetStringWidth() + 18)))
    local ids = ns.Window.CheckedList()
    local chipRoom = width - cx0 - p.comment:GetWidth() - MIN_COMMENT_W - 16
    local wrapComment = chipRoom < 80
    if wrapComment then chipRoom = width - cx0 end
    local cx = cx0
    for i, id in ipairs(ids) do
        local c = chip(i)
        c.activityID = id
        c:SetLabel(ns.Abbrev.Chip(id))
        local w = c:Fit()
        if cx + w > cx0 + chipRoom and i > 1 then
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
    p.hint:SetPoint("TOPLEFT", p, "TOPLEFT", cx0, -y - 3)
    p.hint:SetShown(#ids == 0)
    if #ids == 0 then cx = cx0 + p.hint:GetStringWidth() + 8 end
    if wrapComment then
        y = y + ROW_H + GAP
        cx = 0
    end
    p.comment:ClearAllPoints()
    p.comment:SetPoint("TOPRIGHT", p, "TOPLEFT", width, -y)
    p.commentText:ClearAllPoints()
    p.commentText:SetPoint("TOPLEFT", p, "TOPLEFT", cx + 4, -y - 3)
    p.commentText:SetWidth(math.max(20, width - cx - 4 - p.comment:GetWidth() - 8))
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

-- A large role icon (Blizzard's role atlas, as in the rows): chosen = full
-- colour with a gold ring, not chosen = grey and faint.
local function roleToggle(k)
    local b = CreateFrame("Button", nil, p)
    b:SetSize(ROLE_SIZE, ROLE_SIZE)
    b:RegisterForClicks("LeftButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetAtlas(ns.Rows.RoleAtlas(ROLE_ATLAS[k]))
    b.ring = Controls.Outline(b, { 0, 0, 0, 0 }, "OVERLAY")
    b.roleKey = k
    b:SetScript("OnClick", function() Panel.ToggleRole(k) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L[ROLE_LABEL[k]], Controls.GOLD[1], Controls.GOLD[2], Controls.GOLD[3])
        GameTooltip:AddLine(L.TIP_ROLES, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- "Only groups with room for me": a check box and its label; the whole
-- line is the click target.
local function roomCheck()
    local b = CreateFrame("Button", nil, p)
    b:RegisterForClicks("LeftButtonUp")
    b.box = Controls.CheckMark(b, CHECK)
    b.box:SetPoint("LEFT", 0, 0)
    b.text = Controls.Text(b, "small")
    Controls.Restyle(b.text, Controls.TEXT)
    b.text:SetPoint("LEFT", b.box, "RIGHT", 4, 0)
    b:SetScript("OnClick", function() ns.Window.ToggleFilter("filterMyRole") end)
    b:SetScript("OnEnter", function(self) Controls.Tooltip(self, L.TIP_FILTER_ROOM_FOR_ME) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function Panel.Create(parent)
    p = CreateFrame("Frame", nil, parent)
    p.title = Controls.Text(p, "activity")
    p.pill = CreateFrame("Frame", nil, p)
    p.pill.bg = p.pill:CreateTexture(nil, "BACKGROUND")
    p.pill.bg:SetAllPoints()
    p.pill.edges = Controls.Outline(p.pill, Controls.DIM)
    p.status = Controls.Text(p.pill, "small")
    p.status:SetPoint("CENTER")
    p.post = Controls.Button(p, { text = "", height = ROW_H, primary = true,
        onClick = function(_, mouse) Panel.Action(mouse) end })
    p.template = Controls.Button(p, { text = "", height = ROW_H, icon = "ChevronDown", tip = function() return L.TIP_TEMPLATE end,
        onClick = function(self) ns.Menu.Open(self, Panel.BuildTemplateMenu) end })
    p.rolesLabel = Controls.Text(p, "small")
    p.roles = {}
    for _, k in ipairs(ROLE_KEYS) do p.roles[k] = roleToggle(k) end
    p.roomOnly = roomCheck()
    p.forLabel = Controls.Text(p, "small")
    p.chips = {}
    p.hint = Controls.Text(p, "small")
    p.commentText = Controls.Text(p, "comment")
    p.comment = Controls.Button(p, { text = "", height = ROW_H, onClick = function() Panel.OpenComment() end,
        tip = function() return L.TIP_COMMENT end })
    p.warningText = Controls.Text(p, "comment")
    Controls.Restyle(p.warningText, Controls.RED)
    p.extend = Controls.Button(p, { text = "", height = ROW_H, onClick = function() Panel.Extend() end, tip = function() return L.TIP_EXTEND end })
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
