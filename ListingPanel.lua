local ADDON, ns = ...
local L, Settings, Controls, Activities, Listing = ns.L, ns.Settings, ns.Controls, ns.Activities, ns.Listing
local S = Settings.Get

-- "My listing" (Layouts.lua places it above the filters), as a table of
-- dim labels and values: Status (a pill: Not listed / Listed · 27 min /
-- Changed – click Update), Roles (a large icon per role my class can play,
-- ns.Roles, and the "Only groups with room for me" check box), For (the
-- ticked activities as read-only chips), Comment (read-only; "Comment..."
-- opens Blizzard's listing tab for players with an authenticator), and the
-- one gold Post / Update / Remove button in the value column. Below: the
-- expiry warning with "Extend" and the leader line ("Missing: ...").
--
-- Posting needs a click: Post, Extend and Remove run from OnClick
-- handlers only.
local Panel = {}
ns.ListingPanel = Panel

local GAP = 4
local PILL_H, PILL_PAD = 16, 6   -- the status pill
local ROLE_SIZE = 28              -- a role icon toggle
local LABEL_MIN, LABEL_MAX, COL_GAP = 44, 96, 8   -- the label column
local ROLE_ATLAS = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }
local BUTTON_GAP = 4
local ROLE_KEYS = { "tank", "healer", "dps" }
local ROLE_LABEL = { tank = "ROLE_TANK", healer = "ROLE_HEALER", dps = "ROLE_DAMAGER" }

local p
local warning = false      -- the expiry warning is showing

-- State -------------------------------------------------------------------------------------

-- My selected roles (ns.Roles), the same everywhere.
function Panel.Roles() return ns.Roles.Selected() end

function Panel.Warning() return warning end
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

-- Blizzard's listing tab, where the comment is written (authenticator only).
function Panel.OpenComment()
    local result = Listing.OpenCommentEditor()
    ns.Window.ListingChanged()
    return result
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
    c = Controls.Tag(p, { text = "", tip = function(self)
        local name = self.activityID and Activities.Name(self.activityID) or L.UNKNOWN_ACTIVITY   -- plain: our chip's id
        return name .. "\n" .. L.TIP_ACTIVITY_CHIP
    end })
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
    local ids = ns.Window.CheckedList()
    local mode = not state.active and "POST" or (Panel.Changed() and "UPDATE" or "REMOVE")
    p.post.mode = mode
    p.post:SetLabel(L[mode])
    p.post:SetOff(mode == "POST" and #ids == 0, L.TIP_POST_NEEDS_ACTIVITY)
    p.post.tip = L["TIP_" .. mode]
    paintPill(pillState(state, mode))
    for key, fs in pairs(p.labels) do fs:SetText(L["LISTING_LABEL_" .. key]) end
    p.roomOnly:SetLabel(L.FILTER_ROOM_FOR_ME)
    p.roomOnly:SetChecked(S("filterMyRole"))
    p.comment:SetLabel(L.COMMENT_BUTTON)
    p.comment:SetOff(not Listing.CanComment(), L.TIP_COMMENT_NEEDS_AUTH)
    p.extend:SetLabel(L.EXTEND)
    local comment = state.comment
    if type(comment) == "string" and comment ~= "" then
        Controls.Restyle(p.commentText)
        p.commentText:SetText(comment)
    else
        Controls.Restyle(p.commentText, Controls.DIM)
        p.commentText:SetText(L.NO_COMMENT)
    end
    local r = Panel.Roles()
    for _, k in ipairs(ROLE_KEYS) do
        p.roles[k].on = r[k] == true
        paintRole(p.roles[k])
    end
    p.hint:SetText(L.HINT_TICK_ACTIVITIES)
    p.warningText:SetText(L.EXPIRY_WARNING)
    p.leader:SetText(Panel.LeaderText() or "")
end

-- A table: dim labels right-aligned in a fixed column, the values beside
-- them; the main button sits in the value column under the comment.
--   Status   [pill]
--   Roles    [role icons] [x] Only groups with room for me
--   For      [activity chips] (or the hint)
--   Comment  comment text            [Comment...]
--            [ Post / Update / Remove ]
-- Values that do not fit wrap inside the value column. Returns the height.
local LABEL_ORDER = { "STATUS", "ROLES", "FOR", "COMMENT" }

local function label(key, y, h)
    local fs = p.labels[key]
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", p, "TOPLEFT", p.labelW, -y - h / 2)
end

function Panel.Layout(width)
    if not p then return 0 end
    Panel.Refresh()
    local bh, ch = Controls.ButtonHeight(), Controls.ChipHeight()
    local labelW = 0
    for _, key in ipairs(LABEL_ORDER) do
        local fs = p.labels[key]
        Controls.Restyle(fs, Controls.DIM)
        labelW = math.max(labelW, fs:GetStringWidth())
    end
    p.labelW = math.floor(math.min(LABEL_MAX, math.max(LABEL_MIN, labelW)) + 0.5)
    local vx = p.labelW + COL_GAP          -- the value column's left edge
    local vw = math.max(60, width - vx)    -- and its width
    local y = 0
    -- Status.
    local h = math.max(PILL_H, ch)
    label("STATUS", y, h)
    p.pill:ClearAllPoints()
    p.pill:SetPoint("LEFT", p, "TOPLEFT", vx, -y - h / 2)
    y = y + h + GAP
    -- Roles: the icons my class can play, then the check box (next line when
    -- it does not fit).
    local roleSize = math.max(ROLE_SIZE, bh)
    label("ROLES", y, roleSize)
    local rx = 0
    local allowed = ns.Roles.Allowed()
    for _, k in ipairs(ROLE_KEYS) do
        local b = p.roles[k]
        b:SetShown(allowed[k])
        if allowed[k] then
            b:SetSize(roleSize, roleSize)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", p, "TOPLEFT", vx + rx, -y)
            rx = rx + roleSize + BUTTON_GAP
        end
    end
    local roomW = p.roomOnly:Fit()
    p.roomOnly:ClearAllPoints()
    if rx + 8 + roomW > vw then
        y = y + roleSize + GAP
        p.roomOnly:SetPoint("TOPLEFT", p, "TOPLEFT", vx, -y)
        y = y + ch + GAP
    else
        p.roomOnly:SetPoint("LEFT", p, "TOPLEFT", vx + rx + 8, -y - roleSize / 2)
        y = y + roleSize + GAP
    end
    -- For: the ticked activities, wrapping inside the value column.
    label("FOR", y, ch)
    local ids = ns.Window.CheckedList()
    local cx, lines = 0, 0
    for i, id in ipairs(ids) do
        local c = chip(i)
        c.activityID = id
        c:SetLabel(ns.Abbrev.Chip(id))
        local w = math.min(c:Fit(), vw)
        c:SetWidth(w)
        if cx > 0 and cx + w > vw then cx, lines = 0, lines + 1 end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", p, "TOPLEFT", vx + cx, -y - lines * (ch + 2))
        c:Show()
        cx = cx + w + BUTTON_GAP
    end
    for i = #ids + 1, #p.chips do p.chips[i]:Hide() end
    p.hint:ClearAllPoints()
    p.hint:SetPoint("LEFT", p, "TOPLEFT", vx, -y - ch / 2)
    p.hint:SetWidth(vw)
    p.hint:SetShown(#ids == 0)
    y = y + (lines + 1) * (ch + 2) - 2 + GAP
    -- Comment: the text, "Comment..." at the value column's right end.
    h = math.max(bh, ch)
    label("COMMENT", y, h)
    p.comment:SetWidth(math.min(vw, math.max(70, math.floor(p.comment.label:GetStringWidth() + 18))))
    p.comment:ClearAllPoints()
    p.comment:SetPoint("TOPRIGHT", p, "TOPLEFT", vx + vw, -y)
    p.commentText:ClearAllPoints()
    p.commentText:SetPoint("LEFT", p, "TOPLEFT", vx, -y - h / 2)
    p.commentText:SetWidth(math.max(10, vw - p.comment:GetWidth() - 8))
    y = y + h + GAP
    -- The main button, in the value column, larger and gold.
    local ph = bh + 4
    p.post:SetHeight(ph)
    p.post:SetWidth(math.min(vw, math.max(110, math.floor(p.post.label:GetStringWidth() + 40))))
    p.post:ClearAllPoints()
    p.post:SetPoint("TOPLEFT", p, "TOPLEFT", vx, -y)
    y = y + ph + GAP
    -- Expiry warning with "Extend".
    p.warningText:SetShown(warning)
    p.extend:SetShown(warning)
    if warning then
        p.warningText:ClearAllPoints()
        p.warningText:SetPoint("LEFT", p, "TOPLEFT", vx, -y - bh / 2)
        p.extend:SetWidth(math.max(56, math.floor(p.extend.label:GetStringWidth() + 18)))
        p.extend:ClearAllPoints()
        p.extend:SetPoint("LEFT", p.warningText, "RIGHT", 8, 0)
        y = y + bh + GAP
    end
    -- Leader line.
    local leader = Panel.LeaderText()
    p.leader:SetShown(leader ~= nil)
    if leader then
        p.leader:ClearAllPoints()
        p.leader:SetPoint("TOPLEFT", p, "TOPLEFT", vx, -y - 2)
        y = y + 16 + GAP
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

function Panel.Create(parent)
    p = CreateFrame("Frame", nil, parent)
    p.labels = {}
    for _, key in ipairs(LABEL_ORDER) do
        local fs = Controls.Text(p, "small")
        fs:SetJustifyH("RIGHT")
        p.labels[key] = fs
    end
    p.pill = CreateFrame("Frame", nil, p)
    p.pill.bg = p.pill:CreateTexture(nil, "BACKGROUND")
    p.pill.bg:SetAllPoints()
    p.pill.edges = Controls.Outline(p.pill, Controls.DIM)
    p.status = Controls.Text(p.pill, "small")
    p.status:SetPoint("CENTER")
    p.post = Controls.Button(p, { text = "", primary = true,
        onClick = function(_, mouse) Panel.Action(mouse) end })
    p.roles = {}
    for _, k in ipairs(ROLE_KEYS) do p.roles[k] = roleToggle(k) end
    p.roomOnly = Controls.CheckLabel(p, { onClick = function() ns.Window.ToggleFilter("filterMyRole") end,
        tip = function() return L.TIP_FILTER_ROOM_FOR_ME end })
    p.chips = {}
    p.hint = Controls.Text(p, "small")
    p.commentText = Controls.Text(p, "comment")
    p.comment = Controls.Button(p, { text = "", onClick = function() Panel.OpenComment() end,
        tip = function() return L.TIP_COMMENT end })
    p.warningText = Controls.Text(p, "comment")
    Controls.Restyle(p.warningText, Controls.RED)
    p.extend = Controls.Button(p, { text = "", onClick = function() Panel.Extend() end, tip = function() return L.TIP_EXTEND end })
    p.leader = Controls.Text(p, "comment")
    Controls.Restyle(p.leader, Controls.GOLD)
    Panel.Refresh()
    return p
end

-- The expiry warning, once per listing (Listing.lua decides when).
Listing.OnExpiryWarning(function(remaining)
    warning = true
    ns.Print(L.MSG_EXPIRING, Controls.Age(remaining) or "")
    if ns.Window.IsShown() then ns.Window.ListingChanged() end
end)
