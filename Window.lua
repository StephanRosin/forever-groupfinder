local ADDON, ns = ...
local L, Settings, Media, Controls = ns.L, ns.Settings, ns.Media, ns.Controls
local Finder, Activities, Results, Rows, Layouts = ns.Finder, ns.Activities, ns.Results, ns.Rows, ns.Layouts
local S = Settings.Get

-- The finder's main window: the FOREVER header (gold glow, line, title,
-- refresh with the list's age, lock, close) and its parts: the activity
-- list (Side.lua), my listing (ListingPanel.lua), the filter chips, the
-- result list (Rows.lua: groups first, players below), the group details
-- (Detail.lua) and the leader column (Column.lua). Layouts.lua places the
-- parts for the chosen layout; this file builds them once and fills them.
--
-- Searching: C_LFGList.Search works only from a click or a key press. So
-- Window.Search is called from OnClick handlers and from the open-by-click
-- path (Toggle / Show) only, never from OnUpdate, timers or events. The
-- throttle lives in Finder; a dropped search just leaves the age showing.
local Window = {}
ns.Window = Window

local NAME = "ForeverGroupFinderWindow"
local HEADER_H, BUTTON, ICON = 24, 16, 12
local PAD = 8
local FILTER_H = 18
Window.FILTER_H = FILTER_H
local TICK = 1           -- seconds between two clock updates (ages, remaining time)
local LANGUAGES = {      -- the language filter, each in its own name
    { code = "enUS", label = "English" }, { code = "deDE", label = "Deutsch" },
    { code = "esES", label = "Español" }, { code = "frFR", label = "Français" },
    { code = "itIT", label = "Italiano" }, { code = "ptBR", label = "Português" },
}
Window.LANGUAGES = LANGUAGES

local f
local checked = {}         -- activity id -> true: the search and my listing
local results = {}         -- Finder.Results() of the last full result set
local built = { groups = {}, players = {} }
local receivedAt = nil     -- GetTime() of the last full result set
local status = "idle"      -- idle, searching, failed, unavailable
local filterText = ""
local receivedQuery = nil  -- Finder.QueryKey of the results on screen

-- Checked activities ----------------------------------------------------------------------

function Window.Checked() return checked end

function Window.CheckedList()
    local list = {}
    for id in pairs(checked) do list[#list + 1] = id end
    table.sort(list)
    return list
end

function Window.SetChecked(id, on)
    checked[id] = on and true or nil
end

function Window.SetCheckedList(ids)
    checked = {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do checked[id] = true end
end

-- A new category starts empty, except for my listing's activities in it.
function Window.ResetChecked()
    checked = {}
    local entry = Finder.ActiveEntry()
    local inCategory = {}
    for _, id in ipairs(Finder.Activities(S("category"))) do inCategory[id] = true end
    for _, id in ipairs(entry and entry.activityIDs or {}) do   -- plain: Finder converted the entry
        if inCategory[id] then checked[id] = true end
    end
end

function Window.Elapsed()
    if not receivedAt then return 0 end
    return GetTime() - receivedAt
end

function Window.Frame() return f end
function Window.Built() return built end
function Window.Status() return status end

-- Searching --------------------------------------------------------------------------------

local function languageSet()
    local set = {}
    for _, code in ipairs(S("languages")) do set[code] = true end
    return set
end

function Window.Query()
    return { categoryID = S("category"), activityIDs = Window.CheckedList(), languages = languageSet() }
end

-- The list does not show results for the current selection: the search
-- for it was dropped (interval, one in flight) or results came back for an
-- older query. The refresh button glows; the next click that may search
-- runs the current query.
function Window.Outdated()
    local current = Finder.QueryKey(Window.Query())
    if Finder.IsSearching() then return Finder.LastQuery() ~= current end
    return receivedQuery ~= current
end

-- Click or key press only. Returns Finder.Search's ok, reason. The list is
-- filtered to the checked activities at once, searched or not.
function Window.Search()
    Window.Rebuild()
    local canUse = Finder.CanUse()
    if not canUse then
        status = "unavailable"
        Window.RenderList()
        return false, "unavailable"
    end
    local ok, reason = Finder.Search(Window.Query())
    if ok then status = "searching" end
    Window.UpdateHeader()
    Window.RenderList()
    return ok, reason
end

-- A search Blizzard's own finder issues in this click (its "find a group"
-- handler): no second search; its results arrive as ours do.
function Window.AdoptSearch()
    Finder.ExpectSearch()
    status = "searching"
    Window.UpdateHeader()
    Window.RenderList()
end

-- Results ----------------------------------------------------------------------------------

local function context(withFilters)
    local level = UnitLevel("player")
    local activities = {}
    for id in pairs(checked) do activities[id] = true end
    return {
        filters = withFilters and { myRole = S("filterMyRole"), levelFits = S("filterLevelFits"),
            hideSeen = S("hideSeen"), text = filterText, activities = activities, categoryID = S("category") } or {},
        activityCategory = function(id)
            local info = Activities.Info(id)
            return info and info.categoryID or nil
        end,
        activityFit = function(id)
            local info = Activities.Info(id)
            return info and Activities.Fit(info, level) or nil
        end,
    }
end

-- Sorted and filtered anew from the last full result set (a filter changed).
function Window.Rebuild()
    built = Results.Build(results, context(true))
    Window.RenderList()
    ns.Column.Refresh()   -- the leader's fitting players come from the list
end

local function onResults()
    results = Finder.Results()
    receivedAt = GetTime()
    receivedQuery = Finder.LastQuery()
    status = "idle"
    -- A hidden window builds its rows when it opens (Show -> Refresh).
    if Window.IsShown() then
        Window.Rebuild()
        Window.UpdateHeader()
        ns.Detail.OnResults()
    end
end

-- One result changed (full, delisted, a new comment): its row is updated
-- where it is; the order changes with the next full result set only.
local function onResultUpdated(id)
    if type(id) ~= "number" then return end
    for _, list in ipairs({ built.groups, built.players }) do
        for _, row in ipairs(list) do
            if row.id == id then
                local fresh = Finder.Result(id)
                local new
                if fresh then
                    local b = Results.Build({ fresh }, context(false))
                    new = b.groups[1] or b.players[1]
                end
                if new then
                    for k in pairs(row) do row[k] = nil end
                    for k, v in pairs(new) do row[k] = v end
                else
                    row.delisted = true
                end
                Window.RelayoutRow(row)
                ns.Detail.OnUpdated(row)
                return
            end
        end
    end
end

-- The list -----------------------------------------------------------------------------------

-- The list's inner width in the current layout (Layouts.Arrange sets it).
local function listWidth()
    return f and f.listWidth or 0
end

local function emptyText()
    if status == "unavailable" then return L.MSG_CANNOT_USE end
    if status == "failed" then return L.MSG_SEARCH_FAILED end
    if status == "searching" then return L.SEARCHING end
    if not receivedAt then return L.HINT_START end
    return L.NO_RESULTS
end

function Window.RenderList()
    if not f then return end
    local pool, child = f.pool, f.list.child
    pool:ReleaseAll()
    local width = listWidth()
    child:SetWidth(width)
    local y = 0
    local elapsed = Window.Elapsed()
    local function place(kind, entry)
        local row = pool:Acquire(kind)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        y = y + Rows.Layout(row, entry, width, elapsed)
    end
    local total = #built.groups + #built.players
    if total > 0 then
        place("DIVIDER", { text = L.DIVIDER_GROUPS:format(#built.groups) })
        for _, row in ipairs(built.groups) do place("GROUP", row) end
        if S("showPlayers") then
            place("DIVIDER", { text = L.DIVIDER_PLAYERS:format(#built.players) })
            for _, row in ipairs(built.players) do place("PLAYER", row) end
        end
    end
    f.list.empty:SetText(total > 0 and "" or emptyText())
    f.list.empty:SetShown(total == 0)
    f.list:SetContentHeight(y)
end

-- Lays one row out again where it is (its height does not change).
function Window.RelayoutRow(entry)
    if not f then return end
    for _, row in ipairs(f.pool.used) do
        if row.entry == entry then
            Rows.Layout(row, entry, listWidth(), Window.Elapsed())
            return row
        end
    end
end

-- Seen marks changed: dim the rows in place, no new order.
function Window.RefreshRows()
    for _, list in ipairs({ built.groups, built.players }) do
        for _, row in ipairs(list) do row.seen = ns.Memory.IsSeen(row.key) end
    end
    if not f then return end
    local width, elapsed = listWidth(), Window.Elapsed()
    for _, row in ipairs(f.pool.used) do
        if row.entry then Rows.Layout(row, row.entry, width, elapsed) end
    end
end

-- Filters ------------------------------------------------------------------------------------

-- "Only groups with room for me" (filterMyRole) sits with my roles in
-- ListingPanel.lua.
local FILTER_KEYS = { "filterLevelFits", "hideSeen" }

-- A filter chip: toggles its setting and searches (a user action).
function Window.ToggleFilter(key)
    Settings.Set(key, not S(key))
    Window.Search()
end

function Window.SetTextFilter(text)
    filterText = type(text) == "string" and text or ""
    Window.Rebuild()
end

function Window.ToggleLanguage(code)
    local list, found = {}, false
    for _, c in ipairs(S("languages")) do
        if c == code then found = true else list[#list + 1] = c end
    end
    if not found then list[#list + 1] = code end
    Settings.Set("languages", list)
    Window.Search()
end

local function openLanguageMenu(owner)
    ns.Menu.Open(owner, function(root)
        root:CreateTitle(L.FILTER_LANGUAGE)
        for _, lang in ipairs(LANGUAGES) do
            root:CreateCheckbox(lang.label, function(code) return languageSet()[code] == true end,
                function(code) Window.ToggleLanguage(code) end, lang.code)
        end
    end)
end

function Window.LayoutFilters()
    local bar = f.filters
    local chips = bar.chips
    chips.filterLevelFits:SetLabel(L.FILTER_LEVEL_FITS)
    chips.hideSeen:SetLabel(L.FILTER_HIDE_SEEN)
    local n = #S("languages")
    chips.language:SetLabel(n > 0 and L.FILTER_LANGUAGE_N:format(n) or L.FILTER_LANGUAGE)
    local x = 0
    local order = { chips.filterLevelFits, bar.text, chips.hideSeen, chips.language }
    for _, c in ipairs(order) do
        c:ClearAllPoints()
        c:SetPoint("LEFT", bar, "LEFT", x, 0)
        local w = c == bar.text and 110 or c:Fit()
        x = x + w + 4
    end
    for _, key in ipairs(FILTER_KEYS) do chips[key]:SetOn(S(key)) end
    chips.language:SetOn(n > 0)
end

local function createFilters(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(FILTER_H)
    bar.chips = {}
    for _, key in ipairs(FILTER_KEYS) do
        bar.chips[key] = Controls.Chip(bar, { text = "", onClick = function() Window.ToggleFilter(key) end,
            tip = function() return L["TIP_" .. key:upper()] end })
    end
    bar.chips.language = Controls.Chip(bar, { text = "", icon = "ChevronDown",
        onClick = function(self) openLanguageMenu(self) end, tip = function() return L.TIP_LANGUAGES end })
    bar.text = Controls.EditBox(bar, L.FILTER_TEXT, 40)
    bar.text:SetWidth(110)
    bar.text:SetHeight(16)
    bar.text:HookScript("OnTextChanged", function(self) Window.SetTextFilter(self:GetText()) end)
    bar.text:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Window.Search()
    end)
    return bar
end

-- Header ---------------------------------------------------------------------------------------

function Window.UpdateHeader()
    if not f then return end
    local h = f.header
    local label
    if Finder.IsSearching() then
        label = L.SEARCHING
    else
        local age = Controls.Age(Finder.LastSearchAge())
        label = age and L.REFRESH_AGE:format(age) or L.REFRESH   -- plain: our formatted text
    end
    h.refresh:SetLabel(label)
    h.refresh:SetWidth(math.max(70, math.floor(h.refresh.label:GetStringWidth() + 30)))
    local outdated = receivedAt ~= nil and Window.Outdated()
    h.refresh.outdated = outdated
    h.refresh:SetOn(outdated)
    h.refresh.glow:SetShown(outdated)
    local locked = S("locked")
    h.lock.icon:SetTexture(Media.Icon(locked and "Lock" or "Unlock"))
    h.grip:SetShown(not locked)
    h.title:ClearAllPoints()
    h.title:SetPoint("LEFT", h, "LEFT", locked and 10 or 24, 0)
end

local function savePosition()
    local x, y = ns.Position.Read(f, "TOP")
    if x then Settings.SetMany({ point = "TOP", relPoint = "TOP", x = x, y = y }) end
end

local function createHeader()
    local h = CreateFrame("Button", nil, f)
    f.header = h
    h:SetHeight(HEADER_H)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:EnableMouse(true)
    -- The quest log's gold glow and line.
    Controls.HeaderGlow(h)
    h.grip = h:CreateTexture(nil, "OVERLAY")
    h.grip:SetSize(12, 12)
    h.grip:SetPoint("LEFT", 8, 0)
    h.grip:SetTexture(Media.Icon("Grip"))
    h.grip:SetVertexColor(Controls.ACCENT[1], Controls.ACCENT[2], Controls.ACCENT[3])
    h.title = Controls.Text(h, "header")
    h.title:SetText(L.WINDOW_TITLE)
    h.close = Controls.CloseButton(h, BUTTON, function() Window.Hide() end, function() return L.TIP_CLOSE end)
    h.close:SetPoint("RIGHT", h, "RIGHT", -4, 0)
    h.lock = Controls.IconButton(h, "Lock", BUTTON, function() ns.ToggleLock() end,
        function() return S("locked") and L.TIP_UNLOCK_WINDOW or L.TIP_LOCK_WINDOW end)
    h.lock:SetPoint("RIGHT", h.close, "LEFT", -1, 0)
    h.refresh = Controls.Button(h, { text = L.REFRESH, width = 80, height = 16, icon = "Reset",
        onClick = function() Window.Search() end,
        tip = function(self) return self.outdated and L.TIP_OUTDATED or L.TIP_REFRESH end })
    -- The outdated mark: a gold glow behind the button, pulsing.
    h.refresh.glow = h.refresh:CreateTexture(nil, "BACKGROUND", nil, -1)
    h.refresh.glow:SetPoint("TOPLEFT", -3, 3)
    h.refresh.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    h.refresh.glow:SetColorTexture(1, 0.79, 0.19, 0.5)
    h.refresh.glow:Hide()
    h.refresh:SetPoint("RIGHT", h.lock, "LEFT", -4, 0)
    h:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" and not S("locked") then
            f:StartMoving()
            f.moving = true
        end
    end)
    h:SetScript("OnMouseUp", function()
        if not f.moving then return end
        f:StopMovingOrSizing()
        f.moving = nil
        if f.SetUserPlaced then f:SetUserPlaced(false) end
        savePosition()
    end)
end

local resizeSpec   -- below with moving and resizing; layout() sets its ranges

-- Look and layout --------------------------------------------------------------------------------

-- x / y are UIParent units: the frame's own offsets are scaled.
local function place(point, relPoint, x, y)
    local scale = S("scale") / 100
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint(point, UIParent, relPoint, x / scale, y / scale)
end

-- The window's look on a frame with .bg, .clip and a header glow (the
-- detail panel wears it too).
function Window.ApplyLook(frame, width, height)
    Media.ApplyBackground(frame.bg, S("bgMode"), S("bgColor"), S("bgAlpha") / 100, S("bgTexture"))
    local radius = ns.Corners.Clamp(S("cornerRadius"), width, height)
    ns.Corners.Fit(frame.clip, frame, radius, { frame.bg, frame.header.shine })
    ns.Border.Draw(frame, frame, {
        style = S("borderStyle"), size = S("borderSize"), color = S("borderColor"), radius = radius,
        shadow = S("shadowEnabled"), shadowSize = S("shadowSize"), shadowAlpha = S("shadowAlpha") / 100,
    })
end

-- Places the parts for the current layout (the listing's height changes).
function Window.Arrange()
    if not f then return end
    Layouts.Arrange(f, f.layoutWidth or Layouts.Width(), f.layoutHeight or Layouts.Height(), HEADER_H)
end

local function layout(width, height)
    f.layoutWidth, f.layoutHeight = width, height
    f:SetSize(width, height)
    Controls.Restyle(f.header.title)
    f.header.title:SetText(L.WINDOW_TITLE)
    f.filters.text.hint:SetText(L.FILTER_TEXT)
    for _, grip in pairs(f.grips) do grip:SetShown(not S("locked")) end
    Window.ApplyLook(f, width, height)
    resizeSpec.widthRange, resizeSpec.heightRange = Layouts.Ranges()
    local mode = Layouts.Current()
    local switched = f.mode ~= nil and f.mode ~= mode
    if switched then Layouts.ClosePopup(f) end
    f.mode = mode
    ns.Detail.Layout(height)
    Window.UpdateHeader()
    Window.Arrange()
    if switched then ns.Detail.Rehost() end
end

-- Everything again from the settings (no search).
function Window.Refresh()
    if not f then return end
    place(S("point"), S("relPoint"), S("x"), S("y"))
    layout(Layouts.Width(), Layouts.Height())
    ns.Side.Refresh()
    ns.ListingPanel.Refresh()
    Window.Rebuild()
    ns.Detail.Refresh()
end

-- Called when the checked activities or my listing changed.
function Window.ListingChanged()
    ns.ListingPanel.Refresh()
    Window.Arrange()
end

-- The clock: ages, the remaining time and the expiry warning. Never searches.
function Window.Tick()
    if not f then return end
    Window.UpdateHeader()
    ns.Listing.Tick()
    ns.ListingPanel.UpdateClock()
    local elapsed = Window.Elapsed()
    for _, row in ipairs(f.pool.used) do
        if row.entry then Rows.SetAge(row, row.entry, elapsed) end
    end
end

-- Moving and resizing (the size settings are the layout's) ------------------------------

resizeSpec = {
    locked = function() return S("locked") end,
    width = function() return Layouts.Width() end,
    height = function() return Layouts.Height() end,
    widthRange = Settings.RANGES.width,
    heightRange = Settings.RANGES.height,
    live = function(_, r)
        place("TOP", "TOP", r.x * r.scale, r.y * r.scale)
        layout(r.width, r.height)
        Window.RenderList()
    end,
    commit = function(_, r)
        local wKey, hKey = Layouts.SizeKeys()
        Settings.SetMany({ [wKey] = r.width, [hKey] = r.height, point = "TOP", relPoint = "TOP",
            x = math.floor(r.x * r.scale + 0.5), y = math.floor(r.y * r.scale + 0.5) })
    end,
    done = function() Window.Refresh() end,
}

-- Building ---------------------------------------------------------------------------------------------

local function create()
    f = CreateFrame("Frame", NAME, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.clip = {}
    createHeader()
    -- The parts, all children of the window; Layouts.lua places them.
    f.side = ns.Side.Create(f)
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetWidth(1)
    f.divider:SetColorTexture(0.16, 0.16, 0.16, 1)
    f.columnLine = f:CreateTexture(nil, "ARTWORK")
    f.columnLine:SetWidth(1)
    f.columnLine:SetColorTexture(0.16, 0.16, 0.16, 1)
    f.listing = ns.ListingPanel.Create(f)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    f.rule:SetColorTexture(0.16, 0.16, 0.16, 1)
    f.filters = createFilters(f)
    f.detail = ns.Detail.CreateEmbedded(f)
    f.column = ns.Column.Create(f)
    Layouts.Create(f)
    f.list = Controls.Scroll(f)
    f.list.empty = Controls.Text(f.list, "comment")
    f.list.empty:SetPoint("TOPLEFT", 4, -6)
    f.pool = Rows.NewPool(f.list.child)
    ns.Resize.Attach(f, resizeSpec)
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        local glow = f.header.refresh.glow
        if glow:IsShown() then glow:SetAlpha(0.45 + 0.4 * math.sin(GetTime() * 5)) end
        acc = acc + (elapsed or 0)
        if acc < TICK then return end
        acc = 0
        Window.Tick()
    end)
    f:SetScript("OnHide", function()
        ns.Menu.CloseOwn()
        Layouts.ClosePopup(f)
        ns.Detail.Close()
        if f.moving then
            f:StopMovingOrSizing()
            f.moving = nil
        end
    end)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, NAME) end
end

-- Public -------------------------------------------------------------------------------------------------

function Window.IsShown() return f ~= nil and f:IsShown() end

-- Opens the window. From a click or a key press only: it searches.
-- search: "adopt" (Blizzard searches in this click) or false (no search:
-- opened from an event) instead of searching.
function Window.Show(search)
    if not f then create() end
    if next(checked) == nil then Window.ResetChecked() end
    f:Show()
    Window.Refresh()
    if search == "adopt" then
        Window.AdoptSearch()
    elseif search ~= false then
        Window.Search()
    end
end

function Window.Hide()
    ns.Detail.Close()
    if f then f:Hide() end
end

function Window.Toggle()
    if Window.IsShown() then Window.Hide() else Window.Show() end
end

-- Events (never search) -------------------------------------------------------------------------------------

Finder.On("RESULTS", onResults)
Finder.On("RESULT_UPDATED", onResultUpdated)
Finder.On("FAILED", function()
    status = "failed"
    if Window.IsShown() then
        Window.UpdateHeader()
        Window.RenderList()
    end
end)
local function listingEvent()
    if not Window.IsShown() then return end
    ns.Side.Refresh()
    Window.ListingChanged()
end
Finder.On("ACTIVE_ENTRY", listingEvent)
Finder.On("EXPIRED", listingEvent)
Finder.On("AVAILABILITY", function() if Window.IsShown() then ns.Side.Refresh() end end)
ns.On("GROUP_ROSTER_UPDATE", listingEvent)
ns.On("PLAYER_ROLES_ASSIGNED", listingEvent)

Settings.OnChange(function()
    if Window.IsShown() then Window.Refresh() end
end)
ns.Locale.OnChange(function()
    if Window.IsShown() then Window.Refresh() end
end)
