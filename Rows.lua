local ADDON, ns = ...
local L, Settings, Controls, Activities = ns.L, ns.Settings, ns.Controls, ns.Activities
local S = Settings.Get

-- The rows of the result list: dividers ("Groups (3)"), group rows (one
-- line) and player rows (two lines). Rows are pooled per kind and reused;
-- Rows.Layout fills one for an entry and returns its height. Every field of
-- a result row may be nil (Finder turned a secret into nil): each read is
-- checked by type.
local Rows = {}
ns.Rows = Rows

local EDGE_W = 3
local SQUARE, SQUARE_GAP, MAX_SQUARES = 12, 2, 5
local AGE_W = 46
local PAD = 6
local PLAYER_LEFT_W = 160
local INVITE_W = 46
local CHIP_GAP = 3
local ICON = 14
local DIVIDER_H = 18
local TAG_COLOR = { 0.5, 0.82, 1 }
local SEEN_ALPHA, DELISTED_ALPHA = 0.45, 0.5
local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local PIN_ATLAS = "Waypoint-MapPin-Untracked"
local ROLE_ATLAS = { tank = "groupfinder-icon-role-micro-tank", healer = "groupfinder-icon-role-micro-heal",
    dps = "groupfinder-icon-role-micro-dps" }
local ROLE_ORDER = { "tank", "healer", "dps" }
local ROLE_LABEL = { tank = "ROLE_TANK", healer = "ROLE_HEALER", dps = "ROLE_DAMAGER",
    TANK = "ROLE_TANK", HEALER = "ROLE_HEALER", DAMAGER = "ROLE_DAMAGER" }

Rows.DIVIDER_H = DIVIDER_H

-- Colours and names -------------------------------------------------------------------

function Rows.ClassColor(classFile)
    if type(classFile) ~= "string" then return 0.6, 0.6, 0.6 end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local c = C_ClassColor.GetClassColor(classFile)
        if c then return c.r, c.g, c.b end
    end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 0.6, 0.6, 0.6
end

function Rows.ClassName(classFile)
    if type(classFile) ~= "string" then return nil end
    local names = LOCALIZED_CLASS_NAMES_MALE
    return names and names[classFile] or classFile
end

local function atlasExists(name)
    if C_Texture and C_Texture.GetAtlasInfo then return C_Texture.GetAtlasInfo(name) ~= nil end
    return true
end

-- The class icon as the combat meter draws it: the finder's own class atlas,
-- else the character-creation sheet.
local function setClassIcon(tex, classFile)
    tex:SetTexCoord(0, 1, 0, 1)
    if type(classFile) ~= "string" then
        tex:Hide()
        return
    end
    local atlas = "groupfinder-icon-class-" .. classFile:lower()
    if atlasExists(atlas) then
        tex:SetAtlas(atlas)
    else
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
        if not coords then
            tex:Hide()
            return
        end
        tex:SetTexture(CLASS_SHEET)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
    tex:Show()
end

-- "Deadmines, +1": the first activity and how many more.
function Rows.ActivityText(ids)
    if type(ids) ~= "table" or #ids == 0 then return L.UNKNOWN_ACTIVITY end
    local first = Activities.Name(ids[1]) or L.UNKNOWN_ACTIVITY
    if #ids > 1 then return L.ACTIVITY_MORE:format(first, #ids - 1) end
    return first
end

function Rows.MaxPlayers(ids)
    local max = 0
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local info = Activities.Info(id)
        if info and info.maxPlayers > max then max = info.maxPlayers end
    end
    return max
end

local function roleNames(roles)
    local out = {}
    if type(roles) ~= "table" then return out end
    for _, key in ipairs(ROLE_ORDER) do
        if roles[key] == true then out[#out + 1] = L[ROLE_LABEL[key]] end
    end
    return out
end

local function ageOf(row, elapsed)
    if type(row.age) ~= "number" then return nil end
    return row.age + (elapsed or 0)
end

-- Tooltip ------------------------------------------------------------------------------

-- The lines of a row's tooltip: { text, color, right, wrap }.
function Rows.TooltipLines(row, elapsed)
    local lines = {}
    local function add(text, color, right, wrap)
        lines[#lines + 1] = { text = text, color = color or Controls.TEXT, right = right, wrap = wrap }
    end
    local names = {}
    for _, id in ipairs(type(row.activityIDs) == "table" and row.activityIDs or {}) do   -- plain: Finder converted the row
        names[#names + 1] = Activities.Name(id) or L.UNKNOWN_ACTIVITY
    end
    add(#names > 0 and table.concat(names, ", ") or L.UNKNOWN_ACTIVITY, Controls.GOLD, nil, true)
    for _, m in ipairs(type(row.members) == "table" and row.members or {}) do
        local name = type(m.name) == "string" and m.name or L.UNKNOWN_PLAYER   -- plain: Finder converted the member
        local left = type(m.level) == "number" and L.TIP_MEMBER:format(name, m.level) or name
        local parts = {}
        parts[#parts + 1] = Rows.ClassName(m.classFile)
        local role = type(m.role) == "string" and ROLE_LABEL[m.role]
        if role then parts[#parts + 1] = L[role] end   -- plain: our own lookup
        if type(m.area) == "string" and m.area ~= "" then parts[#parts + 1] = m.area end
        local r, g, b = Rows.ClassColor(m.classFile)
        add(left, { r, g, b }, table.concat(parts, " - "))
    end
    local wanted = roleNames(row.roles)
    if #wanted > 0 then add(L.TIP_WANTED_ROLES:format(table.concat(wanted, ", ")), Controls.DIM) end
    if type(row.comment) == "string" and row.comment ~= "" then add(row.comment, { 1, 1, 1 }, nil, true) end
    local age = Controls.Age(ageOf(row, elapsed))
    if age then add(L.TIP_AGE:format(age), Controls.DIM) end   -- plain: our formatted text
    if row.delisted == true then add(L.DELISTED, Controls.RED) end
    add(L.TIP_ROW_CLICKS, Controls.ACCENT, nil, true)
    return lines
end

function Rows.ShowTooltip(owner, row, elapsed)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for _, line in ipairs(Rows.TooltipLines(row, elapsed)) do
        local c = line.color
        if line.right then
            GameTooltip:AddDoubleLine(line.text, line.right, c[1], c[2], c[3], 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(line.text, c[1], c[2], c[3], line.wrap)
        end
    end
    GameTooltip:Show()
end

-- Shared pieces ------------------------------------------------------------------------

local function newBase(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:EnableMouse(true)
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.05)
    row.hover:Hide()
    row.open = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.open:SetPoint("TOPLEFT")
    row.open:SetPoint("BOTTOMRIGHT")
    row.open:SetColorTexture(Controls.GREEN[1], Controls.GREEN[2], Controls.GREEN[3], 0.08)
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(EDGE_W)
    row.edge:SetColorTexture(Controls.GREEN[1], Controls.GREEN[2], Controls.GREEN[3], 1)
    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row.line:SetHeight(1)
    row.line:SetColorTexture(0.11, 0.13, 0.19, 1)
    row.age = Controls.Text(row, "small")
    row.age:SetJustifyH("RIGHT")
    row.age:SetWidth(AGE_W)
    row.strike = row:CreateTexture(nil, "OVERLAY")
    row.strike:SetHeight(1)
    row.strike:SetColorTexture(Controls.RED[1], Controls.RED[2], Controls.RED[3], 0.9)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if self.entry then Rows.ShowTooltip(self, self.entry, ns.Window.Elapsed()) end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, mouse)
        local entry = self.entry
        if not entry then return end
        if mouse == "RightButton" then
            ns.Menu.OpenRowMenu(self, entry)
        else
            Rows.Whisper(entry)
        end
    end)
    return row
end

-- Left click: whisper the leader (or the player) and remember the row as seen.
function Rows.Whisper(entry)
    if type(entry.leader) ~= "string" then return end
    ns.Finder.Whisper(entry.leader)
    ns.Memory.MarkSeen(entry.key)
    ns.Window.RefreshRows()
end

local function markers(row, entry)
    local open = entry.freeForMe == true and S("markOpenSlot") and entry.kind == "GROUP"
    row.edge:SetShown(open and true or false)
    row.open:SetShown(open and true or false)
    local alpha = 1
    if entry.seen == true then alpha = SEEN_ALPHA end
    if entry.delisted == true then alpha = math.min(alpha, DELISTED_ALPHA) end
    row:SetAlpha(alpha)
end

function Rows.SetAge(row, entry, elapsed)
    if not row.age then return end   -- plain: a font string
    row.age:SetText(Controls.Age(ageOf(entry, elapsed)) or "")
end

-- Dividers ------------------------------------------------------------------------------

local function newDivider(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.08, 0.1, 0.15, 1)
    row.text = Controls.Text(row, "small")
    row.text:SetPoint("LEFT", PAD + 2, 0)
    return row
end

local function layoutDivider(row, entry, width)
    Controls.Restyle(row.text, { 0.78, 0.59, 0.12 })
    row.text:SetText(entry.text)
    row:SetSize(width, DIVIDER_H)
    return DIVIDER_H
end

-- Groups ---------------------------------------------------------------------------------

local function newSquare(row)
    local sq = CreateFrame("Frame", nil, row)
    sq:SetSize(SQUARE, SQUARE)
    sq.fill = sq:CreateTexture(nil, "ARTWORK")
    sq.fill:SetPoint("TOPLEFT", 1, -1)
    sq.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    sq.edges = Controls.Outline(sq, { 0, 0, 0, 1 })
    return sq
end

local function newGroup(parent)
    local row = newBase(parent)
    row.activity = Controls.Text(row, "activity")
    row.squares = {}
    for i = 1, MAX_SQUARES do row.squares[i] = newSquare(row) end
    row.more = Controls.Text(row, "small")
    row.tag = Controls.Text(row, "small")
    row.comment = Controls.Text(row, "comment")
    return row
end

local function layoutSquares(row, entry, x)
    local members = type(entry.members) == "table" and entry.members or {}
    local count = #members
    local max = Rows.MaxPlayers(entry.activityIDs)
    local slots = math.min(MAX_SQUARES, math.max(count, max))
    for i = 1, MAX_SQUARES do
        local sq = row.squares[i]
        sq:ClearAllPoints()
        sq:SetPoint("LEFT", row, "LEFT", x + (i - 1) * (SQUARE + SQUARE_GAP), 0)
        local m = members[i]
        if i <= slots and m then
            local r, g, b = Rows.ClassColor(m.classFile)
            sq.fill:SetColorTexture(r, g, b, 1)
            sq.fill:Show()
            Controls.PaintOutline(sq.edges, { 0, 0, 0, 1 })
            sq.free = false
            sq:Show()
        elseif i <= slots then
            sq.fill:Hide()
            Controls.PaintOutline(sq.edges, { 0.4, 0.4, 0.4, 0.8 })
            sq.free = true
            sq:Show()
        else
            sq:Hide()
        end
    end
    local extra = count - MAX_SQUARES
    row.more:ClearAllPoints()
    row.more:SetPoint("LEFT", row, "LEFT", x + MAX_SQUARES * (SQUARE + SQUARE_GAP), 0)
    row.more:SetText(extra > 0 and L.MORE_MEMBERS:format(extra) or "")
    return MAX_SQUARES * (SQUARE + SQUARE_GAP) + 26
end

local function tagText(entry)
    if type(entry.friend) == "number" and entry.friend > 0 then return L.TAG_FRIEND end
    if type(entry.guild) == "number" and entry.guild > 0 then return L.TAG_GUILD end
    return ""
end

local function layoutGroup(row, entry, width, elapsed)
    local h = S("rowHeight")
    row:SetSize(width, h)
    for _, fs in ipairs({ row.activity, row.more, row.tag, row.comment, row.age }) do Controls.Restyle(fs) end
    Controls.Color(row.tag, TAG_COLOR)
    local x = EDGE_W + PAD
    local actW = math.max(90, math.min(170, math.floor(width * 0.28)))
    row.activity:ClearAllPoints()
    row.activity:SetPoint("LEFT", row, "LEFT", x, 0)
    row.activity:SetWidth(actW)
    row.activity:SetText(Rows.ActivityText(entry.activityIDs))
    x = x + actW + PAD
    x = x + layoutSquares(row, entry, x)
    local tag = tagText(entry)
    row.tag:ClearAllPoints()
    row.tag:SetPoint("LEFT", row, "LEFT", x, 0)
    row.tag:SetText(tag)
    if tag ~= "" then x = x + row.tag:GetStringWidth() + 4 end
    row.comment:ClearAllPoints()
    row.comment:SetPoint("LEFT", row, "LEFT", x, 0)
    row.comment:SetWidth(math.max(10, width - x - AGE_W - PAD))
    row.comment:SetText(type(entry.comment) == "string" and entry.comment or "")   -- plain: Finder converted the row
    row.age:ClearAllPoints()
    row.age:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    Rows.SetAge(row, entry, elapsed)
    row.strike:ClearAllPoints()
    row.strike:SetPoint("LEFT", row.activity, "LEFT", 0, 0)
    row.strike:SetPoint("RIGHT", row, "RIGHT", -AGE_W - PAD, 0)
    row.strike:SetShown(entry.delisted == true)
    markers(row, entry)
    return h
end

-- Players --------------------------------------------------------------------------------

local function newChip(row)
    local chip = CreateFrame("Frame", nil, row)
    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()
    chip.bg:SetColorTexture(0.11, 0.09, 0.06, 1)
    chip.edges = Controls.Outline(chip, { 0.36, 0.29, 0.13, 1 })
    chip.text = Controls.Text(chip, "small")
    chip.text:SetPoint("CENTER")
    return chip
end

local function newPlayer(parent)
    local row = newBase(parent)
    row.class = row:CreateTexture(nil, "ARTWORK")
    row.class:SetSize(ICON, ICON)
    row.name = Controls.Text(row, "name")
    row.level = Controls.Text(row, "small")
    row.roles = {}
    for i, key in ipairs(ROLE_ORDER) do
        row.roles[i] = row:CreateTexture(nil, "ARTWORK")
        row.roles[i]:SetSize(12, 12)
        row.roles[i]:SetAtlas(ROLE_ATLAS[key])
    end
    row.pin = row:CreateTexture(nil, "ARTWORK")
    row.pin:SetSize(12, 12)
    row.pin:SetAtlas(PIN_ATLAS)
    row.area = Controls.Text(row, "activity")
    row.chips = {}
    row.more = Controls.Text(row, "small")
    row.comment = Controls.Text(row, "comment")
    row.invite = Controls.Button(row, { text = L.INVITE, width = INVITE_W, height = 16,
        onClick = function(self) if self.leader then ns.Finder.Invite(self.leader) end end })
    return row
end

local function layoutChips(row, entry, x, y, w)
    local ids = type(entry.activityIDs) == "table" and entry.activityIDs or {}   -- plain: Finder converted the row
    local used, shown = 0, 0
    for i, id in ipairs(ids) do
        local chip = row.chips[i] or newChip(row)
        row.chips[i] = chip
        Controls.Restyle(chip.text)
        chip.text:SetText(Activities.Name(id) or L.UNKNOWN_ACTIVITY)
        local cw = math.floor(chip.text:GetStringWidth() + 10 + 0.5)
        if used + cw > w - 24 and shown > 0 then
            chip:Hide()
        else
            chip:SetSize(cw, 14)
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", row, "TOPLEFT", x + used, y)
            chip:Show()
            used, shown = used + cw + CHIP_GAP, shown + 1
        end
    end
    for i = #ids + 1, #row.chips do row.chips[i]:Hide() end
    row.more:ClearAllPoints()
    row.more:SetPoint("TOPLEFT", row, "TOPLEFT", x + used, y - 1)
    row.more:SetText(#ids > shown and L.MORE_MEMBERS:format(#ids - shown) or "")
    row.shownChips = shown
end

local function layoutPlayer(row, entry, width, elapsed)
    local h = S("playerRowHeight")
    row:SetSize(width, h)
    for _, fs in ipairs({ row.name, row.level, row.area, row.more, row.comment, row.age }) do Controls.Restyle(fs) end
    local first = type(entry.members) == "table" and entry.members[1] or {}
    local top, bottom = -3, -math.floor(h / 2) - 1
    local x = EDGE_W + PAD
    setClassIcon(row.class, first.classFile)
    row.class:ClearAllPoints()
    row.class:SetPoint("TOPLEFT", row, "TOPLEFT", x, top)
    local nx = x + ICON + 4
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", nx, top)
    row.name:SetText(type(entry.leader) == "string" and entry.leader or L.UNKNOWN_PLAYER)
    row.name:SetTextColor(Rows.ClassColor(first.classFile))
    local nameW = math.min(row.name:GetStringWidth(), PLAYER_LEFT_W - ICON - 60)
    row.name:SetWidth(nameW)
    row.level:ClearAllPoints()
    row.level:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.level:SetText(type(first.level) == "number" and tostring(first.level) or "")
    local rx = nx + nameW + 4 + row.level:GetStringWidth() + 4
    for i, key in ipairs(ROLE_ORDER) do
        local tex = row.roles[i]
        local wanted = type(entry.roles) == "table" and entry.roles[key] == true
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", row, "TOPLEFT", rx, top)
        tex:SetShown(wanted)
        if wanted then rx = rx + 13 end
    end
    row.pin:ClearAllPoints()
    row.pin:SetPoint("TOPLEFT", row, "TOPLEFT", x + 1, bottom)
    row.area:ClearAllPoints()
    row.area:SetPoint("TOPLEFT", row, "TOPLEFT", nx, bottom)
    row.area:SetWidth(PLAYER_LEFT_W - ICON - 4)
    local area = type(entry.area) == "string" and entry.area ~= "" and entry.area or L.UNKNOWN_AREA
    row.area:SetText(area)
    local bx = x + PLAYER_LEFT_W
    local bw = math.max(40, width - bx - INVITE_W - AGE_W - 2 * PAD)
    layoutChips(row, entry, bx, top, bw)
    row.comment:ClearAllPoints()
    row.comment:SetPoint("TOPLEFT", row, "TOPLEFT", bx, bottom)
    row.comment:SetWidth(bw)
    row.comment:SetText(type(entry.comment) == "string" and entry.comment or "")   -- plain: Finder converted the row
    row.invite.leader = type(entry.leader) == "string" and entry.leader or nil
    row.invite:ClearAllPoints()
    row.invite:SetPoint("RIGHT", row, "RIGHT", -PAD - AGE_W, 0)
    row.invite:SetShown(row.invite.leader ~= nil)
    row.age:ClearAllPoints()
    row.age:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    Rows.SetAge(row, entry, elapsed)
    row.strike:ClearAllPoints()
    row.strike:SetPoint("LEFT", row.name, "LEFT", 0, 0)
    row.strike:SetPoint("RIGHT", row, "RIGHT", -AGE_W - PAD, 0)
    row.strike:SetShown(entry.delisted == true)
    markers(row, entry)
    return h
end

-- Pools ----------------------------------------------------------------------------------

local MAKERS = { DIVIDER = newDivider, GROUP = newGroup, PLAYER = newPlayer }
local LAYOUTS = { DIVIDER = layoutDivider, GROUP = layoutGroup, PLAYER = layoutPlayer }

-- A pool of rows on parent: Acquire(kind) hands out a free row of that kind
-- (made once, reused afterwards); ReleaseAll hides every row.
function Rows.NewPool(parent)
    local pool = { free = {}, used = {}, made = 0 }
    function pool.Acquire(self, kind)
        self.free[kind] = self.free[kind] or {}
        local row = table.remove(self.free[kind])
        if not row then
            row = MAKERS[kind](parent)
            row.kind = kind
            self.made = self.made + 1
        end
        self.used[#self.used + 1] = row
        row:Show()
        return row
    end
    function pool.ReleaseAll(self)
        for _, row in ipairs(self.used) do
            row:Hide()
            row.entry = nil
            table.insert(self.free[row.kind], row)
        end
        self.used = {}
    end
    return pool
end

-- Fills row for entry; returns its height.
function Rows.Layout(row, entry, width, elapsed)
    if row.kind ~= "DIVIDER" then row.entry = entry end
    return LAYOUTS[row.kind](row, entry, width, elapsed)
end
