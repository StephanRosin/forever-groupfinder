local ADDON, ns = ...
local L, Controls, Rows = ns.L, ns.Controls, ns.Rows

-- The DETAILS layout's right column while no group is open: when I lead a
-- group, "Missing: ..." and the solo players who want one of the missing
-- roles, each with a one-click Invite; otherwise a hint to click a group.
-- (An open group shows in the same place: Detail.lua's embedded host.)
local Column = {}
ns.Column = Column

local PAD, GAP = 8, 4
local LINE_H, ICON, INVITE_W = 22, 16, 60
local ROLE_KEY = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local c
local fitting = {}   -- the players shown

-- The solo players (Window.Built().players) wanting a role still missing;
-- missing = { TANK = n, HEALER = n, DAMAGER = n } or nil. Pure.
function Column.Fitting(players, missing)
    local out = {}
    if not missing then return out end
    for _, row in ipairs(players or {}) do
        local roles = type(row.roles) == "table" and row.roles or {}   -- plain: Finder converted the row
        local fits = false
        for _, role in ipairs(Rows.ROLES) do
            if (missing[role] or 0) > 0 and roles[ROLE_KEY[role]] == true then fits = true end
        end
        if fits and type(row.leader) == "string" and not row.delisted then out[#out + 1] = row end
    end
    return out
end

function Column.Frame() return c end
function Column.Players() return fitting end

function Column.Invite(row)
    if type(row.leader) == "string" then ns.Finder.Invite(row.leader) end   -- plain: Finder converted the row
end

-- Lines ------------------------------------------------------------------------------------------

local function line(i)
    local l = c.lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, c.list.child)
    l:SetHeight(LINE_H)
    l.roles = {}
    for k = 1, 3 do
        local t = l:CreateTexture(nil, "ARTWORK")
        t:SetSize(ICON, ICON)
        t:SetPoint("LEFT", (k - 1) * (ICON + 1), 0)
        l.roles[k] = t
    end
    l.class = l:CreateTexture(nil, "ARTWORK")
    l.class:SetSize(ICON - 2, ICON - 2)
    l.name = Controls.Text(l, "name")
    l.level = Controls.Text(l, "small")
    l.invite = Controls.Button(l, { text = L.INVITE, width = INVITE_W, height = 18,
        onClick = function(self) if self.row then Column.Invite(self.row) end end,
        tip = function() return L.TIP_COLUMN_INVITE end })
    l.invite:SetPoint("RIGHT", 0, 0)
    c.lines[i] = l
    return l
end

local function layoutLine(l, row, width)
    l:SetWidth(width)
    local wanted = type(row.roles) == "table" and row.roles or {}   -- plain: Finder converted the row
    local n = 0
    for _, role in ipairs(Rows.ROLES) do
        if wanted[ROLE_KEY[role]] == true then
            n = n + 1
            l.roles[n]:SetAtlas(Rows.RoleAtlas(role))
            l.roles[n]:Show()
        end
    end
    for k = n + 1, 3 do l.roles[k]:Hide() end
    local x = 3 * (ICON + 1) + GAP
    local member = type(row.members) == "table" and row.members[1] or {}   -- plain: Finder converted the row
    Rows.SetClassIcon(l.class, member.classFile)
    l.class:ClearAllPoints()
    l.class:SetPoint("LEFT", x, 0)
    Controls.Restyle(l.name)
    Controls.Restyle(l.level)
    l.name:SetText(row.leader)
    l.name:SetTextColor(Rows.ClassColor(member.classFile))
    l.name:ClearAllPoints()
    l.name:SetPoint("LEFT", l.class, "RIGHT", 4, 0)
    l.level:SetText(type(member.level) == "number" and tostring(member.level) or "")
    l.level:ClearAllPoints()
    l.level:SetPoint("LEFT", l.name, "RIGHT", 4, 0)
    l.name:SetWidth(math.max(20, math.min(l.name:GetStringWidth(), width - x - ICON - 30 - INVITE_W - 8)))
    l.invite.row = row
    l.invite:SetLabel(L.INVITE)
end

-- Display ------------------------------------------------------------------------------------------

function Column.Refresh()
    if not c then return end
    if not ns.Layouts.EmbedsDetail() or ns.Detail.OpenID() ~= nil then
        c:Hide()
        return
    end
    c:Show()
    local width = (c.width or 280) - 2 * PAD
    local missing = ns.ListingPanel.LeaderMissing()
    fitting = Column.Fitting(ns.Window.Built().players, missing)
    for _, l in ipairs(c.lines) do l:Hide() end
    c.title:SetWidth(width)
    c.note:SetWidth(width)
    if not missing then
        c.title:SetText(L.COLUMN_TITLE)
        c.note:SetText(L.COLUMN_HINT)
        c.list:Hide()
        return
    end
    c.title:SetText(ns.ListingPanel.LeaderText() or "")
    c.note:SetText(#fitting > 0 and L.COLUMN_PLAYERS:format(#fitting) or L.COLUMN_NO_PLAYERS)
    c.list:Show()
    c.list.child:SetWidth(width)
    for i, row in ipairs(fitting) do
        local l = line(i)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", c.list.child, "TOPLEFT", 0, -(i - 1) * LINE_H)
        layoutLine(l, row, width)
        l:Show()
    end
    c.list:SetContentHeight(#fitting * LINE_H)
end

-- The column's size (Layouts.lua anchors it).
function Column.Layout(w, h)
    if not c then return end
    c.width = w
    c:SetSize(w, h)
    c.list.viewHeight = math.max(0, h - 2 * PAD - 18 - GAP - 30 - GAP)
    Column.Refresh()
end

function Column.Create(parent)
    c = CreateFrame("Frame", nil, parent)
    c.lines = {}
    c.title = Controls.Text(c, "activity")
    c.title:SetPoint("TOPLEFT", PAD, -PAD)
    c.title:SetWordWrap(true)
    c.note = Controls.Text(c, "comment")
    c.note:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -GAP)
    c.note:SetWordWrap(true)
    c.list = Controls.Scroll(c)
    c.list:SetPoint("TOPLEFT", c.note, "BOTTOMLEFT", 0, -GAP - 4)
    c.list:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -PAD, PAD)
    c:Hide()
    return c
end
