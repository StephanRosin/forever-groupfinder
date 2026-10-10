local ADDON, ns = ...
local L, Controls, Rows = ns.L, ns.Controls, ns.Rows

-- The leader line: while I lead a group and a role is still missing, one
-- line above the filters (every layout) lists the solo players from the
-- list who want a missing role, each a chip: role icon and class-coloured
-- name; a click invites. More than fit: "+n". ("Missing: ..." itself is in
-- my listing.)
local Column = {}
ns.Column = Column

local LINE_H, ICON, GAP = 20, 14, 4
local MORE_W = 28
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

-- Chips ------------------------------------------------------------------------------------------

local function wantedRole(row)
    local wanted = type(row.roles) == "table" and row.roles or {}   -- plain: Finder converted the row
    for _, role in ipairs(Rows.ROLES) do
        if wanted[ROLE_KEY[role]] == true then return role end
    end
end

local function chip(i)
    local b = c.chips[i]
    if b then return b end
    b = Controls.Button(c, { text = "", height = LINE_H - 2,
        onClick = function(self) if self.row then Column.Invite(self.row) end end,
        tip = function(self) return self.row and L.TIP_COLUMN_INVITE:format(self.row.leader) or nil end })
    b.role = b:CreateTexture(nil, "ARTWORK")
    b.role:SetSize(ICON, ICON)
    b.role:SetPoint("LEFT", 3, 0)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", b.role, "RIGHT", 3, 0)
    c.chips[i] = b
    return b
end

-- Lays the line out for width; returns its height (0: not shown).
function Column.Layout(width)
    if not c then return 0 end
    local missing = ns.ListingPanel.LeaderMissing()
    fitting = Column.Fitting(ns.Window.Built().players, missing)
    for _, b in ipairs(c.chips) do b:Hide() end
    if not missing or #fitting == 0 then
        c:Hide()
        return 0
    end
    c.title:SetText(L.COLUMN_PLAYERS:format(#fitting))
    local x = c.title:GetStringWidth() + 8
    local shown = 0
    for i, row in ipairs(fitting) do
        local b = chip(i)
        b.row = row
        b.role:SetAtlas(Rows.RoleAtlas(wantedRole(row)))
        b:SetLabel(row.leader)
        local member = type(row.members) == "table" and row.members[1] or {}   -- plain: Finder converted the row
        b.label:SetTextColor(Rows.ClassColor(member.classFile))
        local w = math.floor(ICON + 9 + b.label:GetStringWidth() + 0.5)
        local last = i == #fitting
        if x + w > width - (last and 0 or MORE_W) then break end
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("LEFT", c, "LEFT", x, 0)
        b:Show()
        x, shown = x + w + GAP, shown + 1
    end
    c.more:SetText(shown < #fitting and ("+" .. (#fitting - shown)) or "")
    c.more:ClearAllPoints()
    c.more:SetPoint("LEFT", c, "LEFT", x, 0)
    c:Show()
    return LINE_H
end

-- Called when the list or my group changed (Window.Rebuild): the line may
-- come or go, so the window arranges again.
function Column.Refresh()
    if c and ns.Window.Frame() then ns.Window.Arrange() end
end

function Column.Create(parent)
    c = CreateFrame("Frame", nil, parent)
    c:SetHeight(LINE_H)
    c.chips = {}
    c.title = Controls.Text(c, "small")
    Controls.Restyle(c.title, Controls.GOLD)
    c.title:SetPoint("LEFT", 0, 0)
    c.more = Controls.Text(c, "small")
    c:Hide()
    return c
end
