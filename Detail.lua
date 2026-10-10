local ADDON, ns = ...
local L, Settings, Controls, Activities, Rows = ns.L, ns.Settings, ns.Controls, ns.Activities, ns.Rows
local S = Settings.Get

-- The detail panel of a group: docked to the right edge of the window, in
-- its look (header with the activity name, rounded corners, border); its
-- height follows the window. A left click on a group row opens it, the same
-- row again, its X or ESC closes it, another group switches it. It shows the
-- activities with their levels, leader, age, the full comment, flags,
-- friends and guild, every member (Tank, Healer, Damage, then the free
-- places) and the actions: whisper, whisper template, invite, seen, hide,
-- ignore. RESULT_UPDATED and new result sets update it in place.
local Detail = {}
ns.Detail = Detail

local NAME = "ForeverGroupFinderDetail"
local WIDTH, HEADER_H, BUTTON_H = 270, 24, 18
local PAD, GAP = 8, 4
local LINE_H, MEMBER_H, ICON = 16, 18, 14

local p
local current      -- the row shown (a row table of Window.Built())
local height = 0

function Detail.OpenID()
    if current and p and p:IsShown() then return current.id end
    return nil
end

function Detail.Row() return current end
function Detail.Frame() return p end
function Detail.IsShown() return p ~= nil and p:IsShown() end

local function leaderOf(row)
    return type(row.leader) == "string" and row.leader ~= "" and row.leader or nil
end

local function positive(n) return type(n) == "number" and n > 0 end

-- What the panel shows, top to bottom: { kind = "text" | "heading" | "member" | "free", ... }.
function Detail.Lines(row, elapsed)
    local lines = {}
    local function text(t, color, style, wrap)
        lines[#lines + 1] = { kind = "text", text = t, color = color, style = style or "comment", wrap = wrap }
    end
    local function heading(t) lines[#lines + 1] = { kind = "heading", text = t } end
    if row.delisted == true then text(L.DELISTED, Controls.RED, "name") end
    heading(L.DETAIL_ACTIVITIES)
    for _, id in ipairs(type(row.activityIDs) == "table" and row.activityIDs or {}) do   -- plain: Finder converted the row
        local info = Activities.Info(id)
        local name = Activities.Name(id) or L.UNKNOWN_ACTIVITY
        if info and info.minLevel > 0 and info.maxLevel > 0 then
            name = L.DETAIL_ACTIVITY:format(name, L.LEVEL_RANGE:format(info.minLevel, info.maxLevel))
        end
        text(name, Controls.GOLD, "activity")
    end
    text(L.DETAIL_LEADER:format(leaderOf(row) or L.UNKNOWN_PLAYER))
    local age = Controls.Age(type(row.age) == "number" and row.age + (elapsed or 0) or nil)   -- plain: Finder converted the row
    if age then text(L.TIP_AGE:format(age), Controls.DIM, "small") end   -- plain: our own value
    if type(row.comment) == "string" and row.comment ~= "" then
        heading(L.DETAIL_COMMENT)
        text(row.comment, { 1, 1, 1 }, "comment", true)
    end
    if (type(row.voice) == "number" and row.voice > 0) or (type(row.voice) == "string" and row.voice ~= "") then
        text(L.DETAIL_VOICE, Controls.ACCENT, "small")
    end
    if row.newPlayerFriendly == true then text(L.DETAIL_NEW_PLAYERS, Controls.GREEN, "small") end
    if positive(row.friend) or positive(row.guild) then
        text(L.DETAIL_KNOWN:format(positive(row.friend) and row.friend or 0, positive(row.guild) and row.guild or 0),
            { 0.5, 0.82, 1 }, "small")
    end
    local members = type(row.members) == "table" and row.members or {}   -- plain: Finder converted the row
    heading(L.DETAIL_MEMBERS:format(#members))
    for _, slot in ipairs(Rows.Slots(row)) do
        lines[#lines + 1] = slot.free and { kind = "free", role = slot.role } or { kind = "member", member = slot.member, role = slot.role }
    end
    return lines
end

-- Pools ---------------------------------------------------------------------------------------

local function textLine(i)
    local fs = p.texts[i]
    if not fs then
        fs = Controls.Text(p.body.child, "comment")
        p.texts[i] = fs
    end
    return fs
end

local function memberLine(i)
    local m = p.members[i]
    if m then return m end
    m = CreateFrame("Frame", nil, p.body.child)
    m:SetHeight(MEMBER_H)
    m.slot = Rows.NewSlot(m)
    m.slot:SetSize(ICON + 2, ICON + 2)
    m.slot:SetPoint("LEFT", 0, 0)
    m.class = m:CreateTexture(nil, "ARTWORK")
    m.class:SetSize(ICON, ICON)
    m.class:SetPoint("LEFT", m.slot, "RIGHT", 4, 0)
    m.name = Controls.Text(m, "name")
    m.name:SetPoint("LEFT", m.class, "RIGHT", 4, 0)
    m.level = Controls.Text(m, "small")
    m.area = Controls.Text(m, "small")
    m.area:SetJustifyH("RIGHT")
    m.area:SetPoint("RIGHT", m, "RIGHT", 0, 0)
    p.members[i] = m
    return m
end

-- Display ---------------------------------------------------------------------------------------

local function layoutMember(m, line, width)
    Rows.PaintSlot(m.slot, { free = line.kind == "free", role = line.role, member = line.member })
    for _, fs in ipairs({ m.name, m.level, m.area }) do Controls.Restyle(fs) end
    m:SetWidth(width)
    if line.kind == "free" then
        m.class:Hide()
        m.name:SetText(line.role and L.DETAIL_FREE:format(L[Rows.ROLE_LABEL[line.role]]) or L.DETAIL_FREE_ANY)   -- plain: our own value
        Controls.Color(m.name, Controls.DIM)
        m.level:SetText("")
        m.area:SetText("")
        return
    end
    local member = line.member
    Rows.SetClassIcon(m.class, member.classFile)
    m.name:SetText(type(member.name) == "string" and member.name or L.UNKNOWN_PLAYER)   -- plain: Finder converted the member
    m.name:SetTextColor(Rows.ClassColor(member.classFile))
    m.name:SetWidth(math.min(m.name:GetStringWidth(), 110))
    m.level:ClearAllPoints()
    m.level:SetPoint("LEFT", m.name, "RIGHT", 4, 0)
    m.level:SetText(type(member.level) == "number" and tostring(member.level) or "")
    local areaW = width - (ICON + 2 + 4 + ICON + 4) - m.name:GetWidth() - 4 - m.level:GetStringWidth() - 6
    m.area:SetWidth(math.max(10, areaW))
    m.area:SetText(type(member.area) == "string" and member.area or "")
end

local function render()
    local row = current
    local width = WIDTH - 2 * PAD - 4
    local child = p.body.child
    child:SetWidth(width)
    for _, fs in ipairs(p.texts) do fs:Hide() end
    for _, m in ipairs(p.members) do m:Hide() end
    local y, nt, nm = 0, 0, 0
    for _, line in ipairs(Detail.Lines(row, ns.Window.Elapsed())) do
        if line.kind == "member" or line.kind == "free" then
            nm = nm + 1
            local m = memberLine(nm)
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            layoutMember(m, line, width)
            m:Show()
            y = y + MEMBER_H
        else
            nt = nt + 1
            local fs = textLine(nt)
            fs.styleName = line.kind == "heading" and "small" or line.style
            Controls.Restyle(fs, line.kind == "heading" and { 0.78, 0.59, 0.12 } or line.color)
            fs:SetWordWrap(line.wrap and true or false)
            fs:SetWidth(width)
            fs:ClearAllPoints()
            if line.kind == "heading" and y > 0 then y = y + GAP end
            fs:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            fs:SetText(line.text)
            fs:Show()
            y = y + math.max(LINE_H, (line.wrap and fs:GetStringHeight() or 0) + 2)
        end
    end
    p.body:SetContentHeight(y)
end

local function updateButtons()
    local row = current
    local leader = leaderOf(row)
    local canInvite = not (IsInGroup and IsInGroup()) or (UnitIsGroupLeader and UnitIsGroupLeader("player")) or false
    p.whisper:SetOff(leader == nil, L.UNKNOWN_PLAYER)
    p.template:SetOff(leader == nil, L.UNKNOWN_PLAYER)
    p.ignore:SetOff(leader == nil, L.UNKNOWN_PLAYER)
    if leader == nil then
        p.invite:SetOff(true, L.UNKNOWN_PLAYER)
    else
        p.invite:SetOff(not canInvite, L.TIP_INVITE_NOT_LEADER)
    end
    p.seen:SetOn(row.seen == true)
    for _, b in ipairs(p.buttons) do b:SetLabel(L[b.labelKey]) end
end

-- Everything again for the current row (no search).
function Detail.Refresh()
    if not (p and current and p:IsShown()) then return end
    Controls.Restyle(p.header.title)
    p.header.title:SetText(Rows.ActivityText(current.activityIDs))
    Detail.Layout(height)
    updateButtons()
    render()
end

-- The window's height; the panel's buttons and list fit into it.
function Detail.Layout(h)
    height = h or height
    if not p then return end
    p:SetSize(WIDTH, height)
    ns.Window.ApplyLook(p, WIDTH, height)
    Detail.Dock()
    -- Two rows of three inside the panel; a label too long for its button
    -- is cut off with "...", never past the button.
    local bw = math.floor((WIDTH - 2 * PAD - 2 * GAP) / 3)
    for i, b in ipairs(p.buttons) do
        local col, line = (i - 1) % 3, math.floor((i - 1) / 3)
        b:SetWidth(bw)
        b.label:SetWidth(bw - (b.icon and 24 or 8))
        b.layoutX = PAD + col * (bw + GAP)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", b.layoutX, PAD + (1 - line) * (BUTTON_H + GAP))
    end
    p.body.viewHeight = math.max(0, height - HEADER_H - 2 * PAD - 2 * BUTTON_H - 2 * GAP)
end

-- Docked to the window's right edge; to its left edge when the screen has
-- no room on the right.
function Detail.Dock()
    local window = ns.Window.Frame()
    if not (p and window) then return end
    local right = window:GetRight()
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local roomRight = not right or (right + 4 + WIDTH) * scale <= UIParent:GetWidth()
    p.side = roomRight and "RIGHT" or "LEFT"
    p:ClearAllPoints()
    if roomRight then
        p:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, 0)
        p:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", 4, 0)
    else
        p:SetPoint("TOPRIGHT", window, "TOPLEFT", -4, 0)
        p:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", -4, 0)
    end
end

-- Every button's left and right edge inside the panel (for the tests).
function Detail.ButtonExtents()
    local out = {}
    for _, b in ipairs(p and p.buttons or {}) do
        local x = b.layoutX or 0
        out[#out + 1] = { left = x, right = x + b:GetWidth(), width = WIDTH }
    end
    return out
end

-- Actions (clicks) --------------------------------------------------------------------------------

local function seen()
    ns.Memory.MarkSeen(current.key)
    ns.Window.RefreshRows()
    Detail.Refresh()
end

function Detail.Whisper()
    local leader = current and leaderOf(current)
    if not leader then return end
    ns.Finder.Whisper(leader)
    seen()
end

function Detail.Invite()
    local leader = current and leaderOf(current)
    if leader then ns.Finder.Invite(leader) end
end

function Detail.MarkSeen()
    if current then seen() end
end

function Detail.HideGroup()
    if not current then return end
    ns.Memory.Hide(current.key)
    Detail.Close()
    ns.Window.Rebuild()
end

function Detail.Ignore()
    local leader = current and leaderOf(current)
    if not leader then return end
    Detail.Close()
    ns.Memory.SetIgnored(leader, true)
end

-- Building --------------------------------------------------------------------------------------

local function button(labelKey, tipKey, onClick, icon)
    local b = Controls.Button(p, { text = L[labelKey], height = BUTTON_H, icon = icon, onClick = onClick,
        tip = function() return L[tipKey] end })
    b.labelKey = labelKey
    p.buttons[#p.buttons + 1] = b
    return b
end

local function create()
    local window = ns.Window.Frame()
    p = CreateFrame("Frame", NAME, window)
    p:SetFrameStrata("MEDIUM")
    p:EnableMouse(true)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints()
    p.clip = {}
    local h = CreateFrame("Frame", nil, p)
    p.header = h
    h:SetHeight(HEADER_H)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    Controls.HeaderGlow(h)
    h.close = Controls.CloseButton(h, 16, function() Detail.Close() end, function() return L.TIP_CLOSE end)
    h.close:SetPoint("RIGHT", h, "RIGHT", -4, 0)
    h.title = Controls.Text(h, "header")
    h.title:SetPoint("LEFT", h, "LEFT", 10, 0)
    h.title:SetPoint("RIGHT", h.close, "LEFT", -4, 0)
    p.body = Controls.Scroll(p)
    p.body:SetPoint("TOPLEFT", h, "BOTTOMLEFT", PAD, -PAD)
    p.body:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, PAD + 2 * BUTTON_H + 2 * GAP)
    p.texts, p.members, p.buttons = {}, {}, {}
    p.whisper = button("DETAIL_WHISPER", "TIP_DETAIL_WHISPER", function() Detail.Whisper() end)
    p.template = button("DETAIL_TEMPLATE", "TIP_DETAIL_TEMPLATE", function(self)
        local row = current
        if row then ns.Menu.Open(self, function(root) ns.Menu.AddWhisperTemplates(root, row) end) end
    end, "ChevronDown")
    p.invite = button("MENU_INVITE", "TIP_DETAIL_INVITE", function() Detail.Invite() end)
    p.seen = button("DETAIL_SEEN", "TIP_DETAIL_SEEN", function() Detail.MarkSeen() end)
    p.hide = button("MENU_HIDE", "TIP_DETAIL_HIDE", function() Detail.HideGroup() end)
    p.ignore = button("DETAIL_IGNORE", "TIP_DETAIL_IGNORE", function() Detail.Ignore() end)
    p:SetScript("OnHide", function()
        local was = current
        current = nil
        if was then ns.Window.RefreshRows() end
    end)
    p:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, NAME) end
end

-- Public ----------------------------------------------------------------------------------------

function Detail.Open(row)
    if not ns.Window.Frame() then return end
    if not p then create() end
    current = row
    p:Show()
    Detail.Layout(S("height"))
    Detail.Refresh()
    ns.Window.RefreshRows()
end

function Detail.Close()
    if p then p:Hide() end
end

-- The same group again closes the panel; another one switches it.
function Detail.Toggle(row)
    if Detail.OpenID() ~= nil and Detail.OpenID() == row.id then
        Detail.Close()
    else
        Detail.Open(row)
    end
end

-- A new result set: the same group's new row, or the old one as delisted.
function Detail.OnResults()
    local id = Detail.OpenID()
    if id == nil then return end   -- plain: our own value
    local built = ns.Window.Built()
    for _, list in ipairs({ built.groups, built.players }) do
        for _, row in ipairs(list) do
            if row.id == id then
                current = row
                Detail.Refresh()
                return
            end
        end
    end
    current.delisted = true
    Detail.Refresh()
end

-- One result changed (Window updated its row in place).
function Detail.OnUpdated(row)
    if Detail.OpenID() ~= nil and Detail.OpenID() == row.id then
        current = row
        Detail.Refresh()
    end
end
