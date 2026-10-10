-- A mock of the WoW API, just enough for Forever Group Finder. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, timers = {}, fontStrings = {}, popups = {}, registered = {},
            calls = {}, menus = {} }

local function record(name, ...) M.calls[#M.calls + 1] = { name, ... } end
M.record = record

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are widget methods. Everything else is the addon's
    -- own data and must be nil as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name, kind)
    local w = setmetatable({ _name = name, _kind = kind, _scripts = {}, _events = {},
                             _w = 0, _h = 0, _shown = true, _attr = {}, _alpha = 1, _scale = 1 }, widget)
    function w:GetName() return self._name end
    function w:GetObjectType() return self._kind end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end return fn(...) end
    end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:SetTextColor(r, g, b) self._textColor = { r, g, b } end
    function w:GetTextColor() local c = self._textColor or { 1, 1, 1 }; return c[1], c[2], c[3], 1 end
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked end
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:GetSize() return self._w, self._h end
    function w:Hide() self._shown = false end
    function w:Show() self._shown = true end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsVisible()
        local f = self
        while f do
            if not f._shown then return false end
            f = f._parent
        end
        return true
    end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha end
    function w:GetFrameLevel() return self._level or 3 end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    function w:SetEnabled(on) self._enabled = on and true or false end
    function w:IsEnabled() return self._enabled ~= false end
    function w:SetFrameLevel(v) self._level = v end
    function w:SetFrameStrata(s) self._strata = s end
    function w:GetFrameStrata() return self._strata end
    function w:SetScale(v) self._scale = v end
    function w:GetScale() return self._scale or 1 end
    function w:GetEffectiveScale() return self._scale or 1 end
    function w:SetMovable(v) self._movable = v end
    function w:IsMovable() return self._movable end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsMouseOver() return self._mouseOver or false end
    function w:RegisterForDrag(...) self._drag = select("#", ...) > 0 end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:RegisterEvent(e)
        if M.validEvents and not M.validEvents[e] then error("unknown event " .. e) end
        self._events[e] = true
    end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:SetPoint(p, rel, p2, x, y)
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._points = self._points or {}
        self._points[p] = { rel, p2, x, y }
        self._lastPoint = { p, rel, p2, x, y }
    end
    function w:ClearAllPoints() self._points = {} end
    function w:GetNumPoints() local n = 0; for _ in pairs(self._points or {}) do n = n + 1 end; return n end
    function w:GetPoint() local a = self._lastPoint; if a then return a[1], a[2], a[3], a[4], a[5] end end
    -- Screen rectangle: tests set _rect = { left, bottom, width, height }.
    function w:GetCenter()
        if not self._rect then return nil end
        return self._rect[1] + self._rect[3] / 2, self._rect[2] + self._rect[4] / 2
    end
    function w:GetLeft() return self._rect and self._rect[1] end
    function w:GetBottom() return self._rect and self._rect[2] end
    function w:GetRight() return self._rect and (self._rect[1] + self._rect[3]) end
    function w:GetTop() return self._rect and (self._rect[2] + self._rect[4]) end
    function w:SetColorTexture(r, g, b, a) self._texColor = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
    function w:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
    function w:SetTexture(t) self._texture = t end
    function w:GetTexture() return self._texture end
    function w:SetAtlas(a) self._atlas = a end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    function w:AddMaskTexture(m) self._masks = (self._masks or 0) + 1 end
    function w:RemoveMaskTexture(m) self._masks = (self._masks or 1) - 1 end
    function w:CreateMaskTexture() return newWidget(nil, "MaskTexture") end
    function w:CreateTexture(_, layer, _, sublevel)
        local t = newWidget(nil, "Texture")
        t._parent = self
        t._layer, t._sublevel = layer, sublevel
        return t
    end
    function w:StartMoving() self._moving = true end
    function w:StopMovingOrSizing() self._moving = false end
    function w:SetVerticalScroll(v) self._scroll = v end
    function w:GetVerticalScroll() return self._scroll or 0 end
    function w:GetVerticalScrollRange() return 0 end
    function w:SetScrollChild(c) self._child = c end
    function w:CreateFontString(_, _, template)
        local fs = newWidget(nil, "FontString")
        fs._parent = self
        -- As in the game: without a template a font string has no font until
        -- SetFont / SetFontObject, and SetText then raises "Font not set".
        if template then fs._font = { "Fonts\\FRIZQT__.TTF", 12, "" } end
        function fs:SetText(t)
            if not self._font then error("FontString:SetText(): Font not set") end
            self._text = t
        end
        function fs:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
        function fs:GetFont() if self._font then return self._font[1], self._font[2], self._font[3] end end
        function fs:SetFont(p, s, f) self._font = { p, s, f }; return true end
        function fs:SetFontObject() end
        function fs:GetStringWidth() return #(tostring(self._text or "")) * 6 end
        -- Wraps at the set width: one line per (width / 6) characters.
        function fs:GetStringHeight()
            local text = tostring(self._text or "")
            local perLine = (self._w and self._w > 0) and math.max(1, math.floor(self._w / 6)) or math.huge
            local n = math.max(1, math.ceil(#text / perLine))
            if self._maxLines and self._maxLines > 0 then n = math.min(n, self._maxLines) end
            return n * self._font[2]
        end
        function fs:SetMaxLines(n) self._maxLines = n end
        function fs:SetShadowOffset(x, y) self._shadow = { x, y } end
        function fs:GetShadowOffset() return (self._shadow or { 0, 0 })[1], (self._shadow or { 0, 0 })[2] end
        function fs:GetShadowColor() return 0, 0, 0, 1 end
        function fs:GetFontObject() return self._fontObject end
        M.fontStrings[#M.fontStrings + 1] = fs
        return fs
    end
    return w
end
M.newWidget = newWidget

function CreateFrame(kind, name, parent, template)
    local f = newWidget(name, kind)
    f._parent, f._template = parent, template
    M.frames[#M.frames + 1] = f
    if name then M.byName[name] = f; _G[name] = f end
    if template == "SecureActionButtonTemplate" then f._secure = true end
    if template == "CooldownFrameTemplate" then
        function f:SetCooldown(s, d) self._cooldown = { s, d } end
        function f:Clear() self._cooldown = nil end
    end
    return f
end

-- Delivers an event to every frame that registered it, in creation order.
function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local handler = f._events[event] and f:GetScript("OnEvent")
        if handler then handler(f, event, ...) end
    end
end

function M.RunTimers()
    for _ = 1, 5 do
        local list = M.timers
        M.timers = {}
        for _, fn in ipairs(list) do fn() end
        if #M.timers == 0 then return end
    end
end

UIParent = newWidget("UIParent")
UIParent._w, UIParent._h = 1920, 1080
UIParent._rect = { 0, 0, 1920, 1080 }
Minimap = newWidget("Minimap")
Minimap._w, Minimap._h = 260, 260
Minimap._rect = { 1652, 767, 260, 260 }
function Minimap:GetCenter() return 1782, 897 end
GameTooltip = newWidget("GameTooltip")
function GameTooltip:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = { t } end
function GameTooltip:AddDoubleLine(l, r) self._lines = self._lines or {}; self._lines[#self._lines + 1] = { l, r } end
function GameTooltip:SetOwner(o) self._lines = {}; self._owner = o end
function GameTooltip:ClearLines() self._lines = {} end
function GameTooltip:Hide() self._shown = false; self._lines = {} end
function GameTooltip:IsOwned() return true end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m end }
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, a) M.popups[#M.popups + 1] = { which = which, text = StaticPopupDialogs[which].text, arg = a } end
C_Timer = { After = function(_, fn) M.timers[#M.timers + 1] = fn end }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
InterfaceOptions_AddCategory = function(panel) M.registered[#M.registered + 1] = panel.name end
PixelUtil = { GetNearestPixelSize = function(v) return v end, GetPixelToUIUnitFactor = function() return 1 end }
Enum = { UITextureSliceMode = { Stretched = 1 }, SpellBookSpellBank = { Player = 0 } }

M.locale = "enUS"
function GetLocale() return M.locale end
M.build = { "1.60.1", "70205", "Oct 2 2026", 16001 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
M.state = { combat = false, money = 500, instance = nil, zone = "Stranglethorn Vale", ctrl = false, modified = {} }
function InCombatLockdown() return M.state.combat end
function IsControlKeyDown() return M.state.ctrl end
function IsModifiedClick(what) return M.state.modified[what] or false end
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
-- state.group: a home party; state.instanceGroup: a finder group.
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_HOME then return M.state.group or false end
    if category == LE_PARTY_CATEGORY_INSTANCE then return M.state.instanceGroup or false end
    return (M.state.group or M.state.instanceGroup) and true or false
end
M.sent = {}
function SendChatMessage(msg, channel) M.sent[#M.sent + 1] = { msg = msg, channel = channel, via = "global" } end
function GetMoney() return M.state.money end
function GetMoneyString(v) return v .. "c" end
function GetRealZoneText() return M.state.zone end
function IsMouseButtonDown() return M.state.mouseDown ~= false end
function GetCursorPosition() return M.state.cursorX or 0, M.state.cursorY or 0 end
function IsInInstance()
    if M.state.instance then return true, M.state.instance.kind end
    return false, "none"
end
function GetInstanceInfo() return M.state.instance and M.state.instance.name or "" end


-- Secret values ---------------------------------------------------------------
-- In combat the client hands addons "secret" names, GUIDs and amounts. Tainted
-- code may display them (SetText, string.format %s/%.Nf, AbbreviateLargeNumbers)
-- but must not compare, compute with, concatenate, index or %d-format them.
-- A secret here is a userdata (newproxy) sharing one metatable whose every
-- operator raises; the wrapped value lives in a weak side table. Mixed-type
-- comparisons (secret < 5) and arithmetic raise natively in Lua 5.1; the
-- metamethods catch secret-vs-secret and the rest.
local secretRaw = setmetatable({}, { __mode = "k" })
local secretProto = newproxy(true)
local secretMeta = getmetatable(secretProto)
local function forbid(what) return function() error("secret value: " .. what .. " is not allowed", 2) end end
for _, op in ipairs({ "lt", "le", "eq", "add", "sub", "mul", "div", "mod", "pow", "unm", "concat", "len",
    "index", "newindex", "call" }) do
    secretMeta["__" .. op] = forbid(op)
end
secretMeta.__tostring = function(u) return "<secret " .. tostring(secretRaw[u]) .. ">" end

function M.Secret(v)
    local u = newproxy(secretProto)
    secretRaw[u] = { v }
    return u
end
function M.IsSecret(v) return type(v) == "userdata" and secretRaw[v] ~= nil end
-- The plain value behind a secret (tests only; the addon never can).
function M.Reveal(v)
    if M.IsSecret(v) then return secretRaw[v][1] end
    return v
end
issecretvalue = M.IsSecret

-- Secrets may never become table keys (the client raises). Lua cannot trap a
-- key assignment, so tests walk everything the addon keeps and returns.
function M.FindSecretKey(root)
    local seen = {}
    local function walk(t, path)
        if seen[t] then return nil end
        seen[t] = true
        for k, v in pairs(t) do
            if M.IsSecret(k) then return path .. "[<secret>]" end
            if type(v) == "table" then
                local hit = walk(v, path .. "." .. tostring(k))
                if hit then return hit end
            end
        end
    end
    return walk(root, "root")
end

-- string.format as the client does it: a secret argument is fine for %s and
-- %f (with a precision), anything else raises; the result is itself secret.
local plainFormat = string.format
string.format = function(fmt, ...)
    local args, n, anySecret = { ... }, select("#", ...), false
    for i = 1, n do if M.IsSecret(args[i]) then anySecret = true end end
    if not anySecret then return plainFormat(fmt, ...) end
    if M.IsSecret(fmt) then error("secret value used as a format string", 2) end
    local i, pos = 0, 1
    while true do
        local s, e, spec, conv = fmt:find("%%([-+ #0]*%d*%.?%d*)(%a)", pos)
        local pct = fmt:find("%%%%", pos)
        if pct and (not s or pct < s) then
            pos = pct + 2
        elseif not s then
            break
        else
            i = i + 1
            if M.IsSecret(args[i]) then
                local ok = conv == "s" or (conv == "f" and spec:find("%.%d") ~= nil)
                if not ok then error("secret value with %" .. spec .. conv .. " in string.format", 2) end
                args[i] = secretRaw[args[i]][1]
            end
            pos = e + 1
        end
    end
    return M.Secret(plainFormat(fmt, unpack(args, 1, n)))
end

-- Simplified client abbreviation; accepts secrets and then returns a secret.
function AbbreviateLargeNumbers(v)
    if M.IsSecret(v) then return M.Secret(AbbreviateLargeNumbers(secretRaw[v][1])) end
    if v >= 1e6 then return plainFormat("%.1fM", v / 1e6) end
    if v >= 1e4 then return plainFormat("%.0fK", v / 1e3) end
    return plainFormat("%.0f", v)
end

M.state.playerGUID = "Player-1-0001"
function UnitGUID(unit) if unit == "player" then return M.state.playerGUID end end

-- Status bars, placement ----------------------------------------------------------
local baseNew = newWidget
newWidget = function(name, kind)
    local w = baseNew(name, kind)
    function w:SetStatusBarTexture(t) self._barTexture = t end
    function w:GetStatusBarTexture() return self._barTexture end
    function w:SetStatusBarColor(r, g, b, a) self._barColor = { r, g, b, a } end
    function w:GetStatusBarColor() local c = self._barColor or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    function w:SetUserPlaced(v) self._userPlaced = v end
    function w:IsUserPlaced() return self._userPlaced or false end
    function w:SetDontSavePosition(v) self._dontSave = v end
    function w:SetAllPoints(rel) self._allPoints = rel or true end
    return w
end
M.newWidget = newWidget

RAID_CLASS_COLORS = {
    MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 }, PRIEST = { r = 1, g = 1, b = 1 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
}

-- MenuUtil (modern client menus): every generated menu is recorded in
-- M.menus as a tree of descriptions; tests find an entry by its text and
-- call it as the client would.
local function newMenu()
    local d = { items = {} }
    local function add(kind, text, isSelected, onSelect, data)
        local c = newMenu()
        c.kind, c.text, c.isSelected, c.onSelect, c.data = kind, text, isSelected, onSelect, data
        d.items[#d.items + 1] = c
        return c
    end
    function d:CreateTitle(t) return add("title", t) end
    function d:CreateDivider() return add("divider") end
    function d:CreateButton(t, fn, data) return add("button", t, nil, fn, data) end
    function d:CreateRadio(t, isSel, setSel, data) return add("radio", t, isSel, setSel, data) end
    function d:CreateCheckbox(t, isSel, setSel, data) return add("checkbox", t, isSel, setSel, data) end
    function d:SetScrollMode() end
    function d:SetEnabled(v) self.enabled = v end
    function d:SetTooltip(fn) self.tooltip = fn end
    return d
end
MenuUtil = {
    CreateContextMenu = function(owner, generator)
        local root = newMenu()
        root.owner = owner
        generator(owner, root)
        M.menus[#M.menus + 1] = root
        return root
    end,
}
function M.LastMenu() return M.menus[#M.menus] end
-- Depth first: the first entry whose text is `text`.
function M.MenuFind(root, text)
    for _, item in ipairs(root and root.items or {}) do
        if item.text == text then return item end
        local hit = M.MenuFind(item, text)
        if hit then return hit end
    end
end
function M.MenuClick(item) return item.onSelect(item.data) end
function M.MenuTexts(root)
    local t = {}
    for _, item in ipairs(root and root.items or {}) do t[#t + 1] = tostring(item.text or "-") end
    return table.concat(t, ",")
end


-- Clock ------------------------------------------------------------------------
M.state.time = 1000
function GetTime() return M.state.time end

-- C_LFGList -----------------------------------------------------------------------
-- M.lfg is what the "server" holds; tests fill it. M.lfg.hardware is the
-- hardware-event flag: Search / CreateListing / UpdateListing without it do
-- nothing and are recorded in M.lfg.blocked (the client prints "Interface
-- action failed"). M.lfg.secret makes every info getter hand out secrets.
M.lfg = {}
function M.lfg.reset()
    local l = M.lfg
    l.blocked, l.searches, l.creates, l.updates, l.removed, l.roles = {}, {}, {}, {}, 0, nil
    l.hardware, l.secret, l.results, l.members, l.counts, l.active = false, false, {}, {}, {}, nil
    l.authenticated, l.canUse, l.failure, l.createOK = {}, true, nil, true
    l.cats, l.catNames, l.activities, l.groups, l.level = {}, {}, {}, {}, 60
end
M.lfg.reset()
-- Runs fn as a click handler would: with a hardware event.
function M.lfg.click(fn, ...)
    M.lfg.hardware = true
    local r = { pcall(fn, ...) }
    M.lfg.hardware = false
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2)
end
local function wrap(v)
    if M.lfg.secret and v ~= nil and type(v) ~= "table" then return M.Secret(v) end
    return v
end
local function wrapAll(t)
    if not t then return nil end
    local out = {}
    for k, v in pairs(t) do out[k] = wrap(v) end
    return out
end
local function gated(kind)
    if not M.lfg.hardware then
        M.lfg.blocked[#M.lfg.blocked + 1] = kind
        return false
    end
    return true
end
C_LFGList = {
    Search = function(...)
        if not gated("Search") then return end
        M.lfg.searches[#M.lfg.searches + 1] = { n = select("#", ...), ... }
    end,
    GetSearchResults = function()
        local ids = {}
        for id in pairs(M.lfg.results) do ids[#ids + 1] = id end
        table.sort(ids)
        return #ids, ids
    end,
    HasSearchResultInfo = function(id) return M.lfg.results[id] ~= nil end,
    GetSearchResultInfo = function(id) return wrapAll(M.lfg.results[id]) end,
    GetSearchResultPlayerInfo = function(id, i)
        local list = M.lfg.members[id]
        local m = list and list[i]
        if not m then return nil end
        local out = wrapAll(m)
        if m.lfgRoles then out.lfgRoles = wrapAll(m.lfgRoles) end
        return out
    end,
    GetSearchResultMemberCounts = function(id) return wrapAll(M.lfg.counts[id]) end,
    HasActiveEntryInfo = function() return M.lfg.active ~= nil end,
    GetActiveEntryInfo = function()
        local a = M.lfg.active
        if not a then return nil end
        local out = wrapAll(a)
        out.activityIDs = a.activityIDs   -- NeverSecret
        return out
    end,
    CreateListing = function(data)
        if not gated("CreateListing") then return false end
        M.lfg.creates[#M.lfg.creates + 1] = data
        if M.lfg.createOK then
            M.lfg.active = { activityIDs = data.activityIDs, comment = "", duration = 3600,
                newPlayerFriendly = data.newPlayerFriendly, voiceMode = data.voiceMode }
        end
        return M.lfg.createOK
    end,
    UpdateListing = function(data)
        if not gated("UpdateListing") then return false end
        M.lfg.updates[#M.lfg.updates + 1] = data
        return true
    end,
    RemoveListing = function() M.lfg.removed = M.lfg.removed + 1; M.lfg.active = nil end,
    IsPlayerAuthenticatedForLFG = function(cat) return M.lfg.authenticated[cat] or false end,
}
-- Activity data the "server" offers: tests fill M.lfg.cats (ids), M.lfg.catNames[id],
-- M.lfg.activities[id] = { categoryID, groupFinderActivityGroupID, fullName, shortName, minLevelSuggestion,
-- maxLevelSuggestion, maxNumPlayers }, M.lfg.groups[id] = { name, order }.
M.lfg.cats, M.lfg.catNames, M.lfg.activities, M.lfg.groups, M.lfg.level = {}, {}, {}, {}, 60
function UnitLevel() return M.lfg.level end
C_LFGList.GetAvailableCategories = function() return wrapAll(M.lfg.cats) end
C_LFGList.GetLfgCategoryInfo = function(id)
    local n = M.lfg.catNames[id]
    if n == nil then return nil end
    return wrapAll({ name = n })
end
C_LFGList.GetAvailableActivityGroups = function(cat)
    local seen, out = {}, {}
    for id, a in pairs(M.lfg.activities) do
        local g = a.groupFinderActivityGroupID
        if a.categoryID == cat and g and not seen[g] then seen[g] = true; out[#out + 1] = g end
    end
    table.sort(out)
    return out
end
C_LFGList.GetActivityGroupInfo = function(g)
    local x = M.lfg.groups[g]
    if not x then return nil end
    return wrap(x.name), wrap(x.order)
end
C_LFGList.GetAvailableActivities = function(cat, group)
    local out = {}
    for id, a in pairs(M.lfg.activities) do
        if a.categoryID == cat and (not group or group == 0 or a.groupFinderActivityGroupID == group) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end
C_LFGList.GetActivityInfoTable = function(id) return wrapAll(M.lfg.activities[id]) end

C_LFGListRoles = { SetRoles = function(roles) M.lfg.roles = roles; return true end }
C_LFGInfo = { CanPlayerUsePremadeGroup = function() return M.lfg.canUse, M.lfg.failure end }
M.invited, M.tells = {}, {}
C_PartyInfo = { InviteUnit = function(name) M.invited[#M.invited + 1] = name end }
ChatFrameUtil = {
    SendTell = function(name) M.tells[#M.tells + 1] = { name = name } end,
    SendTellWithMessage = function(name, text) M.tells[#M.tells + 1] = { name = name, text = text } end,
}

return M
