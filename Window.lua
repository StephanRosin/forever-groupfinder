local ADDON, ns = ...
local L, Settings, Media, Controls = ns.L, ns.Settings, ns.Media, ns.Controls
local Finder, Activities, Results, Rows, Layouts = ns.Finder, ns.Activities, ns.Results, ns.Rows, ns.Layouts
local S = Settings.Get

-- The finder's main window: Forever Quest Log's header (Header.lua: shine,
-- line, grip, title with the list's age; refresh, lock, options, close) and
-- its parts: the activity
-- list (Side.lua), my listing (ListingPanel.lua), the filter chips, the
-- result list (Rows.lua: groups first, players below), the group details
-- (Detail.lua) and the leader line (Column.lua). Layouts.lua places the
-- parts for the chosen layout; this file builds them once and fills them.
--
-- Searching: C_LFGList.Search works only from a click or a key press. So
-- Window.Search is called from OnClick handlers and from the open-by-click
-- path (Toggle / Show) only, never from OnUpdate, timers or events. The
-- throttle lives in Finder; a dropped search just leaves the age showing.
local Window = {}
ns.Window = Window

local NAME = "ForeverGroupFinderWindow"
local HEADER_H = ns.Header.HEIGHT
local PAD = 8
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
            hideSeen = S("hideSeen"), text = filterText, activities = activities, categoryID = S("category"),
            playstyles = Window.PlaystyleSet() } or {},
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
    ns.Column.Refresh()   -- arranges again: the leader line and the counters may change
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
                -- The cached set follows, so a later rebuild (a settings
                -- refresh) shows the same as this row.
                for i, r in ipairs(results) do
                    if r.id == id then
                        if fresh then results[i] = fresh else r.isDelisted = true end
                    end
                end
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
    -- One activity ticked: its name heads the groups instead of every row.
    local only = Window.CheckedList()
    local single = #only == 1 and Activities.Name(only[1]) or nil
    Rows.singleActivity = single
    if total > 0 then
        place("DIVIDER", { text = single and L.DIVIDER_GROUPS_ACTIVITY:format(single, #built.groups)
            or L.DIVIDER_GROUPS:format(#built.groups) })
        for _, row in ipairs(built.groups) do place("GROUP", row) end
        if S("showPlayers") then
            place("DIVIDER", { text = L.DIVIDER_PLAYERS:format(#built.players), sort = true })
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

function Window.PlaystyleSet()
    local set = {}
    for _, v in ipairs(S("playstyles")) do set[v] = true end
    return set
end

-- The playstyle filter is local: the list follows at once, no search.
function Window.TogglePlaystyle(v)
    local list, found = {}, false
    for _, x in ipairs(S("playstyles")) do
        if x == v then found = true else list[#list + 1] = x end
    end
    if not found then list[#list + 1] = v end
    table.sort(list)
    Settings.Set("playstyles", list)
end

local function openPlaystyleMenu(owner)
    ns.Menu.Open(owner, function(root)
        root:CreateTitle(L.FILTER_PLAYSTYLE)
        for _, v in ipairs(ns.Playstyle.VALUES) do
            root:CreateCheckbox(ns.Playstyle.Name(v), function(x) return Window.PlaystyleSet()[x] == true end,
                function(x) Window.TogglePlaystyle(x) end, v)
        end
    end)
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

-- The filter row: [x] Level fits  [x] Hide seen  Language  Ignored (n)
-- Hidden (n) ... and the text filter at the right end. Items that do not
-- fit wrap to another line. Returns the row's height.
local TEXT_W = 110
function Window.LayoutFilters()
    local bar = f.filters
    local chips = bar.chips
    local chipH = Controls.ChipHeight()
    local width = bar:GetWidth()
    chips.filterLevelFits:SetLabel(L.FILTER_LEVEL_FITS)
    chips.hideSeen:SetLabel(L.FILTER_HIDE_SEEN)
    for _, key in ipairs(FILTER_KEYS) do chips[key]:SetChecked(S(key)) end
    local n = #S("languages")
    chips.language:SetLabel(n > 0 and L.FILTER_LANGUAGE_N:format(n) or L.FILTER_LANGUAGE)
    chips.language:SetOn(n > 0)
    local ps = #S("playstyles")
    chips.playstyle:SetLabel(ps > 0 and L.FILTER_PLAYSTYLE_N:format(ps) or L.FILTER_PLAYSTYLE)
    chips.playstyle:SetOn(ps > 0)
    local items = { chips.filterLevelFits, chips.hideSeen, chips.language, chips.playstyle }
    for _, entry in ipairs({ { chips.ignored, #ns.Memory.IgnoreList(), L.CHIP_IGNORED },
        { chips.hidden, #ns.Memory.HiddenList(), L.CHIP_HIDDEN } }) do
        local c, count = entry[1], entry[2]
        c:SetLabel(entry[3]:format(count))
        c:SetShown(count > 0)
        if count > 0 then items[#items + 1] = c end
    end
    bar.text:SetSize(TEXT_W, chipH)
    bar.text.hint:SetText(L.FILTER_TEXT)
    bar.text:ClearAllPoints()
    bar.text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    local x, line = 0, 0
    for _, c in ipairs(items) do
        local w = c:Fit()
        local limit = line == 0 and (width - TEXT_W - 8) or width
        if x > 0 and x + w > limit then x, line = 0, line + 1 end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -line * (chipH + 4))
        c:Show()
        x = x + w + 6
    end
    local h = (line + 1) * (chipH + 4) - 4
    bar:SetHeight(h)
    return h
end

local function createFilters(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar.chips = {}
    for _, key in ipairs(FILTER_KEYS) do
        bar.chips[key] = Controls.CheckLabel(bar, { onClick = function() Window.ToggleFilter(key) end,
            tip = function() return L["TIP_" .. key:upper()] end })
    end
    bar.chips.language = Controls.Chip(bar, { text = "", icon = "ChevronDown",
        onClick = function(self) openLanguageMenu(self) end, tip = function() return L.TIP_LANGUAGES end })
    bar.chips.playstyle = Controls.Chip(bar, { text = "", icon = "ChevronDown",
        onClick = function(self) openPlaystyleMenu(self) end, tip = function() return L.TIP_FILTER_PLAYSTYLE end })
    -- The way back to ignored leaders and hidden groups: their lists in the
    -- options (only shown while there are any).
    bar.chips.ignored = Controls.Chip(bar, { text = "", onClick = function() ns.Options.Open("list", "OPT_IGNORE") end,
        tip = function() return L.TIP_CHIP_IGNORED end })
    bar.chips.hidden = Controls.Chip(bar, { text = "", onClick = function() ns.Options.Open("list", "OPT_HIDDEN") end,
        tip = function() return L.TIP_CHIP_HIDDEN end })
    bar.text = Controls.EditBox(bar, L.FILTER_TEXT, 40)
    bar.text:HookScript("OnTextChanged", function(self) Window.SetTextFilter(self:GetText()) end)
    bar.text:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Window.Search()
    end)
    return bar
end

-- Header ---------------------------------------------------------------------------------------

-- The list's age after the title ("4 s ago", "Searching..."); the refresh
-- button turns gold and pulses while the list is outdated; the lock is
-- blue while unlocked, dim while locked (as the quest log's).
function Window.UpdateHeader()
    if not f then return end
    local h = f.header
    local note = ""
    if Finder.IsSearching() then
        note = L.SEARCHING
    else
        local age = Controls.Age(Finder.LastSearchAge())
        if age then note = L.REFRESH_AGE:format(age) end   -- plain: our formatted text
    end
    h.note:SetText(note)
    local outdated = receivedAt ~= nil and Window.Outdated()
    h.refresh.outdated = outdated
    h.refresh.on = outdated
    h.refresh.glow:SetShown(outdated)
    h.lock.icon:SetTexture(Media.Icon(S("locked") and "Lock" or "Unlock"))
    ns.Header.Layout(h, f.layoutWidth)
end

local function savePosition()
    local x, y = ns.Position.Read(f, "TOP")
    if x then Settings.SetMany({ point = "TOP", relPoint = "TOP", x = x, y = y }) end
end

local function canMove()
    return not S("locked") or (IsControlKeyDown and IsControlKeyDown())
end

-- The quest log's header: grip, title, the list's age, and from the right
-- close, options, lock, refresh.
local function createHeader()
    local Header = ns.Header
    local h = Header.Create(f, { movable = function() return not S("locked") end })
    h.title:SetText(L.WINDOW_TITLE)
    h.close = Header.CloseButton(h, function() return L.TIP_CLOSE end, function() Window.Hide() end)
    h.options = Header.Button(h, "Gear", function() return L.TIP_OPTIONS end, function() ns.Options.Toggle() end)
    h.lock = Header.Button(h, "Lock", function() return S("locked") and L.TIP_UNLOCK_WINDOW or L.TIP_LOCK_WINDOW end,
        function() ns.ToggleLock() end, function() return not S("locked") end)
    h.lock.activeColor = Controls.ACCENT
    h.refresh = Header.Button(h, "Reset", function(self) return self.outdated and L.TIP_OUTDATED or L.TIP_REFRESH end,
        function() Window.Search() end, function() return h.refresh ~= nil and h.refresh.outdated == true end)
    h.refresh.activeColor, h.refresh.offColor = Header.ON, Header.IDLE
    -- The outdated mark: a gold glow behind the icon, pulsing.
    h.refresh.glow = h.refresh:CreateTexture(nil, "BACKGROUND", nil, -1)
    h.refresh.glow:SetPoint("TOPLEFT", 1, -1)
    h.refresh.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    h.refresh.glow:SetColorTexture(1, 0.79, 0.19, 0.35)
    h.refresh.glow:Hide()
    -- Dragging the header moves the window (unlocked, or with Ctrl).
    h:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" and canMove() then
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
    Controls.ApplySizes()   -- button / chip heights and text size from the settings
    f:SetSize(width, height)
    Controls.Restyle(f.header.title)
    f.header.title:SetText(L.WINDOW_TITLE)
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
    ns.Undo.Tick()
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
    f.undo = ns.Undo.Create(f.list)
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
        ns.Undo.Clear()
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
