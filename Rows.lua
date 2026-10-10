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
local SQUARE_GAP, MAX_SQUARES = 2, 5
local AGE_W = 46
local PAD = 6
local PLAYER_LEFT_W = 150
local LEVEL_W = 24
local INVITE_W = 46
local LEADER_W, LEVELS_W, COUNT_W = 96, 38, 30   -- a group row's leader, levels, "2/5"
local CHIP_GAP = 3
local DIVIDER_H = 18
local TAG_COLOR = { 0.5, 0.82, 1 }
local DELISTED_ALPHA = 0.5
local FREE_ICON_ALPHA = 0.5                -- a free place's role icon
local FREE_EDGE = { 0.78, 0.74, 0.62, 0.9 } -- and its outline
local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local PIN_ATLAS = "Waypoint-MapPin-Untracked"
-- Blizzard's own finder icons (Blizzard_LFGVanilla_Browse.lua).
local ROLE_ATLAS = { TANK = "groupfinder-icon-role-large-tank", HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps" }
local ROLE_ORDER = { "tank", "healer", "dps" }
local ROLE_OF = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }
-- Members and free slots: tanks, then healers, then damage, then unknown.
Rows.ROLES = { "TANK", "HEALER", "DAMAGER" }
local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local ROLE_LABEL = { tank = "ROLE_TANK", healer = "ROLE_HEALER", dps = "ROLE_DAMAGER",
    TANK = "ROLE_TANK", HEALER = "ROLE_HEALER", DAMAGER = "ROLE_DAMAGER" }
Rows.ROLE_LABEL = ROLE_LABEL

Rows.DIVIDER_H = DIVIDER_H

function Rows.RoleAtlas(role) return ROLE_ATLAS[role] end

-- The slots of a group: { member = m, role = } for every member, ordered
-- Tank, Healer, Damage (unknown roles last, the list order kept), then
-- { free = true, role = } per free place from the counts' *_REMAINING in
-- the same order. Without counts the free places up to the activity's size
-- have no role.
function Rows.Slots(entry)
    local members = type(entry.members) == "table" and entry.members or {}   -- plain: Finder converted the row
    local slots = {}
    for i, m in ipairs(members) do
        local role = type(m.role) == "string" and ROLE_RANK[m.role] and m.role or nil   -- plain: Finder converted the member
        slots[#slots + 1] = { member = m, role = role, index = i }
    end
    table.sort(slots, function(a, b)
        local ra, rb = ROLE_RANK[a.role] or 4, ROLE_RANK[b.role] or 4
        if ra ~= rb then return ra < rb end
        return a.index < b.index
    end)
    local counts = type(entry.counts) == "table" and entry.counts or {}
    local known = false
    for _, role in ipairs(Rows.ROLES) do
        local n = counts[role .. "_REMAINING"]
        if type(n) == "number" then
            known = true
            for _ = 1, n do slots[#slots + 1] = { free = true, role = role } end
        end
    end
    if not known then
        for _ = #members + 1, Rows.MaxPlayers(entry.activityIDs) do slots[#slots + 1] = { free = true } end
    end
    return slots
end

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
Rows.SetClassIcon = setClassIcon

-- "Deadmines, +1": the first activity and how many more.
function Rows.ActivityText(ids)
    if type(ids) ~= "table" or #ids == 0 then return L.UNKNOWN_ACTIVITY end
    local first = Activities.Name(ids[1]) or L.UNKNOWN_ACTIVITY
    if #ids > 1 then return L.ACTIVITY_MORE:format(first, #ids - 1) end
    return first
end

-- What decides on a group at a glance: the leader (name, class), the
-- members' level range and how full it is. Pure; fields may be nil.
function Rows.GroupFacts(entry)
    local members = type(entry.members) == "table" and entry.members or {}   -- plain: Finder converted the row
    local leader = type(entry.leader) == "string" and entry.leader or nil
    local facts = { leader = leader, count = #members, max = Rows.MaxPlayers(entry.activityIDs) }
    if type(entry.numMembers) == "number" then facts.count = entry.numMembers end
    for _, m in ipairs(members) do
        if (m.isLeader == true or (leader ~= nil and m.name == leader)) and not facts.classFile then
            facts.classFile = m.classFile
        end
        if type(m.level) == "number" then
            facts.minLevel = math.min(facts.minLevel or m.level, m.level)
            facts.maxLevel = math.max(facts.maxLevel or m.level, m.level)
        end
    end
    return facts
end

-- The list shows one activity only: group rows leave its name out (the
-- divider names it). Set by Window.RenderList.
Rows.singleActivity = nil

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
    add(row.kind == "GROUP" and L.TIP_GROUP_CLICKS or L.TIP_ROW_CLICKS, Controls.ACCENT, nil, true)
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
    row.age = Controls.Text(row, "age")
    row.age:SetJustifyH("RIGHT")
    row.age:SetWidth(AGE_W)
    row.strike = row:CreateTexture(nil, "OVERLAY")
    row.strike:SetHeight(1)
    row.strike:SetColorTexture(Controls.RED[1], Controls.RED[2], Controls.RED[3], 0.9)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        Rows.ShowInvite(self, true)
        if self.entry then Rows.ShowTooltip(self, self.entry, ns.Window.Elapsed()) end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if not self:IsMouseOver() then Rows.ShowInvite(self, false) end
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, mouse)
        local entry = self.entry
        if not entry then return end
        if mouse == "RightButton" then
            ns.Menu.OpenRowMenu(self, entry)
        elseif entry.kind == "GROUP" then
            ns.Detail.Toggle(entry)
        else
            Rows.Whisper(entry)
        end
    end)
    return row
end

-- A player row's Invite shows only while the mouse is over the row (it is
-- in the right-click menu too); the age stays visible.
function Rows.ShowInvite(row, on)
    if not row.invite then return end
    row.invite:SetShown(on and row.invite.leader ~= nil)
end

-- Whisper the leader (or the player): a player row's left click; groups
-- open the detail panel instead. Never marks seen (only "Mark as seen" /
-- the Seen button do).
function Rows.Whisper(entry)
    if type(entry.leader) ~= "string" then return end
    ns.Finder.Whisper(entry.leader)
end

-- The parts of a row that seen / no room / delisted dim: text and icons. The green
-- "room for me" edge, its tint and the selection outline keep full colour.
local function dimmable(row)
    local list = {}
    for _, key in ipairs({ "activity", "leaderName", "levels", "count", "more", "tag", "comment", "age", "strike", "level", "class", "name", "pin",
        "area", "invite" }) do
        if row[key] then list[#list + 1] = row[key] end
    end
    for _, group in ipairs({ row.squares, row.roles, row.chips }) do
        for _, part in ipairs(group or {}) do list[#list + 1] = part end
    end
    return list
end
Rows.Dimmable = dimmable

local function markers(row, entry)
    -- The edge tells rows with room apart; with "Only groups with room for
    -- me" on every row has room, so it says nothing and stays off.
    local open = entry.freeForMe == true and S("markOpenSlot") and entry.kind == "GROUP" and not S("filterMyRole")
    local c = S("openEdgeColor")
    row.edge:SetColorTexture(c[1], c[2], c[3], 1)
    row.open:SetColorTexture(c[1], c[2], c[3], 0.08)
    row.edge:SetShown(open and true or false)
    row.open:SetShown(open and true or false)
    local alpha = 1
    if entry.seen == true then alpha = S("seenAlpha") / 100 end
    -- A group without room for any of my roles dims as a seen one.
    if entry.noRoom == true then alpha = math.min(alpha, S("noRoomAlpha") / 100) end
    if entry.delisted == true then alpha = math.min(alpha, DELISTED_ALPHA) end
    row:SetAlpha(1)
    row.dimmed = alpha
    for _, part in ipairs(dimmable(row)) do part:SetAlpha(alpha) end
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
    -- The players' divider: "Sort: Role" with a menu of the orders.
    row.sort = Controls.Button(row, { text = "", size = "fixed", height = DIVIDER_H - 2, icon = "ChevronDown",
        onClick = function(self) Rows.OpenSortMenu(self) end, tip = function() return L.TIP_PLAYER_SORT end })
    row.sort:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    row.sort:Hide()
    return row
end

function Rows.OpenSortMenu(owner)
    ns.Menu.Open(owner, function(root)
        root:CreateTitle(L.PLAYER_SORT)
        for _, mode in ipairs(ns.Results.PLAYER_SORTS) do
            root:CreateRadio(L["PLAYER_SORT_" .. mode], function(m) return S("playerSort") == m end,
                function(m) Settings.Set("playerSort", m) end, mode)
        end
    end)
end

local function layoutDivider(row, entry, width)
    Controls.Restyle(row.text, { 0.78, 0.59, 0.12 })
    row.text:SetText(entry.text)
    row:SetSize(width, DIVIDER_H)
    row.sort:SetShown(entry.sort == true)
    if entry.sort then
        row.sort:SetLabel(L.PLAYER_SORT_BUTTON:format(L["PLAYER_SORT_" .. S("playerSort")]))
        row.sort:SetWidth(math.floor(row.sort.label:GetStringWidth() + 28))
    end
    return DIVIDER_H
end

-- Groups ---------------------------------------------------------------------------------

local function newSquare(row)
    local sq = CreateFrame("Frame", nil, row)
    sq:SetSize(16, 16)
    sq.fill = sq:CreateTexture(nil, "ARTWORK")
    sq.fill:SetPoint("TOPLEFT", 1, -1)
    sq.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    sq.role = sq:CreateTexture(nil, "OVERLAY")
    sq.role:SetPoint("TOPLEFT", 1, -1)
    sq.role:SetPoint("BOTTOMRIGHT", -1, 1)
    sq.edges = Controls.Outline(sq, { 0, 0, 0, 1 })
    return sq
end
Rows.NewSlot = newSquare

-- One slot: a member's role icon on his class colour, or a free place
-- (dim outline, the wanted role's icon faded).
function Rows.PaintSlot(sq, slot)
    sq.free = slot.free == true
    if slot.role then   -- plain: our own value
        sq.role:SetAtlas(ROLE_ATLAS[slot.role])
        sq.role:SetAlpha(sq.free and FREE_ICON_ALPHA or 1)
        sq.role:Show()
    else
        sq.role:Hide()
    end
    if sq.free then
        -- An empty place: a clear light outline on a faint fill.
        sq.fill:SetColorTexture(1, 1, 1, 0.06)
        sq.fill:Show()
        Controls.PaintOutline(sq.edges, FREE_EDGE)
    else
        local r, g, b = Rows.ClassColor(slot.member and slot.member.classFile)
        sq.fill:SetColorTexture(r, g, b, 0.85)
        sq.fill:Show()
        Controls.PaintOutline(sq.edges, { 0, 0, 0, 1 })
    end
end

local function newGroup(parent)
    local row = newBase(parent)
    row.activity = Controls.Text(row, "activity")
    row.activity.sizeKey = "nameSize"   -- the title no larger than a name
    row.leaderName = Controls.Text(row, "name")
    row.levels = Controls.Text(row, "small")
    row.count = Controls.Text(row, "small")
    row.squares = {}
    for i = 1, MAX_SQUARES do row.squares[i] = newSquare(row) end
    row.more = Controls.Text(row, "small")
    row.tag = Controls.Text(row, "small")
    row.comment = Controls.Text(row, "comment")
    row.selected = Controls.Outline(row, Controls.GOLD, "OVERLAY")
    return row
end

local function layoutSquares(row, entry, x)
    local slots = Rows.Slots(entry)
    local SQUARE = math.min(S("groupRoleIconSize"), S("rowHeight") - 2)
    for i = 1, MAX_SQUARES do
        local sq = row.squares[i]
        sq:SetSize(SQUARE, SQUARE)
        sq:ClearAllPoints()
        sq:SetPoint("LEFT", row, "LEFT", x + (i - 1) * (SQUARE + SQUARE_GAP), 0)
        if slots[i] then
            Rows.PaintSlot(sq, slots[i])
            sq:Show()
        else
            sq:Hide()
        end
    end
    local extra = #slots - MAX_SQUARES
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
    for _, fs in ipairs({ row.activity, row.leaderName, row.levels, row.count, row.more, row.tag, row.comment, row.age }) do
        Controls.Restyle(fs)
    end
    Controls.Color(row.tag, TAG_COLOR)
    local x = EDGE_W + PAD
    -- The activity, unless the list shows only one (then the divider names it).
    local showActivity = not (Rows.singleActivity and type(entry.activityIDs) == "table" and #entry.activityIDs == 1)
    row.activity:SetShown(showActivity)
    row.activity:ClearAllPoints()
    row.activity:SetPoint("LEFT", row, "LEFT", x, 0)
    if showActivity then
        local actW = math.max(80, math.min(150, math.floor(width * 0.22)))
        row.activity:SetWidth(actW)
        row.activity:SetText(Rows.ActivityText(entry.activityIDs))
        x = x + actW + PAD
    end
    -- Leader (class colour), the members' levels, how full.
    local facts = Rows.GroupFacts(entry)
    row.leaderName:ClearAllPoints()
    row.leaderName:SetPoint("LEFT", row, "LEFT", x, 0)
    row.leaderName:SetText(facts.leader or L.UNKNOWN_PLAYER)
    if S("classColorNames") and facts.classFile then row.leaderName:SetTextColor(Rows.ClassColor(facts.classFile)) end
    local nameW = math.min(row.leaderName:GetStringWidth() + 2, LEADER_W)
    row.leaderName:SetWidth(nameW)
    x = x + LEADER_W + PAD
    row.levels:ClearAllPoints()
    row.levels:SetPoint("LEFT", row, "LEFT", x, 0)
    row.levels:SetWidth(LEVELS_W)
    row.levels:SetText(facts.minLevel and (facts.minLevel == facts.maxLevel and tostring(facts.minLevel)
        or L.LEVEL_RANGE:format(facts.minLevel, facts.maxLevel)) or "")
    x = x + LEVELS_W + PAD
    row.count:ClearAllPoints()
    row.count:SetPoint("LEFT", row, "LEFT", x, 0)
    row.count:SetWidth(COUNT_W)
    row.count:SetText(facts.max > 0 and L.MEMBER_COUNT:format(facts.count, facts.max) or tostring(facts.count))
    x = x + COUNT_W + PAD
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
    row.strike:SetPoint("LEFT", row, "LEFT", EDGE_W + PAD, 0)
    row.strike:SetPoint("RIGHT", row, "RIGHT", -AGE_W - PAD, 0)
    row.strike:SetShown(entry.delisted == true)
    local open = ns.Detail and ns.Detail.OpenID()
    Controls.PaintOutline(row.selected, Controls.GOLD)
    for _, t in ipairs(row.selected) do t:SetShown(open ~= nil and open == entry.id) end
    markers(row, entry)
    return h
end

-- Players --------------------------------------------------------------------------------

-- A chip's tooltip: the activity's full name and level range.
function Rows.ShowChipTooltip(chip)
    local info = Activities.Info(chip.activityID)
    GameTooltip:SetOwner(chip, "ANCHOR_RIGHT")
    local name = info and info.name or L.UNKNOWN_ACTIVITY   -- plain: our own cache entry
    GameTooltip:AddLine(name, Controls.GOLD[1], Controls.GOLD[2], Controls.GOLD[3])
    if info and info.minLevel > 0 and info.maxLevel > 0 then
        GameTooltip:AddLine(L.TIP_LEVELS:format(info.minLevel, info.maxLevel), 1, 1, 1)
    end
    GameTooltip:Show()
end

local function newChip(row)
    local chip = CreateFrame("Frame", nil, row)
    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()
    chip.bg:SetColorTexture(Controls.TAG_FILL[1], Controls.TAG_FILL[2], Controls.TAG_FILL[3], Controls.TAG_FILL[4])
    chip.edges = Controls.Outline(chip, S("chipBorderColor"))
    chip.text = Controls.Text(chip, "chip")
    chip.text:SetPoint("CENTER")
    -- Hover only: the full name and levels; clicks go through to the row.
    if chip.SetMouseMotionEnabled then
        chip:SetMouseMotionEnabled(true)
        if chip.SetMouseClickEnabled then chip:SetMouseClickEnabled(false) end
    end
    chip:SetScript("OnEnter", function(self) Rows.ShowChipTooltip(self) end)
    chip:SetScript("OnLeave", function()
        if row:IsMouseOver() and row.entry then
            Rows.ShowTooltip(row, row.entry, ns.Window.Elapsed())
        else
            GameTooltip:Hide()
        end
    end)
    return chip
end

local function newPlayer(parent)
    local row = newBase(parent)
    row.roles = {}
    for i in ipairs(ROLE_ORDER) do row.roles[i] = row:CreateTexture(nil, "ARTWORK") end
    row.level = Controls.Text(row, "level")
    row.level:SetJustifyH("CENTER")
    row.class = row:CreateTexture(nil, "ARTWORK")
    row.name = Controls.Text(row, "name")
    row.pin = row:CreateTexture(nil, "ARTWORK")
    row.pin:SetSize(12, 12)
    row.pin:SetAtlas(PIN_ATLAS)
    row.area = Controls.Text(row, "location")
    row.chips = {}
    row.more = Controls.Text(row, "chip")
    row.comment = Controls.Text(row, "comment")
    row.invite = Controls.Button(row, { text = L.INVITE, width = INVITE_W, size = "row",
        onClick = function(self) if self.leader then ns.Finder.Invite(self.leader) end end })
    row.invite:HookScript("OnLeave", function() if not row:IsMouseOver() then Rows.ShowInvite(row, false) end end)
    row.invite:Hide()
    return row
end

-- The role column's icon size and width for a row height: one role fills
-- the height (or the playerRoleIconSize setting), two or three sit side by
-- side, smaller.
function Rows.RoleColumn(h, n)
    local set = S("playerRoleIconSize")
    local big = set > 0 and set or math.max(12, h - 6)
    local size = n <= 1 and big or (n == 2 and math.floor(big * 0.75) or math.floor(big * 0.6))
    return size, math.floor(big * 1.8)
end

local function layoutRoles(row, entry, x, h)
    local wanted = {}
    for i, key in ipairs(ROLE_ORDER) do
        if type(entry.roles) == "table" and entry.roles[key] == true then wanted[#wanted + 1] = i end
    end
    local size, colW = Rows.RoleColumn(h, #wanted)
    local start = x + math.floor((colW - #wanted * size - (#wanted - 1)) / 2)
    for _, tex in ipairs(row.roles) do tex:Hide() end
    for k, i in ipairs(wanted) do
        local tex = row.roles[i]
        tex:SetAtlas(ROLE_ATLAS[ROLE_OF[ROLE_ORDER[i]]])
        tex:SetSize(size, size)
        tex:ClearAllPoints()
        tex:SetPoint("LEFT", row, "LEFT", start + (k - 1) * (size + 1), 0)
        tex:Show()
    end
    row.shownRoles = #wanted
    return colW
end

-- The activity chips flow over both lines of the right side; "+n" counts
-- the ones that do not fit. Returns where line 2 is free from (nil when the
-- chips use only line 1).
local MORE_W = 24
local function layoutChips(row, entry, x, top, bottom, w)
    local ids = type(entry.activityIDs) == "table" and entry.activityIDs or {}   -- plain: Finder converted the row
    local line, used, shown, used2 = 1, 0, 0, nil
    local border = S("chipBorderColor")
    for i, id in ipairs(ids) do
        local chip = row.chips[i] or newChip(row)
        row.chips[i] = chip
        Controls.Restyle(chip.text)
        Controls.PaintOutline(chip.edges, border)
        chip.activityID = id
        chip.text:SetText(ns.Abbrev.Chip(id))
        local cw = math.floor(chip.text:GetStringWidth() + 10 + 0.5)
        local last = i == #ids
        local room = w - used - (line == 2 and not last and MORE_W or 0)
        if cw > room and used > 0 and line == 1 then
            line, used = 2, 0
            room = w - (not last and MORE_W or 0)
        end
        if cw > room and used > 0 then
            for j = i, #ids do row.chips[j] = row.chips[j] or newChip(row); row.chips[j]:Hide() end
            break
        end
        cw = math.min(cw, w)
        chip.text:SetWidth(cw - 6)
        chip:SetSize(cw, 14)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", row, "TOPLEFT", x + used, line == 1 and top or bottom)
        chip:Show()
        used, shown = used + cw + CHIP_GAP, shown + 1
        if line == 2 then used2 = used end
    end
    for i = #ids + 1, #row.chips do row.chips[i]:Hide() end
    row.more:ClearAllPoints()
    row.more:SetPoint("TOPLEFT", row, "TOPLEFT", x + used, (line == 1 and top or bottom) - 1)
    row.more:SetText(#ids > shown and L.MORE_MEMBERS:format(#ids - shown) or "")
    row.shownChips, row.chipLines = shown, line
    if #ids > shown then used2 = w end
    return used2
end

local function layoutPlayer(row, entry, width, elapsed)
    local h = S("playerRowHeight")
    row:SetSize(width, h)
    for _, fs in ipairs({ row.name, row.level, row.area, row.more, row.comment, row.age }) do Controls.Restyle(fs) end
    local ICON = S("classIconSize")
    row.class:SetSize(ICON, ICON)
    local first = type(entry.members) == "table" and entry.members[1] or {}
    local top, bottom = -3, -math.floor(h / 2) - 1
    -- Role column, the level beside it.
    local x = EDGE_W + PAD
    x = x + layoutRoles(row, entry, x, h)
    row.level:ClearAllPoints()
    row.level:SetPoint("LEFT", row, "LEFT", x, 0)
    row.level:SetWidth(LEVEL_W)
    row.level:SetText(type(first.level) == "number" and tostring(first.level) or "")
    x = x + LEVEL_W + PAD
    -- Name (class icon, class colour) over the location.
    setClassIcon(row.class, first.classFile)
    row.class:ClearAllPoints()
    row.class:SetPoint("TOPLEFT", row, "TOPLEFT", x, top)
    local nx = x + ICON + 4
    row.name:SetText(type(entry.leader) == "string" and entry.leader or L.UNKNOWN_PLAYER)
    local area = type(entry.area) == "string" and entry.area ~= "" and entry.area or L.UNKNOWN_AREA
    row.area:SetText(area)
    -- The name / area column is as wide as they need (measured), at least
    -- PLAYER_LEFT_W and at most 45 % of the row; cut only beyond that.
    local need = math.max(row.name:GetStringWidth(), row.area:GetStringWidth()) + ICON + 4 + 4
    local leftW = math.floor(math.max(PLAYER_LEFT_W, math.min(need, (width - x - AGE_W) * 0.45)))
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", nx, top)
    row.name:SetWidth(leftW - ICON - 4)
    if S("classColorNames") then row.name:SetTextColor(Rows.ClassColor(first.classFile)) end
    row.pin:ClearAllPoints()
    row.pin:SetPoint("TOPLEFT", row, "TOPLEFT", x + 1, bottom)
    row.area:ClearAllPoints()
    row.area:SetPoint("TOPLEFT", row, "TOPLEFT", nx, bottom)
    row.area:SetWidth(leftW - ICON - 4)
    -- Chips over the comment.
    local bx = x + leftW
    local bw = math.max(40, width - bx - AGE_W - 2 * PAD)
    -- The comment after the chips on line 2 while room remains (cut off
    -- with "..."), else only in the tooltip.
    local used2 = layoutChips(row, entry, bx, top, bottom, bw) or 0
    local roomLeft = bw - used2
    row.comment:ClearAllPoints()
    row.comment:SetPoint("TOPLEFT", row, "TOPLEFT", bx + used2, bottom)
    row.comment:SetWidth(math.max(1, roomLeft))
    row.comment:SetText(type(entry.comment) == "string" and entry.comment or "")   -- plain: Finder converted the row
    row.comment:SetShown(roomLeft >= 40)
    row.invite:SetLabel(L.INVITE)    -- every layout pass: the language may have changed
    row.invite.leader = type(entry.leader) == "string" and entry.leader or nil
    row.invite:ClearAllPoints()
    row.invite:SetPoint("RIGHT", row, "RIGHT", -PAD - AGE_W, 0)
    Rows.ShowInvite(row, row:IsMouseOver())
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
