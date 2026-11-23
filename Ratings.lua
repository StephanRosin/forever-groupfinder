local _, ns = ...

-- Ratings: 1 to 5 stars and a comment per player (Stephan's wish 23.11.2026).
-- Stored account wide, outside the profiles (like Memory), keyed by the name
-- as the group finder writes it: "Name" on your own realm, "Name-Realm" else.
-- Rated from the row menu, and from Blizzard's unit menus through
-- Menu.ModifyMenu (unit frames, ours and Forever Unit Frames' via
-- togglemenu, and the chat's name menu). Our entry only opens our own
-- window and never calls a protected function, so it taints nothing.

local Ratings = {}
ns.Ratings = Ratings

local L = ns.L
local NOTE_MAX = 200
local STAR_ON, STAR_OFF = "255:209:0", "90:90:90"

Ratings.now = function() return time() end

local function store()
    local db = ns.AccountDB()
    db.ratings = db.ratings or {}
    return db.ratings
end

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- The key for a name (with or without "-Realm") and an optional realm;
-- nil for anything unreadable.
function Ratings.Key(name, realm)
    if type(name) ~= "string" or secret(name) or name == "" then return nil end
    local own, rest = name:match("^([^-]+)-(.+)$")
    if own then name, realm = own, rest end
    if secret(realm) then return nil end
    realm = type(realm) == "string" and realm:gsub("%s", "") or ""
    local home = GetNormalizedRealmName and GetNormalizedRealmName() or nil
    if realm == "" or realm == home then return name end
    return name .. "-" .. realm
end

-- { stars, note, at } or nil.
function Ratings.Get(name)
    local key = Ratings.Key(name)
    return key and store()[key] or nil
end

function Ratings.Set(name, stars, note)
    local key = Ratings.Key(name)
    if not key or type(stars) ~= "number" or stars < 1 or stars > 5 then return false end
    note = type(note) == "string" and strtrim(note):sub(1, NOTE_MAX) or ""
    store()[key] = { stars = math.floor(stars), note = note, at = Ratings.now() }
    return true
end

function Ratings.Remove(name)
    local key = Ratings.Key(name)
    if key then store()[key] = nil end
end

local function star(color)
    return "|T" .. ns.Media.Icon("Star") .. ":0:0:0:0:32:32:0:32:0:32:" .. color .. "|t"
end

-- Five stars, the first n gold.
function Ratings.Stars(n)
    local out = {}
    for i = 1, 5 do out[i] = star(i <= n and STAR_ON or STAR_OFF) end
    return table.concat(out)
end

-- " ★4" after a name in the list; "" when unrated.
function Ratings.Badge(name)
    local r = Ratings.Get(name)
    return r and (" " .. star(STAR_ON) .. r.stars) or ""
end

-- The rating as lines for a tooltip or the detail panel: add(text, color, wrap).
function Ratings.AddLines(add, name)
    local r = Ratings.Get(name)
    if not r then return end
    add(L.RATING_LINE:format(Ratings.Stars(r.stars)), ns.Controls.GOLD)
    if r.note ~= "" then add(r.note, { 1, 1, 1 }, true) end
end

-- After a change: what shows ratings follows.
local function refresh()
    if ns.Window and ns.Window.IsShown() then ns.Window.RefreshRows() end
    if ns.Detail and ns.Detail.IsShown() then ns.Detail.Refresh() end
end

-- The window ----------------------------------------------------------------------------

local W, PAD, STAR = 300, 12, 24
local d   -- made on first use

local function paintStars()
    local shown = d.hover or d.stars
    for i, b in ipairs(d.starButtons) do
        local c = i <= shown and ns.Controls.GOLD or { 0.35, 0.35, 0.35 }
        b.tex:SetVertexColor(c[1], c[2], c[3])
    end
    d.save:SetOff(d.stars < 1, L.RATING_PICK_STARS)
end

local function save()
    if d.stars < 1 then return end
    Ratings.Set(d.name, d.stars, d.note:GetText())
    d:Hide()
    refresh()
end

local function build()
    local Controls = ns.Controls
    d = CreateFrame("Frame", "ForeverGroupFinderRating", UIParent)
    d:SetFrameStrata("DIALOG")
    d:EnableMouse(true)
    d:SetMovable(true)
    d:SetClampedToScreen(true)
    d.bg = d:CreateTexture(nil, "BACKGROUND")
    d.bg:SetAllPoints()
    d.clip = {}
    local h = ns.Header.Create(d, { movable = function() return true end })
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() d:StartMoving() end)
    h:SetScript("OnDragStop", function() d:StopMovingOrSizing() end)
    h.close = ns.Header.CloseButton(h, function() return L.TIP_CLOSE end, function() d:Hide() end)
    d.starButtons = {}
    for i = 1, 5 do
        local b = CreateFrame("Button", nil, d)
        b:SetSize(STAR, STAR)
        b:SetPoint("TOPLEFT", d, "TOPLEFT", PAD + (i - 1) * (STAR + 4), -(ns.Header.HEIGHT + PAD))
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexture(ns.Media.Icon("Star"))
        b:SetScript("OnEnter", function() d.hover = i paintStars() end)
        b:SetScript("OnLeave", function() d.hover = nil paintStars() end)
        b:SetScript("OnClick", function() d.stars = i paintStars() end)
        d.starButtons[i] = b
    end
    d.note = Controls.EditBox(d, L.RATING_NOTE_HINT, NOTE_MAX)
    d.note:SetPoint("TOPLEFT", d.starButtons[1], "BOTTOMLEFT", 0, -10)
    d.note:SetWidth(W - 2 * PAD)
    d.note:SetScript("OnEnterPressed", save)
    d.save = Controls.Button(d, { text = L.RATING_SAVE, width = 80, primary = true, onClick = save })
    d.save:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -PAD, PAD)
    d.remove = Controls.Button(d, { text = L.RATING_REMOVE, width = 80, onClick = function()
        Ratings.Remove(d.name)
        d:Hide()
        refresh()
    end })
    d.remove:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", PAD, PAD)
    d:SetScript("OnHide", function() d.note:ClearFocus() end)
    d:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, d:GetName()) end
end

-- Opens the window for name (as Ratings.Key reads it).
function Ratings.Open(name)
    local key = Ratings.Key(name)
    if not key then return end
    if not d then build() end
    local r = store()[key]
    d.name, d.stars, d.hover = key, r and r.stars or 0, nil
    d.note:SetText(r and r.note or "")
    d.note.updateHint(d.note)
    d.remove:SetShown(r ~= nil)
    local height = ns.Header.HEIGHT + PAD + STAR + 10 + d.note:GetHeight() + PAD + ns.Controls.ButtonHeight() + PAD
    d:SetSize(W, height)
    if not d:IsShown() then
        d:ClearAllPoints()
        d:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    ns.Window.ApplyLook(d, W, height)
    d.header.title:SetText(L.RATING_TITLE:format(key))
    ns.Header.Layout(d.header, W)
    paintStars()
    d:Show()
end

function Ratings.Frame() return d end

-- Unit and chat menus ---------------------------------------------------------------------

Ratings.TAGS = { "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID", "MENU_UNIT_PLAYER", "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS", "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_GUILD",
    "MENU_UNIT_GUILD_OFFLINE", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
    "MENU_UNIT_RECENT_ALLY", "MENU_UNIT_RECENT_ALLY_OFFLINE" }

-- The player a menu is about: from its unit (a player, readable), else the
-- name the chat or a list gave; nil for yourself and anything unreadable.
function Ratings.MenuName(contextData)
    if type(contextData) ~= "table" then return nil end
    local key
    local unit = contextData.unit
    if type(unit) == "string" then
        local ok, isPlayer = pcall(UnitIsPlayer, unit)
        if not ok or secret(isPlayer) or isPlayer ~= true then return nil end
        local okName, name, realm = pcall(UnitName, unit)
        if not okName then return nil end
        key = Ratings.Key(name, realm)
    else
        key = Ratings.Key(contextData.name, contextData.server)
    end
    if not key or key == Ratings.Key(UnitName("player")) then return nil end
    return key
end

-- The entry's text: "Rate..." or the stars given.
function Ratings.MenuText(name)
    local r = Ratings.Get(name)
    return r and L.RATING_MENU_RATED:format(Ratings.Stars(r.stars)) or L.RATING_MENU
end

-- Adds the entry to a menu (ours or Blizzard's); the comment as its tooltip.
function Ratings.AddMenuEntry(root, name)
    local item = root:CreateButton(Ratings.MenuText(name), function() Ratings.Open(name) end)
    local r = Ratings.Get(name)
    if r and r.note ~= "" and item.SetTooltip then
        item:SetTooltip(function(tooltip)
            tooltip:SetText(L.RATING_LINE:format(Ratings.Stars(r.stars)), 1, 0.82, 0)
            tooltip:AddLine(r.note, 1, 1, 1, true)
        end)
    end
    return item
end

function Ratings.ModifyMenu(_, root, contextData)
    local name = Ratings.MenuName(contextData)
    if not name then return end   -- plain: MenuName read it secret-safe
    root:CreateDivider()
    root:CreateTitle(L.ADDON_NAME)
    Ratings.AddMenuEntry(root, name)
end

if Menu and Menu.ModifyMenu then
    for _, tag in ipairs(Ratings.TAGS) do Menu.ModifyMenu(tag, Ratings.ModifyMenu) end
end
