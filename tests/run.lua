-- Tests for Forever Group Finder. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
-- Events the client knows: registering any other name throws, as in the game.
M.validEvents = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true, PLAYER_LEVEL_UP = true,
    LFG_LIST_SEARCH_RESULTS_RECEIVED = true, LFG_LIST_SEARCH_RESULT_UPDATED = true, LFG_LIST_SEARCH_FAILED = true,
    LFG_LIST_ACTIVE_ENTRY_UPDATE = true, LFG_LIST_AVAILABILITY_UPDATE = true, LFG_LIST_ENTRY_EXPIRED_TIMEOUT = true,
    LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS = true, LFG_LIST_SHOW_SEARCH = true }
local ROOT = ADDONDIR
local ADDON = "ForeverGroupFinder"

local function tocLines()
    local lines = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do lines[#lines + 1] = (line:gsub("\r", "")) end
    return lines
end

local function tocFiles()
    local files = {}
    for _, line in ipairs(tocLines()) do
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

local function read(f)
    local h = assert(io.open(ROOT .. "/" .. f))
    local src = h:read("*a")
    h:close()
    return src
end

local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-58s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end

local S, Settings = ns.Settings.Get, ns.Settings

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD")
M.RunTimers()

section("Load")
check("TOC lists existing files only", (function()
    for _, f in ipairs(tocFiles()) do
        local h = io.open(ROOT .. "/" .. f)
        if not h then return f end
        h:close()
    end
    return true
end)(), true)
check("TOC lists every Lua file once", (function()
    local listed = {}
    for _, f in ipairs(tocFiles()) do
        if listed[f] then return "twice: " .. f end
        listed[f] = true
    end
    local found = io.popen("cd '" .. ROOT .. "' && find . -name '*.lua' -not -path './tests/*' -not -path './.superpowers/*' | sed 's|^./||' | sort")
    for f in found:lines() do
        if not listed[f] then return "not in the TOC: " .. f end
    end
    return true
end)(), true)
local toc = {}
for _, line in ipairs(tocLines()) do
    local key, value = line:match("^## ([%w%-]+): *(.-) *$")
    if key then toc[key] = value end
end
check("Interface", toc.Interface, "16001")
check("Title", toc.Title, "Forever Group Finder")
check("Version", toc.Version, "1.0.0")
check("saved variables (account)", toc.SavedVariables, "ForeverGroupFinderProfiles")
check("saved variables (character)", toc.SavedVariablesPerCharacter, "ForeverGroupFinderChar")
check("compartment click", toc.AddonCompartmentFunc, "ForeverGroupFinder_OnAddonCompartmentClick")
check("compartment enter", toc.AddonCompartmentFuncOnEnter, "ForeverGroupFinder_OnAddonCompartmentEnter")
check("compartment leave", toc.AddonCompartmentFuncOnLeave, "ForeverGroupFinder_OnAddonCompartmentLeave")
check("icon", toc.IconTexture, "Interface\\AddOns\\ForeverGroupFinder\\Media\\MinimapIcon.tga")
check("icon file exists", io.open(ROOT .. "/Media/MinimapIcon.tga") ~= nil, true)
for _, lang in ipairs({ "deDE", "esES", "esMX", "frFR" }) do
    check("Notes-" .. lang, (toc["Notes-" .. lang] or "") ~= "", true)
end
for _, name in ipairs({ "L", "Locale", "On", "Print", "AfterCombat", "DB", "AccountDB", "ActiveProfile",
    "SwitchProfile", "DeleteProfile", "CopyProfileFrom", "ProfileList", "Settings", "Share", "Media",
    "Position", "Corners", "Border", "Resize", "Window", "Options", "MinimapButton", "Style", "Widgets" }) do
    check("ns." .. name, ns[name] ~= nil, true)
end
for _, name in ipairs({ "Get", "Set", "SetMany", "OnChange", "Changed", "TextStyle", "ResetProfile", "SetLocked",
    "DEFAULTS", "RANGES", "TEXT_STYLES" }) do
    check("Settings." .. name, Settings[name] ~= nil, true)
end
check("saved variables (account) table", type(ForeverGroupFinderProfiles), "table")
check("saved variables (character) table", type(ForeverGroupFinderChar), "table")
check("default profile", ns.ActiveProfile(), "Default")

section("Shipped defaults")
local D = Settings.DEFAULTS
local EXPECTED = {
    replaceBlizzard = true, minimapShow = true, minimapAngle = 215, compartment = true,
    point = "CENTER", relPoint = "CENTER", x = 0, y = 40, width = 720, height = 460,
    scale = 100, locked = false, sideWidth = 190,
    layout = "SIDEBAR", stackedWidth = 480, stackedHeight = 560, detailsWidth = 880, detailsHeight = 480,
    minInterval = 1, levelRangeOnly = true, category = 2, sortFriendsFirst = true,
    filterMyRole = true, filterLevelFits = false, hideSeen = false,
    markOpenSlot = true, showPlayers = true, rowHeight = 22, playerRowHeight = 34,
    memoryMinutes = 30,
    expiryWarnMinutes = 5,
    borderStyle = "NONE", borderSize = 1, cornerRadius = 10,
    shadowEnabled = true, shadowSize = 9, shadowAlpha = 65,
    bgMode = "SOLID", bgAlpha = 85, bgTexture = "Blizzard Dialog Background Gold", headerLine = true,
    headerFont = "Friz Quadrata", headerSize = 18, headerFlag = "SHADOW",
    activityFont = "Friz Quadrata", activitySize = 12, activityFlag = "SHADOW",
    nameFont = "Friz Quadrata", nameSize = 12, nameFlag = "SHADOW",
    commentFont = "Friz Quadrata", commentSize = 11, commentFlag = "SHADOW",
    smallFont = "Friz Quadrata", smallSize = 10, smallFlag = "SHADOW",
    levelFont = "Friz Quadrata", levelSize = 15, levelFlag = "SHADOW",
    locationFont = "Friz Quadrata", locationSize = 12, locationFlag = "SHADOW",
    chipFont = "Friz Quadrata", chipSize = 10, chipFlag = "SHADOW",
    ageFont = "Friz Quadrata", ageSize = 10, ageFlag = "SHADOW",
    playerRoleIconSize = 0, groupRoleIconSize = 16, classIconSize = 14, classColorNames = true, seenAlpha = 45,
    abbreviate = true,
    noRoomAlpha = 45,
}
local expectedCount = 0
for key, want in pairs(EXPECTED) do
    expectedCount = expectedCount + 1
    check("default " .. key, D[key], want)
end
local COLORS = {
    borderColor = { 0, 0, 0, 1 }, bgColor = { 0.047, 0.047, 0.055 }, headerColor = { 1, 0.82, 0.29 },
    activityColor = { 1, 0.82, 0.29 }, nameColor = { 1, 1, 1 }, commentColor = { 0.79, 0.76, 0.69 },
    smallColor = { 0.55, 0.54, 0.5 }, levelColor = { 1, 1, 1 }, locationColor = { 1, 0.82, 0.29 },
    chipColor = { 0.79, 0.76, 0.69 }, ageColor = { 0.55, 0.54, 0.5 },
    chipBorderColor = { 0.36, 0.29, 0.13 }, openEdgeColor = { 0.25, 0.75, 0.37 },
}
for key, want in pairs(COLORS) do
    expectedCount = expectedCount + 1
    check("default " .. key, Settings.SameValue(D[key], want), true)
end
check("default languages", next(D.languages), nil)
check("default templates", next(D.templates), nil)
check("default whisper templates", #D.whisperTemplates, 1)
check("default whisper text", D.whisperTemplates[1], "Hi! Still looking for {role}? I'm a level {level} {class}.")
local total = 0
for _ in pairs(D) do total = total + 1 end
check("no other default (languages, templates and whisperTemplates are the three tables)", total, expectedCount + 3)
local RANGES = {
    width = { 560, 1100 }, height = { 320, 800 }, scale = { 50, 150 }, sideWidth = { 150, 280 },
    stackedWidth = { 420, 900 }, stackedHeight = { 360, 1000 }, detailsWidth = { 720, 1300 }, detailsHeight = { 360, 900 },
    minInterval = { 1, 15 }, rowHeight = { 16, 36 }, playerRowHeight = { 26, 50 }, memoryMinutes = { 5, 240 },
    expiryWarnMinutes = { 1, 15 }, borderSize = { 1, 8 }, cornerRadius = { 0, 12 }, shadowSize = { 1, 20 },
    x = { -4000, 4000 }, y = { -4000, 4000 },
    shadowAlpha = { 0, 100 }, bgAlpha = { 0, 100 }, headerSize = { 8, 24 }, activitySize = { 8, 20 },
    nameSize = { 8, 20 }, commentSize = { 8, 18 }, smallSize = { 7, 16 },
    minimapAngle = { 0, 360 },   -- the options slider; dragging sets it too
    playerRoleIconSize = { 0, 48 }, groupRoleIconSize = { 10, 28 }, classIconSize = { 8, 28 }, seenAlpha = { 10, 100 }, noRoomAlpha = { 10, 100 },
    levelSize = { 8, 24 }, locationSize = { 8, 20 }, chipSize = { 7, 16 }, ageSize = { 7, 16 },
}
local rangeCount = 0
for key, want in pairs(RANGES) do
    rangeCount = rangeCount + 1
    local got = Settings.RANGES[key]
    check("range " .. key, got and (got[1] .. "-" .. got[2]), want[1] .. "-" .. want[2])
    check("default of " .. key .. " is in its range", D[key] >= want[1] and D[key] <= want[2], true)
end
local rangesTotal = 0
for _ in pairs(Settings.RANGES) do rangesTotal = rangesTotal + 1 end
check("no other range", rangesTotal, rangeCount)
check("text styles", table.concat(Settings.TEXT_STYLES, ","), "header,activity,name,comment,small,level,location,chip,age")
check("list styles", table.concat(Settings.LIST_STYLES, ","), "activity,name,level,location,chip,comment,age")
for _, name in ipairs(Settings.TEXT_STYLES) do
    for _, part in ipairs({ "Font", "Size", "Flag", "Color" }) do
        check("default " .. name .. part, D[name .. part] ~= nil, true)
    end
end

section("Settings")
Settings.Set("width", 900)
check("set and get", S("width"), 900)
check("stored", ns.DB().width, 900)
Settings.Set("width", D.width)
check("default is not stored", ns.DB().width, nil)
check("get falls back", S("width"), 720)
Settings.Set("width", 5000)
check("clamped to the maximum", S("width"), 1100)
Settings.Set("width", 1)
check("clamped to the minimum", S("width"), 560)
Settings.Set("minInterval", 0)
check("search interval never below 1 s", S("minInterval"), 1)
Settings.Set("scale", 99.6)
check("whole numbers", S("scale"), 100)
check("rounded to the default is not stored", ns.DB().scale, nil)
Settings.ResetProfile()
check("only non-defaults are stored", next(ns.DB()), nil)
local seen = {}
Settings.OnChange(function(key) seen[#seen + 1] = tostring(key) end)
Settings.SetMany({ x = 30, y = 80, width = D.width })
check("SetMany: one change", table.concat(seen, ","), "nil")
check("SetMany values", S("x") + S("y"), 110)
check("SetMany drops defaults", ns.DB().width, nil)
Settings.Set("x", 12)
check("Set reports its key", seen[#seen], "x")
check("text style size", Settings.TextStyle("comment").size, 11)
check("text style font", Settings.TextStyle("header").font, "Friz Quadrata")
Settings.SetLocked(true)
check("lock", S("locked"), true)
Settings.SetLocked(false)
check("unlock", S("locked"), false)
check("unlocked stores nothing", ns.DB().locked, nil)
Settings.ResetProfile()
-- Tables are stored whole, and only when they differ.
Settings.Set("languages", { "deDE", "enUS" })
check("languages stored whole", #ns.DB().languages, 2)
Settings.Set("languages", {})
check("empty languages is the default", ns.DB().languages, nil)
Settings.Set("whisperTemplates", { "Hi! Still looking for {role}? I'm a level {level} {class}." })
check("default whisper templates are not stored", ns.DB().whisperTemplates, nil)
Settings.Set("whisperTemplates", { "one", "two" })
check("whisper templates stored whole", #ns.DB().whisperTemplates, 2)
local template = { name = "Heal", activityIDs = { 3, 4 }, comment = "chill", roles = { tank = false, healer = true, dps = false } }
Settings.Set("templates", { template })
check("template stored", ns.DB().templates[1].name, "Heal")
template.name = "changed later"
check("a stored table is a copy", ns.DB().templates[1].name, "Heal")
check("colour differing from the default is stored", (function()
    Settings.Set("nameColor", { 1, 0, 0 })
    return ns.DB().nameColor[2]
end)(), 0)
Settings.Set("nameColor", { 1, 1, 1 })
check("colour equal to the default is not stored", ns.DB().nameColor, nil)
local got = S("languages")
got[1] = "frFR"
check("Get hands out a copy of a default table", next(D.languages), nil)
Settings.ResetProfile()

section("Profiles")
Settings.Set("width", 800)
ns.SwitchProfile("Raid")
check("new profile starts from the current", S("width"), 800)
check("two profiles", #ns.ProfileList(), 2)
Settings.Set("width", 640)
ns.SwitchProfile("Default")
check("other profile unchanged", S("width"), 800)
check("character stores the name", ForeverGroupFinderChar.active, "Default")
check("copy from", ns.CopyProfileFrom("Raid"), true)
check("copied", S("width"), 640)
ns.SwitchProfile("Raid")
check("delete the active one", ns.DeleteProfile("Raid"), true)
check("falls back to Default", ns.ActiveProfile(), "Default")
check("delete unknown", ns.DeleteProfile("nope"), false)
M.chat = {}
ns.AskDeleteProfile()
check("last profile refused", M.chat[1] ~= nil and M.chat[1]:find("last profile", 1, true) ~= nil, true)
local changes = 0
Settings.OnChange(function(key) if key == nil then changes = changes + 1 end end)
ns.SwitchProfile("Other")
check("a profile switch tells everyone", changes, 1)
ns.SwitchProfile("Default")
ns.DeleteProfile("Other")
Settings.ResetProfile()

section("Export and import")
Settings.Set("width", 777)
Settings.Set("bgColor", { 0.1, 0.2, 0.3 })
Settings.Set("borderStyle", "GOLD")
Settings.Set("languages", { "deDE" })
Settings.Set("whisperTemplates", { "a", "b {role}" })
template.name = "Heal"
Settings.Set("templates", { template, { name = "Dps", activityIDs = {}, comment = "", roles = { tank = false, healer = false, dps = true } } })
Settings.Set("headerFlag", "OUTLINE")
local text = ns.Share.Export()
check("prefix", text:sub(1, 5), "FGF1:")
check("prefix constant", ns.Share.PREFIX, "FGF1:")
Settings.ResetProfile()
check("reset", S("width"), D.width)
check("import", ns.Share.Import(text), true)
check("number back", S("width"), 777)
check("colour back", S("bgColor")[3], 0.3)
check("enum back", S("borderStyle"), "GOLD")
check("flag back", S("headerFlag"), "OUTLINE")
check("languages back", S("languages")[1], "deDE")
check("whisper templates back", S("whisperTemplates")[2], "b {role}")
check("templates back (count)", #S("templates"), 2)
check("templates back (name)", S("templates")[1].name, "Heal")
check("templates back (activities)", S("templates")[1].activityIDs[2], 4)
check("templates back (roles)", S("templates")[2].roles.dps, true)
check("export is the same after a round trip", ns.Share.Export(), text)
check("only non-defaults travel", select(2, text:gsub("s%d+:", "")) < 40, true)
check("garbage refused", ns.Share.Import("hello"), nil)
check("a combat meter string is refused", ns.Share.Import("FCM1:t}"), nil)
check("a quest log string is refused", ns.Share.Import("FQL1:t}"), nil)
check("code is never run", ns.Share.Import("FGF1:s5:os.ex"), nil)
check("truncated string refused", ns.Share.Import(text:sub(1, #text - 3)), nil)
check("unknown keys skipped", ns.Share.Import("FGF1:ts6:bogus!b1}"), true)
check("unknown key not stored", ns.DB().bogus, nil)
Settings.ResetProfile()
check("bad enum values skipped", ns.Share.Import("FGF1:ts11:borderStyles3:BAD"
    .. "s6:bgModes5:SOLIDs10:headerFlags6:Italic}"), true)
check("a removed setting (roleOverride) is skipped", ns.Share.Import("FGF1:ts12:roleOverrides4:TANK}"), true)
check("removed setting not stored", ns.DB().roleOverride, nil)
check("bad borderStyle not stored", ns.DB().borderStyle, nil)
check("bad flag not stored", ns.DB().headerFlag, nil)
check("good enum kept", ns.Share.Import("FGF1:ts11:borderStyles4:GOLDs8:nameFlags7:OUTLINE}"), true)
check("enum imported", S("borderStyle"), "GOLD")
check("flag imported", S("nameFlag"), "OUTLINE")
check("wrong type skipped", ns.Share.Import("FGF1:ts5:widths3:abcs6:locked" .. "n1;}"), true)
check("wrong type not stored", ns.DB().width, nil)
check("wrong type (bool) not stored", ns.DB().locked, nil)
check("bad anchors skipped", ns.Share.Import("FGF1:ts5:points6:MIDDLEs8:relPoints3:TOP}"), true)
check("bad point not stored", ns.DB().point, nil)
check("good relPoint kept", S("relPoint"), "TOP")
check("good point kept", ns.Share.Import("FGF1:ts5:points10:BOTTOMLEFT}") and S("point"), "BOTTOMLEFT")
check("x and y are clamped", ns.Share.Import("FGF1:ts1:xn99999;s1:yn-99999;}"), true)
check("x clamped", S("x"), 4000)
check("y clamped", S("y"), -4000)
check("known category kept", ns.Share.Import("FGF1:ts8:categoryn114;}") and S("category"), 114)
check("unknown category dropped", ns.Share.Import("FGF1:ts8:categoryn7;}"), true)
check("unknown category not stored", ns.DB().category, nil)
check("numbers are clamped", ns.Share.Import("FGF1:ts5:widthn99999;}"), true)
check("clamped width", S("width"), 1100)
check("a bad template list is dropped", ns.Share.Import("FGF1:ts9:templatest" .. "n1;s3:abc}}"), true)
check("bad template not stored", ns.DB().templates, nil)
check("a table where a number belongs is skipped", ns.Share.Import("FGF1:ts5:widtht}}"), true)
check("table for number not stored", ns.DB().width, nil)
Settings.ResetProfile()

section("Locale")
local Locale = ns.Locale
check("game language by default", Locale.Current(), "enUS")
check("setting by default", Locale.Setting(), "AUTO")
check("de resolves", Locale.Resolve("AUTO", "deDE"), "deDE")
check("esMX gets Spanish", Locale.Resolve("AUTO", "esMX"), "esES")
check("unknown game language gets English", Locale.Resolve("AUTO", "koKR"), "enUS")
check("a chosen language beats the game", Locale.Resolve("frFR", "deDE"), "frFR")
Locale.Set("deDE")
check("German applied", ns.L.PAGE_PROFILES, "Profile")
check("stored in the account, not in a profile", ForeverGroupFinderProfiles.language, "deDE")
ns.SwitchProfile("Elsewhere")
check("a profile switch keeps the language", Locale.Current(), "deDE")
ns.SwitchProfile("Default")
ns.DeleteProfile("Elsewhere")
Locale.Set("AUTO")
check("auto stores nothing", ForeverGroupFinderProfiles.language, nil)
check("back to English", ns.L.PAGE_PROFILES, "Profiles")
check("a missing key shows as itself", ns.L.NO_SUCH_KEY, "NO_SUCH_KEY")

section("Options window")
ns.Options.Open()
check("window shown", ns.Options.IsShown(), true)
local function rowFor(label, field)
    for _, f in ipairs(M.frames) do
        if f[field] and f.label and f.label._text and f.label._text:find(label, 1, true) and f:IsVisible() then
            return f
        end
    end
end
local pageIds = {}
for _, page in ipairs(ns.Options.PAGES) do pageIds[#pageIds + 1] = page.id end
check("pages", table.concat(pageIds, ","), "general,window,appearance,text,look,list,templates,profiles")
for _, page in ipairs(ns.Options.PAGES) do
    local ok, err = pcall(ns.Options.ShowPage, page.id)
    check("page " .. page.id .. " builds", ok, true)
    if not ok then print(err) end
end
for _, id in ipairs(pageIds) do check("nav button " .. id, M.byName["ForeverGroupFinderNav" .. id] ~= nil, true) end
ns.Options.ShowPage("general")
check("replace row", rowFor("Open this finder instead", "box") ~= nil, true)
check("minimap row", rowFor("Minimap button", "box") ~= nil, true)
check("compartment row", rowFor("addon list", "box") ~= nil, true)
check("language dropdown in the nav", ns.Options.languageRow ~= nil or rowFor("Language", "button") ~= nil, true)
ns.Options.ShowPage("profiles")
check("profile row", rowFor("Active profile", "button") ~= nil, true)
-- Every setting has a row on some page (the X / Y sliders also write the
-- anchor; minimapAngle is dragged too).
local reachable = {}
for _, page in ipairs(ns.Options.PAGES) do
    local specs = page.rows()
    for _, opt in ipairs(specs) do
        if opt.key then reachable[opt.key] = page.id end
        for _, key in ipairs(opt.keys or {}) do reachable[key] = page.id end
    end
    ns.Options.ShowPage(page.id)
    local built = M.byName["ForeverGroupFinderPage" .. page.id]
    check("page " .. page.id .. " has its rows", built ~= nil and #built.allRows, #specs)
end
for key in pairs(Settings.DEFAULTS) do check("setting " .. key .. " is on an options page", reachable[key] ~= nil, true) end
check("replace Blizzard on General", reachable.replaceBlizzard, "general")
check("compartment on General", reachable.compartment, "general")
check("scale on Window", reachable.scale, "window")
check("side width on Window", reachable.sideWidth, "window")
check("border on Appearance", reachable.borderStyle, "appearance")
check("comment colour on List look", reachable.commentColor, "look")
check("header colour on Text", reachable.headerColor, "text")
for _, key in ipairs({ "rowHeight", "playerRowHeight", "playerRoleIconSize", "groupRoleIconSize", "classIconSize",
    "classColorNames", "chipBorderColor", "openEdgeColor", "seenAlpha", "levelSize", "levelColor", "locationSize",
    "locationColor", "chipSize", "chipColor", "ageSize", "ageColor", "activitySize", "activityColor", "nameSize" }) do
    check(key .. " on List look", reachable[key], "look")
end
check("no role override any more", Settings.DEFAULTS.roleOverride, nil)
check("memory on List", reachable.memoryMinutes, "list")
check("whispers on Templates", reachable.whisperTemplates, "templates")
check("templates on Templates", reachable.templates, "templates")
-- Window page.
ns.Options.ShowPage("window")
local wRow = rowFor("Width of the side panel", "slider")
check("side width slider", wRow ~= nil, true)
wRow.slider:GetScript("OnValueChanged")(wRow.slider, 200, true)
check("side width set", S("sideWidth"), 200)
Settings.Set("sideWidth", nil)
local xRow = rowFor("Horizontal", "slider")
xRow.slider:GetScript("OnValueChanged")(xRow.slider, 120, true)
check("X slider: x", S("x"), 120)
check("X slider: anchored at the top", S("point") .. "/" .. S("relPoint"), "TOP/TOP")
local resetButton
for _, f in ipairs(M.frames) do
    if f.text and f.text._text == "Reset position and size" and f:IsVisible() then resetButton = f end
end
check("reset button", resetButton ~= nil, true)
resetButton:GetScript("OnClick")(resetButton)
check("reset: back to the defaults", S("x") .. "/" .. S("point"), "0/CENTER")
check("lock on the Window page", rowFor("Locked", "box") ~= nil, true)
-- The options window keeps its place (and page) when the language changes.
do
local Locale = ns.Locale
ns.Options.Open("look")
local of = M.byName.ForeverGroupFinderOptions
of._rect = { 300, 200, of:GetWidth(), of:GetHeight() }
local bar = of.titleBar
bar:GetScript("OnDragStart")(bar)
bar:GetScript("OnDragStop")(bar)
local saved = ns.AccountDB().optionsPosition
check("options position stored on drag", saved ~= nil and saved.x .. "/" .. saved.y,
    (300 + of:GetWidth() / 2 - 960) .. "/" .. (200 + of:GetHeight() - 1080))
of._rect = { 500, 100, of:GetWidth(), of:GetHeight() }
Locale.Set("deDE")
local nf = M.byName.ForeverGroupFinderOptions
check("a new window for the language", nf ~= of, true)
check("still open", ns.Options.IsShown(), true)
check("same page", M.byName.ForeverGroupFinderPagelook:IsShown(), true)
check("where the old one was", nf._points.TOP and (nf._points.TOP[3] .. "/" .. nf._points.TOP[4]),
    (500 + of:GetWidth() / 2 - 960) .. "/" .. (100 + of:GetHeight() - 1080))
Locale.Set("AUTO")
ns.AccountDB().optionsPosition = nil
end
-- Text page: five styles.
ns.Options.ShowPage("text")
local sizeRows = 0
for _, f in ipairs(M.frames) do
    if f.slider and f.label and f.label._text == "Size" and f:IsVisible() then sizeRows = sizeRows + 1 end
end
check("two text styles outside the list", sizeRows, 2)
ns.Options.ShowPage("look")
sizeRows = 0
for _, f in ipairs(M.frames) do
    if f.slider and f.label and f.label._text == "Size" and f:IsVisible() then sizeRows = sizeRows + 1 end
end
check("seven list styles on List look", sizeRows, 7)
-- Appearance: the flat colour only for a flat border.
ns.Options.ShowPage("appearance")
check("border colour hidden without a flat border", rowFor("Colour (flat)", "swatch") == nil, true)
Settings.Set("borderStyle", "FLAT")
check("border colour shown for a flat border", rowFor("Colour (flat)", "button") ~= nil or rowFor("Colour (flat)", "swatch") ~= nil, true)
Settings.Set("borderStyle", nil)
-- List & Filters: role, languages, the ignore list.
local function itemFor(text)
    for _, f in ipairs(M.frames) do
        if f.button and f.text and f.text._text == text and f:IsVisible() then return f end
    end
end
ns.Options.ShowPage("list")
check("ignore list empty hint", (function()
    for _, f in ipairs(M.frames) do
        if f.text and f.text._text == "No one is ignored." and f:IsVisible() then return true end
    end
    return false
end)(), true)
local addRow = rowFor("Add a name", "edit")
check("ignore input", addRow ~= nil, true)
addRow.edit:SetText("  Grumpy  ")
addRow.edit:GetScript("OnEnterPressed")(addRow.edit)
check("ignored from the options", ns.Memory.IsIgnored("Grumpy"), true)
check("listed", itemFor("Grumpy") ~= nil, true)
check("input empty again", addRow.edit:GetText(), "")
addRow.edit:SetText("   ")
addRow.edit:GetScript("OnEnterPressed")(addRow.edit)
check("blank name ignored", #ns.Memory.IgnoreList(), 1)
local item = itemFor("Grumpy")
item.button:GetScript("OnClick")(item.button)
check("removed from the ignore list", ns.Memory.IsIgnored("Grumpy"), false)
check("its row gone", itemFor("Grumpy"), nil)
for i = 1, ns.Options.LIST_SLOTS + 3 do ns.Memory.Ignore(("P%02d"):format(i)) end
ns.Options.Refresh()
check("more than the slots: a line says how many", (function()
    for _, f in ipairs(M.frames) do
        if f.text and f.text._text == "... and 3 more" and f:IsVisible() then return true end
    end
    return false
end)(), true)
for _, name in ipairs(ns.Memory.IgnoreList()) do ns.Memory.Unignore(name) end
local deRow = rowFor("Deutsch", "box")
check("language tick", deRow ~= nil, true)
deRow.box:GetScript("OnClick")(deRow.box)
check("language ticked", table.concat(S("languages"), ","), "deDE")
deRow.box:GetScript("OnClick")(deRow.box)
check("language unticked: nothing stored", ns.DB().languages, nil)
-- Templates: delete a saved listing, edit the whispers.
ns.Listing.SaveTemplate("RFC tank", { 21 }, { tank = true }, "LF tank")
ns.Options.ShowPage("templates")
local tItem = itemFor("RFC tank")
check("saved listing listed", tItem ~= nil, true)
tItem.button:GetScript("OnClick")(tItem.button)
check("saved listing deleted", #ns.Listing.Templates(), 0)
check("its row gone", itemFor("RFC tank"), nil)
local w1 = rowFor("Whisper 1", "edit")
check("default whisper shown", w1 ~= nil and w1.edit:GetText(), Settings.DEFAULTS.whisperTemplates[1])
check("no second whisper row", rowFor("Whisper 2", "edit"), nil)
local newW = rowFor("New whisper", "edit")
newW.edit:SetText("Need a {role}?")
newW.edit:GetScript("OnEnterPressed")(newW.edit)
check("whisper added", S("whisperTemplates")[2], "Need a {role}?")
check("second whisper row", rowFor("Whisper 2", "edit") ~= nil, true)
w1.edit:SetText("Hello {class}")
w1.edit:GetScript("OnEnterPressed")(w1.edit)
check("whisper edited", S("whisperTemplates")[1], "Hello {class}")
w1.edit:SetText("")
w1.edit:GetScript("OnEnterPressed")(w1.edit)
check("emptied whisper removed", table.concat(S("whisperTemplates"), "|"), "Need a {role}?")
local defaultsButton
for _, f in ipairs(M.frames) do
    if f.text and f.text._text == "Default whispers" and f:IsVisible() then defaultsButton = f end
end
defaultsButton:GetScript("OnClick")(defaultsButton)
check("whispers back to the default: nothing stored", ns.DB().whisperTemplates, nil)
check("nothing left over in the profile", next(ns.DB()), nil)
ns.Options.Toggle()
check("closed", ns.Options.IsShown(), false)
check("interface options page", M.registered[1], "Forever Group Finder")

section("Minimap button, compartment and slash command")
-- The window opens and would search; the finder is unavailable here, so no
-- search is started before the Finder tests.
M.lfg.canUse = false
local mb = M.byName["ForeverGroupFinderMinimapButton"]
check("minimap button", mb ~= nil, true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click locks", S("locked"), true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click unlocks", S("locked"), false)
mb:GetScript("OnClick")(mb, "LeftButton")
check("left-click opens the window", ns.Window.IsShown(), true)
mb:GetScript("OnClick")(mb, "LeftButton")
check("left-click closes the window", ns.Window.IsShown(), false)
Settings.Set("minimapShow", false)
check("minimap button hidden by the setting", mb:IsShown(), false)
Settings.Set("minimapShow", nil)
check("shown again", mb:IsShown(), true)
Settings.Set("minimapAngle", 100)
check("angle is stored", ns.DB().minimapAngle, 100)
Settings.Set("minimapAngle", nil)
check("compartment click", type(ForeverGroupFinder_OnAddonCompartmentClick), "function")
check("compartment enter", type(ForeverGroupFinder_OnAddonCompartmentEnter), "function")
check("compartment leave", type(ForeverGroupFinder_OnAddonCompartmentLeave), "function")
ForeverGroupFinder_OnAddonCompartmentClick(nil, "LeftButton")
check("compartment left-click toggles the window", ns.Window.IsShown(), true)
ns.Window.Hide()
ForeverGroupFinder_OnAddonCompartmentClick(nil, "RightButton")
check("compartment right-click locks", S("locked"), true)
ForeverGroupFinder_OnAddonCompartmentClick(nil, "RightButton")
check("compartment tooltip", pcall(ForeverGroupFinder_OnAddonCompartmentEnter, nil, CreateFrame("Frame")), true)
check("compartment tooltip leave", pcall(ForeverGroupFinder_OnAddonCompartmentLeave, nil, CreateFrame("Frame")), true)
-- The setting takes our entry out of a compartment list and puts it back.
AddonCompartmentFrame = { registeredAddons = { { text = "Other" }, { text = "Forever Group Finder" } },
    UpdateDisplay = function() end }
Settings.Set("compartment", false)
check("compartment entry removed", #AddonCompartmentFrame.registeredAddons, 1)
check("the other entry stays", AddonCompartmentFrame.registeredAddons[1].text, "Other")
Settings.Set("compartment", nil)
check("compartment entry back", #AddonCompartmentFrame.registeredAddons, 2)
AddonCompartmentFrame = nil
check("no compartment frame is fine", pcall(Settings.Set, "compartment", false), true)
Settings.Set("compartment", nil)

check("/fgf slash", SLASH_FOREVERGROUPFINDER1, "/fgf")
check("/forevergroupfinder slash", SLASH_FOREVERGROUPFINDER2, "/forevergroupfinder")
local function words(msg)
    local command, args = ns.ParseCommand(msg)
    return command .. "|" .. table.concat(args, ",")
end
check("parse: empty", words(""), "|")
check("parse: nil", words(nil), "|")
check("parse: spaces", words("   "), "|")
check("parse: lower-cased", words("  LOCK  "), "lock|")
check("parse: arguments", words("options  general now"), "options|general,now")
SlashCmdList["FOREVERGROUPFINDER"]("")
check("/fgf toggles the window", ns.Window.IsShown(), true)
SlashCmdList["FOREVERGROUPFINDER"]("")
check("/fgf toggles it back", ns.Window.IsShown(), false)
SlashCmdList["FOREVERGROUPFINDER"]("options")
check("/fgf options opens the options", ns.Options.IsShown(), true)
ns.Options.Toggle()
SlashCmdList["FOREVERGROUPFINDER"]("lock")
check("/fgf lock", S("locked"), true)
SlashCmdList["FOREVERGROUPFINDER"]("unlock")
check("/fgf unlock", S("locked"), false)
SlashCmdList["FOREVERGROUPFINDER"]("LOCK")
check("/fgf is case-insensitive", S("locked"), true)
SlashCmdList["FOREVERGROUPFINDER"]("unlock")
Settings.SetMany({ x = 300, y = 5, width = 900, height = 700, scale = 120, point = "TOP" })
SlashCmdList["FOREVERGROUPFINDER"]("reset")
check("/fgf reset: x", S("x"), 0)
check("/fgf reset: y", S("y"), 40)
check("/fgf reset: size", S("width") + S("height") + S("scale"), 720 + 460 + 100)
check("/fgf reset: point", S("point"), "CENTER")
check("/fgf reset keeps the rest", (function()
    Settings.Set("minimapShow", false)
    SlashCmdList["FOREVERGROUPFINDER"]("reset")
    local kept = S("minimapShow")
    Settings.Set("minimapShow", nil)
    return kept
end)(), false)
check("/fgf reset stores nothing", next(ns.DB()), nil)
SlashCmdList["FOREVERGROUPFINDER"]("search")
check("/fgf search opens the window", ns.Window.IsShown(), true)
check("/fgf search again keeps it open", pcall(SlashCmdList["FOREVERGROUPFINDER"], "search") and ns.Window.IsShown(), true)
ns.Window.Hide()
M.chat = {}
SlashCmdList["FOREVERGROUPFINDER"]("ignore Grumpy-Realm")
check("/fgf ignore", ns.Memory.IsIgnored("Grumpy-Realm"), true)
check("/fgf ignore keeps the case", ns.Memory.IsIgnored("grumpy-realm"), false)
check("/fgf ignore says so", M.chat[1] ~= nil and M.chat[1]:find("Grumpy-Realm is ignored", 1, true) ~= nil, true)
SlashCmdList["FOREVERGROUPFINDER"]("UNIGNORE Grumpy-Realm")
check("/fgf unignore", ns.Memory.IsIgnored("Grumpy-Realm"), false)
check("/fgf unignore says so", M.chat[2] ~= nil and M.chat[2]:find("no longer ignored", 1, true) ~= nil, true)
SlashCmdList["FOREVERGROUPFINDER"]("unignore Grumpy-Realm")
check("/fgf unignore of someone not ignored", M.chat[3] ~= nil and M.chat[3]:find("not on the ignore list", 1, true) ~= nil, true)
SlashCmdList["FOREVERGROUPFINDER"]("ignore")
check("/fgf ignore without a name", M.chat[4] ~= nil and M.chat[4]:find("/fgf ignore <name>", 1, true) ~= nil, true)
SlashCmdList["FOREVERGROUPFINDER"]("unignore")
check("/fgf unignore without a name", M.chat[5] ~= nil and M.chat[5]:find("/fgf unignore <name>", 1, true) ~= nil, true)
check("nothing ignored", #ns.Memory.IgnoreList(), 0)
M.chat = {}
SlashCmdList["FOREVERGROUPFINDER"]("what")
check("usage", M.chat[1] ~= nil and M.chat[1]:find("/fgf", 1, true) ~= nil, true)
check("usage names the new commands", M.chat[1]:find("search, ignore <name>, unignore <name>", 1, true) ~= nil, true)

M.lfg.canUse = true
section("Events and combat")
local fired = 0
check("the client would reject the event", pcall(CreateFrame("Frame").RegisterEvent, CreateFrame("Frame"), "SOME_UNKNOWN_EVENT"), false)
check("ns.On survives an unknown event", (pcall(ns.On, "SOME_UNKNOWN_EVENT", function() fired = fired + 1 end)), true)
ns.On("PLAYER_ENTERING_WORLD", function() fired = fired + 1 end)
M.Fire("PLAYER_ENTERING_WORLD")
check("ns.On delivers", fired, 1)
check("AfterCombat runs at once out of combat", (function()
    local now = 0
    ns.AfterCombat("now", function() now = 1 end)
    return now
end)(), 1)
M.state.combat = true
local ran = 0
ns.AfterCombat("k", function() ran = ran + 1 end)
ns.AfterCombat("k", function() ran = ran + 10 end)
check("deferred in combat", ran, 0)
check("pending", ns.PendingAfterCombat(), 1)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("runs after combat (the last one under a key)", ran, 10)

section("Mock secrets")
local sv = M.Secret(5)
check("issecretvalue", issecretvalue(sv), true)
check("plain is not secret", issecretvalue(5), false)
check("compare raises", pcall(function() return sv < 3 end), false)
check("secret vs secret raises", pcall(function() return sv == M.Secret(5) end), false)
check("arithmetic raises", pcall(function() return sv + 1 end), false)
check("concatenation raises", pcall(function() return "x" .. sv end), false)
check("%d raises", pcall(string.format, "%d", sv), false)
check("%.0f is allowed", M.Reveal(string.format("%.0f", sv)), "5")
check("%s is allowed", M.Reveal(("<%s>"):format(M.Secret("Bob"))), "<Bob>")
check("a formatted secret stays secret", issecretvalue(string.format("%s", M.Secret("Bob"))), true)
check("secret key found", M.FindSecretKey({ a = { [sv] = 1 } }) ~= nil, true)

local Format, Meter = ns.Format, ns.Meter
local function revealed(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok then return "ERROR: " .. tostring(v) end
    return M.Reveal(v)
end


section("Languages")
local base = ns.Locales.enUS
local languages = 0
for code, strings in pairs(ns.Locales) do
    languages = languages + 1
    for key in pairs(base) do check(code .. " has " .. key, strings[key] ~= nil, true) end
    for key in pairs(strings) do check(code .. ": " .. key .. " is known", base[key] ~= nil, true) end
    for key, value in pairs(base) do
        local want = select(2, value:gsub("%%[ds]", ""))
        local got = strings[key] and select(2, strings[key]:gsub("%%[ds]", "")) or want
        check(code .. ": placeholders of " .. key, got, want)
        local braces = {}
        for name in value:gmatch("{%w+}") do braces[#braces + 1] = name end
        for _, name in ipairs(braces) do
            check(code .. ": " .. name .. " kept in " .. key, strings[key] and strings[key]:find(name, 1, true) ~= nil, true)
        end
    end
    for key, value in pairs(strings) do
        check(code .. ": " .. key .. " is not empty", value ~= "", true)
    end
end
check("four languages", languages, 4)
check("language choices", #ns.Locale.CHOICES, 4)
for _, choice in ipairs(ns.Locale.CHOICES) do check("choice " .. choice.value .. " exists", ns.Locales[choice.value] ~= nil, true) end
for _, strings in pairs(ns.Locales) do
    check("addon name", strings.ADDON_NAME, "Forever Group Finder")
    for key, value in pairs(strings) do
        check("no combat meter leftovers in " .. key, value:find("Combat Meter", 1, true) or value:find("/fcm", 1, true)
            or value:find("Quest Log", 1, true) or value:find("/fql", 1, true), nil)
    end
end
for key, value in pairs(ns.Locales.deDE) do
    for _, bad in ipairs({ "oess", "oesch", "oehe", "aende", "ueber", "fuer", "Rueck", "schliess" }) do
        check("no umlaut workaround in " .. key .. " (" .. bad .. ")", value:find(bad), nil)
    end
end
-- Every key the code uses exists in English.
local keysUsed = 0
for _, f in ipairs(tocFiles()) do
    local src = read(f)
    for key in src:gmatch("L%.([A-Z][A-Z0-9_]+)") do check(f .. " uses known L." .. key, base[key] ~= nil, true) end
    for key in src:gmatch('"([A-Z]+_[A-Z0-9_]+)"') do
        local prefix = key:match("^(%u+)_")
        if prefix == "OPT" or prefix == "PAGE" or prefix == "STYLE" or prefix == "TIP" or prefix == "MSG" then
            keysUsed = keysUsed + 1
            check(f .. " uses known " .. key, base[key] ~= nil, true)
        end
    end
end
check("label keys are found in the code", keysUsed > 10, true)
-- Every setting that will get a label has one.
for _, name in ipairs(Settings.TEXT_STYLES) do check("style label " .. name, base["STYLE_" .. name:upper()] ~= nil, true) end

section("Finder")
local F, lfg = ns.Finder, M.lfg
check("Finder exists", F ~= nil, true)
lfg.reset()
M.state.time = 5000
local function res(id, extra)
    local r = { searchResultID = id, activityIDs = { 4 }, leaderName = "Lead" .. id, comment = "tank pls", numMembers = 2,
        age = 30, numCharFriends = 1, numBNetFriends = 2, numGuildMates = 3, isDelisted = false, voiceMode = 0,
        newPlayerFriendly = true }
    for k, v in pairs(extra or {}) do r[k] = v end
    lfg.results[id] = r
    lfg.members[id] = { { name = "Lead" .. id, level = 60, classFilename = "WARRIOR", assignedRole = "TANK",
        lfgRoles = { tank = true, healer = false, dps = false }, areaName = "Ragefire Chasm", isLeader = true },
        { name = "Mate", level = 58, classFilename = "MAGE", assignedRole = "DAMAGER",
        lfgRoles = { tank = false, healer = false, dps = true }, areaName = "Orgrimmar", isLeader = false } }
    lfg.counts[id] = { TANK = 1, HEALER = 0, DAMAGER = 1, TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2 }
end

-- search: click gate, throttle, pending, language filter
check("no search yet", F.LastSearchAge(), nil)
check("not searching", F.IsSearching(), false)
local ok, why = lfg.click(F.Search, { categoryID = 2, activityIDs = { 4, 5 } })
check("search accepted", ok, true)
check("search reached the client", #lfg.searches, 1)
check("category passed", lfg.searches[1][1], 2)
check("filters are 0", lfg.searches[1][2] == 0 and lfg.searches[1][3] == 0, true)
check("no language filter when none given", lfg.searches[1][4], nil)
check("cross faction off", lfg.searches[1][5], false)
check("no advanced filter", lfg.searches[1][6], nil)
check("activities passed", lfg.searches[1][7][2], 5)
check("searching", F.IsSearching(), true)
check("age 0 right after", F.LastSearchAge(), 0)
ok, why = lfg.click(F.Search, { categoryID = 2, activityIDs = {} })
check("pending refused", ok, false)
check("pending reason", why, "pending")
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("results end the search", F.IsSearching(), false)
M.state.time = 5000.5
ok, why = lfg.click(F.Search, { categoryID = 2, activityIDs = {} })
check("throttled refused", ok, false)
check("throttled reason", why, "throttled")
check("age counts up", F.LastSearchAge(), 0.5)
M.state.time = 5003
ok = lfg.click(F.Search, { categoryID = 114, activityIDs = {}, languages = {} })
check("after the interval", ok, true)
check("empty activity list searches the whole category", lfg.searches[2][7], nil)
check("empty language set builds no filter", lfg.searches[2][4], nil)
M.Fire("LFG_LIST_SEARCH_FAILED", "throttled")
M.state.time = 5010
ok = lfg.click(F.Search, { categoryID = 2, activityIDs = { 4 }, languages = { deDE = true, enUS = true } })
check("language search accepted", ok, true)
check("language filter is a table of bools", lfg.searches[3][4].deDE, true)
check("language filter keeps every locale", lfg.searches[3][4].enUS, true)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
M.state.time = 5020
ok = F.Search({ categoryID = 2, activityIDs = { 4 } })
check("a search without a click does nothing in the client", #lfg.searches, 3)
check("... and is recorded as blocked", lfg.blocked[#lfg.blocked], "Search")
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
M.state.time = 5100
ok = lfg.click(F.Search, { categoryID = 2, activityIDs = { 4 } })
M.state.time = 5101
ok, why = lfg.click(F.Search, { categoryID = 2, activityIDs = { 4 } })
check("pending", why, "pending")
M.state.time = 5120
ok = lfg.click(F.Search, { categoryID = 2, activityIDs = { 4 } })
check("a search the client swallowed does not block forever", ok, true)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

-- results
lfg.reset()
res(11); res(12, { numMembers = 1 }); lfg.results[13] = nil
local got = F.Results()
check("two results", #got, 2)
local r = got[1]
check("id", r.id, 11)
check("activities", r.activityIDs[1], 4)
check("leader", r.leaderName, "Lead11")
check("comment", r.comment, "tank pls")
check("members count", r.numMembers, 2)
check("age", r.age, 30)
check("friends = char + bnet", r.friends, 3)
check("guild", r.guild, 3)
check("delisted", r.isDelisted, false)
check("voice", r.voiceMode, 0)
check("new player friendly", r.newPlayerFriendly, true)
check("two members", #r.members, 2)
check("member name", r.members[1].name, "Lead11")
check("member level", r.members[2].level, 58)
check("member class", r.members[1].classFile, "WARRIOR")
check("member role", r.members[1].role, "TANK")
check("member wanted roles", r.members[2].lfgRoles.dps, true)
check("member area", r.members[2].area, "Orgrimmar")
check("member leader", r.members[1].isLeader, true)
check("counts", r.counts.TANK, 1)
check("counts remaining", r.counts.DAMAGER_REMAINING, 2)
check("members follow numMembers", #got[2].members, 1)
lfg.members[12] = { lfg.members[12][1] }
check("Result(id)", F.Result(12).members[1].name, "Lead12")
check("Result(gone)", F.Result(99), nil)
lfg.results[14] = { searchResultID = 14 }
check("sparse result survives", F.Result(14).leaderName, nil)
check("sparse result has a friends number", F.Result(14).friends, 0)
lfg.results[14] = nil

-- secret mode
lfg.secret = true
local sr = F.Result(11)
check("secret mode still gives a table", sr ~= nil, true)
check("secret leader becomes nil", sr.leaderName, nil)
check("secret comment becomes nil", sr.comment, nil)
check("secret age becomes nil", sr.age, nil)
check("secret friends nil", sr.friends, nil)
check("secret members: none can be listed", #sr.members, 0)
check("secret counts nil", sr.counts.TANK, nil)
check("secret mode, whole list", #F.Results(), 2)
check("no secret leaks into the data", M.FindSecretKey(F.Results()), nil)
check("no secret value anywhere", (function()
    local function walk(t) for _, v in pairs(t) do if M.IsSecret(v) or (type(v) == "table" and walk(v)) then return true end end end
    return walk(F.Results()) or false
end)(), false)
lfg.secret = false
-- events
local seen = {}
for _, e in ipairs({ "RESULTS", "RESULT_UPDATED", "FAILED", "ACTIVE_ENTRY", "AVAILABILITY", "EXPIRED" }) do
    F.On(e, function(...) seen[#seen + 1] = { e, ... } end)
end
F.On("RESULTS", function() seen[#seen + 1] = { "second" } end)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("RESULTS", seen[1][1], "RESULTS")
check("every listener hears it", seen[2][1], "second")
M.Fire("LFG_LIST_SEARCH_RESULT_UPDATED", 11)
check("RESULT_UPDATED id", seen[3][2], 11)
M.Fire("LFG_LIST_SEARCH_FAILED", "boom")
check("FAILED reason", seen[4][2], "boom")
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE", true)
check("ACTIVE_ENTRY", seen[5][1], "ACTIVE_ENTRY")
M.Fire("LFG_LIST_AVAILABILITY_UPDATE")
check("AVAILABILITY", seen[6][1], "AVAILABILITY")
M.Fire("LFG_LIST_ENTRY_EXPIRED_TIMEOUT")
check("EXPIRED (timeout)", seen[7][1], "EXPIRED")
M.Fire("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")
check("EXPIRED (too many)", seen[8][1], "EXPIRED")
check("a throwing listener does not stop the others", (function()
    F.On("RESULTS", function() error("bad listener") end)
    local n = #seen
    M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    return #seen - n
end)(), 2)

-- listing
lfg.reset()
check("no active entry", F.ActiveEntry(), nil)
local entry = { activityIDs = { 4, 5 }, newPlayerFriendly = true, generalPlaystyle = 0, voiceMode = 1,
    roles = { tank = false, healer = true, dps = false } }
check("create outside a click fails", F.CreateOrUpdate(entry), false)
check("create blocked is recorded", lfg.blocked[#lfg.blocked], "CreateListing")
check("roles not saved when it failed", lfg.roles, nil)
check("create in a click", lfg.click(F.CreateOrUpdate, entry), true)
check("create called", #lfg.creates, 1)
check("create activities", lfg.creates[1].activityIDs[2], 5)
check("create flags", lfg.creates[1].newPlayerFriendly, true)
check("create playstyle", lfg.creates[1].generalPlaystyle, 0)
check("create voice", lfg.creates[1].voiceMode, 1)
check("roles saved", lfg.roles.healer, true)
local a = F.ActiveEntry()
check("active entry activities", a.activityIDs[1], 4)
check("active entry duration", a.duration, 3600)
check("active entry comment", a.comment, "")
check("active entry flag", a.newPlayerFriendly, true)
check("second call updates", lfg.click(F.CreateOrUpdate, { activityIDs = { 4 }, newPlayerFriendly = false }), true)
check("no second create", #lfg.creates, 1)
check("update called", #lfg.updates, 1)
check("update has no playstyle key", lfg.updates[1].generalPlaystyle, nil)
check("roles untouched without entry.roles", lfg.roles.healer, true)
lfg.secret = true
local sa = F.ActiveEntry()
check("secret active entry: activities (never secret)", sa.activityIDs[1], 4)
check("secret active entry: duration nil", sa.duration, nil)
check("secret active entry: no secret inside", M.IsSecret(sa.comment), false)
lfg.secret = false
F.Remove()
check("remove", lfg.removed, 1)
check("entry gone", F.ActiveEntry(), nil)
lfg.createOK = false
check("a refused create reports false", lfg.click(F.CreateOrUpdate, entry), false)
lfg.createOK = true

-- misc
check("invite", (function() F.Invite("Bob-Realm"); return M.invited[#M.invited] end)(), "Bob-Realm")
F.Whisper("Bob", "hi there")
check("whisper with text", M.tells[#M.tells].text, "hi there")
check("whisper name", M.tells[#M.tells].name, "Bob")
F.Whisper("Ann")
check("whisper without text", M.tells[#M.tells].name .. ":" .. tostring(M.tells[#M.tells].text), "Ann:nil")
check("CanUse", select(1, F.CanUse()), true)
lfg.canUse, lfg.failure = false, "Too low"
local cu, cr = F.CanUse()
check("CanUse false", cu, false)
check("CanUse reason", cr, "Too low")
lfg.canUse = true
check("CanComment false", F.CanComment(2), false)
lfg.authenticated[2] = true
check("CanComment true", F.CanComment(2), true)
local saved = C_LFGList.IsPlayerAuthenticatedForLFG
C_LFGList.IsPlayerAuthenticatedForLFG = nil
check("CanComment guarded when the API is missing", F.CanComment(2), false)
C_LFGList.IsPlayerAuthenticatedForLFG = saved
lfg.reset()

section("Activities")
lfg.reset()
local A = ns.Activities
check("Activities exists", A ~= nil, true)
lfg.cats = { 120, 118, 2, 114 }
lfg.catNames = { [2] = "Dungeons (API)", [114] = "", [118] = "Battlegrounds", [120] = "Custom" }
local cats = A.Categories()
local ids = {}
for _, c in ipairs(cats) do ids[#ids + 1] = c.id end
check("category order, only available", table.concat(ids, ","), "2,114,118,120")
check("category name from the API", cats[1].name, "Dungeons (API)")
check("empty API name falls back to the locale", cats[2].name, ns.L.CATEGORY_114)
lfg.cats = { 116 }
check("missing category info falls back", A.Categories()[1].name, ns.L.CATEGORY_116)
lfg.cats = {}
check("no categories", #A.Categories(), 0)
check("every locale names the five categories", (function()
    for _, s in pairs(ns.Locales) do
        for _, id in ipairs({ 2, 114, 116, 118, 120 }) do if not s["CATEGORY_" .. id] then return id end end
    end
    return true
end)(), true)
check("Finder.Categories", (function() lfg.cats = { 2, 114 }; return #F.Categories() end)(), 2)
check("Finder.CategoryInfo unknown", F.CategoryInfo(5), nil)
lfg.catNames[2] = "D"
check("Finder.CategoryInfo name", F.CategoryInfo(2).name, "D")

local function act(id, g, full, short, lo, hi, max)
    lfg.activities[id] = { categoryID = 2, groupFinderActivityGroupID = g, fullName = full, shortName = short,
        minLevelSuggestion = lo, maxLevelSuggestion = hi, maxNumPlayers = max }
end
lfg.groups = { [10] = { name = "Classic", order = 1 } }
act(1, 10, "Ragefire Chasm", "RFC", 13, 18, 5)
act(2, 10, "Deadmines", "", 17, 24, 5)
act(3, 10, "Stratholme", "Strat", 58, 0, 5)
act(4, 10, "Anyone Welcome", "Any", 0, 0, 5)
act(5, 10, "Blackfathom Deeps", "BFD", 20, 30, 5)
act(6, 10, "Wailing Caverns", "WC", 17, 24, 5)
check("Finder.ActivityInfo", F.ActivityInfo(1).fullName, "Ragefire Chasm")
check("Finder.ActivityInfo unknown", F.ActivityInfo(99), nil)
check("Finder.Activities", #F.Activities(2), 6)
check("Finder.Activities other category", #F.Activities(114), 0)
check("Finder.ActivityGroupName", F.ActivityGroupName(10), "Classic")
lfg.secret = true
check("Finder.ActivityInfo hides secrets", F.ActivityInfo(1).fullName, nil)
lfg.secret = false

local info = A.Info(1)
check("info name", info.name, "Ragefire Chasm")
check("info short", info.shortName, "RFC")
check("info levels", info.minLevel .. "-" .. info.maxLevel, "13-18")
check("info players", info.maxPlayers, 5)
check("info group", info.groupName, "Classic")
check("empty short name falls back to the name", A.Info(2).shortName, "Deadmines")
check("name", A.Name(1), "Ragefire Chasm")
check("unknown activity", A.Info(99), nil)
check("unknown name", A.Name(99), nil)

-- fit at the boundaries
local rfc = A.Info(1)
check("fit below min", A.Fit(rfc, 12), "HIGH")
check("fit at min", A.Fit(rfc, 13), "FITS")
check("fit at max", A.Fit(rfc, 18), "FITS")
check("fit above max", A.Fit(rfc, 19), "LOW")
check("open-ended max", A.Fit(A.Info(3), 70), "FITS")
check("open-ended range", A.Fit(A.Info(4), 1), "FITS")

local function listIDs(opts)
    local out = {}
    for _, a in ipairs(A.List(2, opts)) do out[#out + 1] = a.id end
    return table.concat(out, ",")
end
lfg.level = 20
check("fit in the list", A.List(2)[1].fit, "FITS")
-- level 20: FITS = 2,4,5,6 (4: minLevel 0); RFC LOW; Strat HIGH
check("sorted FITS first, then minLevel, then name", listIDs(), "4,2,6,5,1,3")
check("list entry fields", (function()
    local e = A.List(2, { text = "bfd" })[1]
    return e.name .. "|" .. e.shortName .. "|" .. e.minLevel .. "|" .. e.maxLevel .. "|" .. e.maxPlayers .. "|" .. e.groupName .. "|" .. e.fit
end)(), "Blackfathom Deeps|BFD|20|30|5|Classic|FITS")
check("switch on keeps only FITS", listIDs({ levelRangeOnly = true }), "4,2,6,5")
check("switch off keeps all", listIDs({ levelRangeOnly = false }), "4,2,6,5,1,3")
check("LOW and HIGH are classified", (function()
    local f = {}
    for _, a in ipairs(A.List(2)) do f[a.id] = a.fit end
    return f[1] .. f[3]
end)(), "LOWHIGH")
check("text matches the name, any case", listIDs({ text = "DEAD" }), "2")
check("text matches the short name", listIDs({ text = "strat" }), "3")
check("text with the switch", listIDs({ text = "strat", levelRangeOnly = true }), "")
check("text is plain, not a pattern", listIDs({ text = "." }), "")
check("empty text matches all", listIDs({ text = "" }), "4,2,6,5,1,3")
lfg.level = 70
check("level 70", listIDs({ levelRangeOnly = true }), "4,3")

-- cache refresh
check("unknown before it exists", A.Info(7), nil)
act(7, 10, "New Place", "NP", 1, 0, 5)
check("a miss is cached until a refresh", A.Info(7), nil)
M.Fire("LFG_LIST_AVAILABILITY_UPDATE")
check("availability refreshes the cache", A.Info(7).name, "New Place")
lfg.activities[7].fullName = "Renamed"
check("cache holds", A.Name(7), "New Place")
M.Fire("PLAYER_LEVEL_UP")
check("level up refreshes the cache", A.Name(7), "Renamed")

section("Abbreviations")
do
local A = ns.Abbrev
local function ab(name, mapID, short) return A.For({ name = name, mapID = mapID, shortName = short or name }) end
-- (1) by the instance's mapID, whatever the language
check("map: RFC", ab("Sima de Fuego", 389), "RFC")
check("map: Deadmines", ab("Les Mortemines", 36), "DM")
check("map: SFK", ab("Burg Schattenfang", 33), "SFK")
check("map: Stocks", ab("The Stockade", 34), "Stocks")
check("map: Gnomer", ab("Gnomeregan", 90), "Gnomer")
check("map: SM Graveyard", ab("Scarlet Monastery - Graveyard", 189), "SM GY")
check("map: SM Library", ab("Scarlet Monastery - Library", 189), "SM Lib")
check("map: SM Armory", ab("Scarlet Monastery - Armory", 189), "SM Arm")
check("map: SM Cathedral", ab("Scarlet Monastery - Cathedral", 189), "SM Cath")
check("map: LBRS", ab("Lower Blackrock Spire", 229), "LBRS")
check("map: UBRS", ab("Upper Blackrock Spire", 229), "UBRS")
check("map: DM East", ab("Dire Maul - East", 429), "DME")
check("map: DM West", ab("Dire Maul - West", 429), "DMW")
check("map: DM North", ab("Dire Maul - North", 429), "DMN")
check("map: Strat Live", ab("Stratholme - Live", 329), "Strat Live")
check("map: Strat UD", ab("Stratholme - Undead", 329), "Strat UD")
check("map: Strat without a wing", ab("Stratholme", 329), "Strat")
check("map: Scholo", ab("Scholomance", 289), "Scholo")
for mapID, want in pairs({ [409] = "MC", [249] = "Ony", [469] = "BWL", [309] = "ZG", [509] = "AQ20", [531] = "AQ40",
    [533] = "Naxx", [43] = "WC", [48] = "BFD", [47] = "RFK", [129] = "RFD", [70] = "Ulda", [209] = "ZF",
    [349] = "Mara", [109] = "ST", [230] = "BRD" }) do
    check("map " .. mapID, ab("x", mapID), want)
end
-- (2) by the English name (no or unknown mapID), case-insensitive
check("name: Wailing Caverns", ab("Wailing Caverns", nil, "Wailing Caverns"), "WC")
check("name: case-insensitive", ab("THE DEADMINES"), "DM")
check("name: unknown mapID falls back", ab("Molten Core", 99999), "MC")
check("name: SM wing", ab("Scarlet Monastery: Library"), "SM Lib")
check("name: Dire Maul wing", ab("Dire Maul North"), "DMN")
for name, want in pairs({ ["Ruins of Lordaeron"] = "RoL", ["Hall of Thanes"] = "HoT", ["Excavation Site"] = "Excav",
    ["City of Dalaran"] = "Dala", ["The Drowned City"] = "Drowned", ["Krol'dok Stronghold"] = "Krol'dok",
    ["Alcaz Island Prison"] = "Alcaz", ["Blackmaw Hold"] = "Blackmaw", ["Shaper's Terrace"] = "Shaper's" }) do
    check("Forever: " .. name, ab(name), want)
end
-- (3) the client's short name when short, else initials
check("short name used", ab("Some Long Zone Quests", nil, "SLZQ"), "SLZQ")
check("long short name: initials", ab("Hall of Something Else", nil, "Hall of Something Else"), "HSE")
check("initials skip of / the", A.Initials("The Hall of Kings"), "HK")
check("a short full name stays", ab("Duskwood"), "Duskwood")
check("nil info", A.For(nil), nil)
-- The setting.
lfg.activities[22] = lfg.activities[22] or { categoryID = 2, fullName = "The Deadmines", shortName = "DM", minLevelSuggestion = 18, maxLevelSuggestion = 23, maxNumPlayers = 5 }
check("chip text abbreviated by default", A.Chip(22), "DM")
Settings.Set("abbreviate", false)
check("setting off: full name", A.Chip(22), "The Deadmines")
Settings.Set("abbreviate", nil)
check("unknown activity", A.Chip(987654), "Unknown activity")
end

section("Memory")
local Mem = ns.Memory
check("Memory exists", Mem ~= nil, true)
local clock = 1000000
Mem.now = function() return clock end
check("key", Mem.Key({ leaderName = "Anna", activityIDs = { 5, 2, 9 } }), "Anna|2,5,9")
check("key without leader", Mem.Key({ activityIDs = { 1 } }), nil)
check("key without activities", Mem.Key({ leaderName = "Anna" }), "Anna|")
check("key does not reorder the input", (function()
    local r = { leaderName = "B", activityIDs = { 3, 1 } }
    Mem.Key(r)
    return r.activityIDs[1]
end)(), 3)
check("nil key is never seen", Mem.IsSeen(nil), false)
Mem.MarkSeen("Anna|2")
check("seen", Mem.IsSeen("Anna|2"), true)
check("not seen", Mem.IsSeen("Bob|2"), false)
Mem.MarkSeen(nil)
Mem.Hide("Bob|3")
check("hidden", Mem.IsHidden("Bob|3"), true)
check("hidden is not seen", Mem.IsSeen("Bob|3"), false)
clock = clock + 29 * 60
check("seen holds before the limit", Mem.IsSeen("Anna|2"), true)
check("hidden holds before the limit", Mem.IsHidden("Bob|3"), true)
clock = clock + 2 * 60
check("seen expires", Mem.IsSeen("Anna|2"), false)
check("hidden expires", Mem.IsHidden("Bob|3"), false)
check("expired entries are pruned", next(ns.AccountDB().memory.seen), nil)
Settings.Set("memoryMinutes", 60)
Mem.MarkSeen("C|1")
clock = clock + 45 * 60
check("limit follows the setting", Mem.IsSeen("C|1"), true)
Settings.Set("memoryMinutes", nil)
check("shorter setting expires it", Mem.IsSeen("C|1"), false)
Mem.Ignore("Zed")
Mem.Ignore("Abe")
check("ignored", Mem.IsIgnored("Zed"), true)
check("not ignored", Mem.IsIgnored("Y"), false)
check("ignore of nil", Mem.IsIgnored(nil), false)
clock = clock + 1000 * 3600
check("ignore is permanent", Mem.IsIgnored("Zed"), true)
check("ignore list sorted", table.concat(Mem.IgnoreList(), ","), "Abe,Zed")
Mem.Unignore("Zed")
check("unignored", Mem.IsIgnored("Zed"), false)
check("stored account wide", ns.AccountDB().memory.ignore.Abe, true)
check("export carries no memory", ns.Share.Export():find("memory", 1, true), nil)
check("import leaves memory alone", (function()
    ns.Share.Import(ns.Share.Export())
    return Mem.IsIgnored("Abe")
end)(), true)
check("decoded profile drops memory", ns.Share.Decode("FGF1:ts6:memoryt}}").memory, nil)
Mem.Unignore("Abe")
do
    local m = ns.AccountDB().memory
    m.seen = {}; m.hidden = {}
    Mem.MarkSeen("Old|1"); Mem.Hide("Old|2")
    clock = clock + 31 * 60
    Mem.MarkSeen("New|1")
    check("marking prunes expired seen", m.seen["Old|1"], nil)
    check("marking prunes expired hidden", m.hidden["Old|2"], nil)
    check("marking keeps the new entry", m.seen["New|1"] ~= nil, true)
    m.seen["Old|3"] = clock - 3600; m.hidden["Old|4"] = clock - 3600
    M.Fire("PLAYER_LOGIN")
    check("login prunes seen", m.seen["Old|3"], nil)
    check("login prunes hidden", m.hidden["Old|4"], nil)
    check("login keeps fresh entries", m.seen["New|1"] ~= nil, true)
    clock = clock - 3600
    check("future timestamp is expired (seen)", Mem.IsSeen("New|1"), false)
    m.hidden["Fut|1"] = clock + 600
    Mem.Prune()
    check("future timestamp is pruned", m.hidden["Fut|1"], nil)
end

section("Results")
local R = ns.Results
check("Results exists", R ~= nil, true)
local function member(name, role) return { name = name, level = 60, classFile = "MAGE", role = role, area = "Elwynn", isLeader = true,
    lfgRoles = { tank = role == "TANK", healer = role == "HEALER", dps = role == "DAMAGER" } } end
local function group(id, leader, acts, o)
    o = o or {}
    local g = { id = id, activityIDs = acts, leaderName = leader, comment = o.comment, numMembers = o.n or 3, age = o.age or 10,
        friends = o.friends or 0, guild = o.guild or 0, isDelisted = o.delisted, members = { member(leader or "x", "TANK"), member("m2", "DAMAGER"), member("m3", "DAMAGER") },
        counts = { TANK = 1, HEALER = 0, DAMAGER = 2, TANK_REMAINING = o.tankFree or 0, HEALER_REMAINING = o.healFree or 1, DAMAGER_REMAINING = o.dpsFree or 0 } }
    return g
end
local function solo(id, name, acts, o)
    o = o or {}
    return { id = id, activityIDs = acts, leaderName = name, comment = o.comment, numMembers = 1, age = o.age or 5,
        friends = o.friends or 0, guild = o.guild or 0, members = { member(name, "HEALER") }, counts = {} }
end
local fits = { [1] = "FITS", [2] = "HIGH", [3] = "LOW" }
local ctx = function(c)
    c = c or {}
    return { myRoles = c.myRoles or { "HEALER" }, myLevel = 60, filters = c.filters or {}, activityFit = function(id) return fits[id] end }
end
local ids = function(rows) local t = {} for _, r in ipairs(rows) do t[#t + 1] = r.id end return table.concat(t, ",") end

local out = R.Build({ group(1, "A", { 1 }), solo(2, "B", { 1 }), group(3, "C", { 1 }) }, ctx())
check("split groups", ids(out.groups), "1,3")
check("split players", ids(out.players), "2")
check("row kind group", out.groups[1].kind, "GROUP")
check("row kind player", out.players[1].kind, "PLAYER")
check("row leader", out.groups[1].leader, "A")
check("row freeForMe", out.groups[1].freeForMe, true)
check("player area", out.players[1].area, "Elwynn")
check("player roles", out.players[1].roles.healer, true)
check("row delisted flag", R.Build({ group(1, "A", { 1 }, { delisted = true }) }, ctx()).groups[1].delisted, true)
check("one-member result with other members is a group", ids(R.Build({ { id = 9, activityIDs = { 1 }, leaderName = "Q", numMembers = 1,
    members = { member("Q", "TANK"), member("W", "TANK") }, counts = {} } }, ctx()).groups), "9")

-- filters
local mixed = { group(1, "A", { 1 }, { healFree = 0, dpsFree = 1 }), group(2, "B", { 1 }), solo(3, "S", { 1 }) }
check("no role filter keeps all", ids(R.Build(mixed, ctx()).groups), "2,1")
local byRole = R.Build(mixed, ctx({ filters = { myRole = true } }))
check("role filter drops full-for-me groups", ids(byRole.groups), "2")
check("role filter never touches players", ids(byRole.players), "3")
check("role filter follows the role", ids(R.Build(mixed, ctx({ myRoles = { "DAMAGER" }, filters = { myRole = true } })).groups), "1")
local lv = { group(1, "A", { 1 }), group(2, "B", { 2 }), group(3, "C", { 3 }), group(4, "D", { 2, 1 }), solo(5, "E", { 3 }) }
local lvl = R.Build(lv, ctx({ filters = { levelFits = true } }))
check("level filter groups", ids(lvl.groups), "1,4")
check("level filter players", ids(lvl.players), "")
check("best fit of several activities", R.Build(lv, ctx()).groups[1].fit, "FITS")
check("fit of a mismatch", (function() for _, r in ipairs(R.Build(lv, ctx()).groups) do if r.id == 2 then return r.fit end end end)(), "HIGH")
Mem.MarkSeen("A|1")
local seen = R.Build({ group(1, "A", { 1 }), group(2, "B", { 1 }) }, ctx({ filters = { hideSeen = true } }))
check("hide seen", ids(seen.groups), "2")
check("seen flag without the filter", R.Build({ group(1, "A", { 1 }) }, ctx()).groups[1].seen, true)
local txt = { group(1, "Alice", { 1 }, { comment = "Need healer for RFC" }), group(2, "Bob", { 2 }), group(3, "Carl", { 3 }) }
check("text in comment", ids(R.Build(txt, ctx({ filters = { text = "healer" } })).groups), "1")
check("text in leader", ids(R.Build(txt, ctx({ filters = { text = "BOB" } })).groups), "2")
Mem.Hide("Bob|2")
check("hidden key dropped", ids(R.Build(txt, ctx()).groups), "1,3")
Mem.Ignore("Carl")
check("ignored leader dropped", ids(R.Build(txt, ctx()).groups), "1")
check("ignored player dropped", ids(R.Build({ solo(1, "Carl", { 1 }) }, ctx()).players), "")
Mem.Unignore("Carl")
clock = clock + 100 * 3600
check("text in activity name", ids(R.Build({ group(1, "A", { 1 }), group(2, "B", { 2 }) },
    { myRoles = { "HEALER" }, myLevel = 60, filters = { text = "deadm" }, activityFit = function() return "FITS" end }).groups), "2")

-- sort
local sorted = R.Build({
    group(1, "A", { 1 }, { healFree = 0, age = 5 }),
    group(2, "B", { 2 }, { age = 5 }),
    group(3, "C", { 1 }, { age = 9 }),
    group(4, "D", { 1 }, { age = 2 }),
    group(5, "E", { 1 }, { age = 5, friends = 1 }),
    group(6, "F", { 3 }, { age = 1 }),
    group(7, "G", { 1 }, { age = 5, guild = 2, healFree = 0 }),
    group(8, "H", { 1 }, { age = 5 }),
}, ctx())
check("sort order", ids(sorted.groups), "5,7,4,8,3,2,6,1")
local noFriends = R.Build({ group(1, "A", { 1 }, { age = 3 }), group(2, "B", { 1 }, { age = 1, friends = 1 }) }, ctx())
check("friends first by default", ids(noFriends.groups), "2,1")
Settings.Set("sortFriendsFirst", false)
check("friends first can be off (order differs)", ids(R.Build({ group(1, "A", { 1 }, { age = 1 }), group(2, "B", { 1 }, { age = 3, friends = 1 }) }, ctx()).groups), "1,2")
check("friends off sorts by age", ids(R.Build({ group(1, "A", { 1 }, { age = 1 }), group(2, "B", { 1 }, { age = 3, friends = 1 }) }, ctx()).groups), "1,2")
Settings.Set("sortFriendsFirst", nil)
check("friends first back on", ids(R.Build({ group(1, "A", { 1 }, { age = 1 }), group(2, "B", { 1 }, { age = 3, friends = 1 }) }, ctx()).groups), "2,1")
check("ties by id", ids(R.Build({ group(8, "A", { 1 }), group(3, "B", { 1 }), group(5, "C", { 1 }) }, ctx()).groups), "3,5,8")

-- secret-nil fields
local holes = { id = 1, members = {}, counts = {} }
local ok, res = pcall(R.Build, { holes, { id = 2, numMembers = 3 }, { id = 3, activityIDs = {}, members = { { } }, numMembers = 1 } }, ctx({ filters = { text = "x", levelFits = true, myRole = true, hideSeen = true } }))
check("nil fields do not break filters", ok, true)
ok, res = pcall(R.Build, { holes, { id = 2 }, { id = 3, leaderName = "Z", members = { {} }, numMembers = 1 }, { id = 4, age = 3 } }, ctx())
check("nil fields do not break sort and rows", ok, true)
check("rows with holes are kept", #res.groups + #res.players, 4)
check("nil input", pcall(R.Build, nil, ctx()), true)

-- nil fit and default role
local unknown = R.Build({ group(1, "A", { 99 }, { age = 1 }), group(2, "B", { 3 }, { age = 9 }), group(3, "C", { 1 }, { age = 5 }) }, ctx())
check("unknown fit sorts last", ids(unknown.groups), "3,2,1")
check("unknown fit has no fit", unknown.groups[3].fit, nil)
check("levelFits keeps unknown activities", ids(R.Build({ group(1, "A", { 99 }), group(2, "B", { 3 }) }, ctx({ filters = { levelFits = true } })).groups), "1")
check("room for any of my roles", ids(R.Build({ group(1, "A", { 1 }, { healFree = 1, dpsFree = 0 }), group(2, "B", { 1 }, { healFree = 0, dpsFree = 1 }),
    group(3, "C", { 1 }, { healFree = 0, dpsFree = 0 }) }, ctx({ myRoles = { "HEALER", "DAMAGER" }, filters = { myRole = true } })).groups), "1,2")

-- My roles: only what the class can play, the selection per character.
local Ro = ns.Roles
local function roleSet(t) return (t.tank and "T" or "-") .. (t.healer and "H" or "-") .. (t.dps and "D" or "-") end
ForeverGroupFinderChar.roles = nil
UnitClass = function() return "Krieger", "WARRIOR" end
check("warrior: tank and dps", roleSet(Ro.Allowed()), "T-D")
UnitGroupRolesAssigned = nil
check("warrior default: first allowed (tank)", roleSet(Ro.Selected()), "T--")
check("text for tank", Ro.Text(), "Tank")
check("Results uses my roles", ids(R.Build({ group(1, "A", { 1 }, { tankFree = 1, healFree = 0, dpsFree = 0 }), group(2, "B", { 1 }, { healFree = 1, dpsFree = 0 }) },
    { myLevel = 60, filters = { myRole = true }, activityFit = function() return "FITS" end }).groups), "1")
UnitGroupRolesAssigned = function() return "DAMAGER" end
check("default from the assigned group role", roleSet(Ro.Selected()), "--D")
M.lfg.savedRoles = { tank = true, healer = true, dps = false }
check("default from Blizzard's saved roles, healer dropped", roleSet(Ro.Selected()), "T--")
M.lfg.savedRoles = nil
UnitGroupRolesAssigned = nil
check("healer is not allowed for a warrior", Ro.Toggle("healer"), false)
check("toggle dps on", Ro.Toggle("dps"), true)
check("tank and dps", roleSet(Ro.Selected()), "T-D")
check("stored per character", roleSet(ForeverGroupFinderChar.roles), "T-D")
check("text for two roles", Ro.Text(), "Tank/DPS")
check("toggle tank off", Ro.Toggle("tank"), true)
check("the last role stays", Ro.Toggle("dps"), false)
check("dps only", roleSet(Ro.Selected()), "--D")
UnitClass = function() return "Priester", "PRIEST" end
check("a stored role the class cannot play falls back", roleSet(Ro.Selected()), "--D")
check("priest: heal and dps", roleSet(Ro.Allowed()), "-HD")
UnitGetAvailableRoles = function() return true, false, false end
check("the client's answer wins", roleSet(Ro.Allowed()), "T--")
UnitGetAvailableRoles = function() return false, false, false end
check("an empty answer falls back to the class", roleSet(Ro.Allowed()), "-HD")
UnitGetAvailableRoles = nil
UnitClass = nil
check("unknown class: all roles", roleSet(Ro.Allowed()), "THD")
ForeverGroupFinderChar.roles = nil

section("Listing")
local Li = ns.Listing
local lfg = M.lfg
check("Listing exists", Li ~= nil, true)
lfg.reset()
lfg.cats = { 2 }
lfg.activities = {
    [11] = { categoryID = 2, fullName = "Ragefire Chasm", shortName = "RFC", minLevelSuggestion = 13, maxLevelSuggestion = 18, maxNumPlayers = 5 },
    [12] = { categoryID = 2, fullName = "Molten Core", shortName = "MC", minLevelSuggestion = 60, maxLevelSuggestion = 60, maxNumPlayers = 40 },
    [13] = { categoryID = 2, fullName = "Zul'Gurub", shortName = "ZG", minLevelSuggestion = 60, maxLevelSuggestion = 60, maxNumPlayers = 20 },
    [14] = { categoryID = 2, fullName = "Ruins", shortName = "AQ20", minLevelSuggestion = 60, maxLevelSuggestion = 60, maxNumPlayers = 10 },
    [15] = { categoryID = 2, fullName = "Odd", shortName = "Odd", minLevelSuggestion = 1, maxLevelSuggestion = 60, maxNumPlayers = 15 },
}
check("state without a listing", Li.State().active, false)
check("no remaining without a listing", Li.State().remaining, nil)
check("post without activities does nothing", Li.Post({}, nil), false)
check("post blocked without a click", Li.Post({ 11 }, { tank = true }), false)
check("blocked post recorded", lfg.blocked[1], "CreateListing")
lfg.blocked = {}
check("post creates", M.lfg.click(Li.Post, { 11 }, { tank = true, healer = false, dps = false }), true)
check("create call", lfg.creates[1].activityIDs[1], 11)
check("roles set after the listing", lfg.roles ~= nil and lfg.roles.tank, true)
check("state active", Li.State().active, true)
check("state roles", Li.State().roles.tank, true)
lfg.active.comment = "LF tank"
check("existing comment read", Li.Comment(), "LF tank")
M.lfg.click(Li.Post, { 11, 14 }, nil)
check("second post updates", #lfg.updates, 1)
check("update keeps creates at one", #lfg.creates, 1)
check("update carries no comment", lfg.updates[1].comment, nil)
lfg.secret = true
check("secret comment reads as empty", Li.Comment(), "")
lfg.secret = false

-- countdown and the single warning
local warnings = 0
Li.OnExpiryWarning(function() warnings = warnings + 1 end)
lfg.active.duration = 600
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check("remaining from duration", Li.State().remaining, 600)
M.state.time = M.state.time + 100
check("remaining counts down locally", Li.State().remaining, 500)
check("no warning above the limit", warnings, 0)
M.state.time = M.state.time + 201
Li.Tick()
check("warns below expiryWarnMinutes", warnings, 1)
Li.Tick(); Li.State()
check("warns only once", warnings, 1)
M.state.time = M.state.time + 10000
check("remaining never negative", Li.State().remaining, 0)
lfg.active.duration = 3600
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
M.state.time = M.state.time + 3400
Li.Tick()
check("extended listing warns again", warnings, 2)
Settings.Set("expiryWarnMinutes", 1)
lfg.active.duration = 3600
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
M.state.time = M.state.time + 3400
Li.Tick()
check("warn limit follows the setting", warnings, 2)
Settings.Set("expiryWarnMinutes", 5)

Li.Remove()
check("remove calls Finder", lfg.removed, 1)
check("state inactive after remove", Li.State().active, false)

-- templates
check("no templates at first", #Li.Templates(), 0)
check("empty name rejected", Li.SaveTemplate("", { 11 }, {}, ""), false)
check("save", Li.SaveTemplate("Tank RFC", { 11 }, { tank = true }, "LF healer"), true)
check("persisted in the profile", ns.DB().templates[1].name, "Tank RFC")
check("template shape roles", ns.DB().templates[1].roles.healer, false)
check("template shape dps", ns.DB().templates[1].roles.dps, false)
check("template comment kept", ns.DB().templates[1].comment, "LF healer")
Li.SaveTemplate("Tank RFC", { 11, 14 }, { tank = true, dps = true }, "")
check("same name overwrites", #Li.Templates(), 1)
check("overwritten activities", #Li.Templates()[1].activityIDs, 2)
Li.SaveTemplate("Heal MC", { 12 }, { healer = true }, "")
check("two templates", #Li.Templates(), 2)
local applied = Li.ApplyTemplate("Heal MC")
check("apply activities", applied.activityIDs[1], 12)
check("apply roles", applied.roles.healer, true)
check("apply comment", applied.comment, "")
check("apply unknown", Li.ApplyTemplate("Nope"), nil)
check("apply gives a copy", (function() applied.activityIDs[1] = 99; return Li.Templates()[2].activityIDs[1] end)(), 12)
check("delete", Li.DeleteTemplate("Tank RFC"), true)
check("delete unknown", Li.DeleteTemplate("Tank RFC"), false)
check("one template left", #Li.Templates(), 1)
Li.DeleteTemplate("Heal MC")
check("empty again stores nothing", ns.DB().templates, nil)

-- missing roles
UnitIsGroupLeader = function() return false end
check("not leading: no missing", Li.Missing(11), nil)
UnitIsGroupLeader = function() return true end
local assigned, members, raid = {}, 1, false
GetNumGroupMembers = function() return members end
IsInRaid = function() return raid end
UnitGroupRolesAssigned = function(u) return assigned[u] or "NONE" end
local function missing(id) local m = Li.Missing(id); return m.TANK .. "/" .. m.HEALER .. "/" .. m.DAMAGER end
check("5-man, only me", missing(11), "1/1/3")
members, assigned = 3, { player = "TANK", party1 = "HEALER", party2 = "DAMAGER" }
check("5-man with tank, healer, dps", missing(11), "0/0/2")
members, assigned = 1, {}
check("10-man empty roles", missing(14), "2/3/5")
check("20-man", missing(13), "2/5/13")
check("40-man", missing(12), "4/10/26")
raid, members = true, 4
assigned = { raid1 = "TANK", raid2 = "TANK", raid3 = "HEALER", raid4 = "DAMAGER" }
check("raid counts assigned roles", missing(12), "2/9/25")
assigned = { raid1 = "TANK", raid2 = "TANK", raid3 = "TANK", raid4 = "TANK" }
check("surplus never negative", missing(14), "0/3/5")
raid, members = false, 2
assigned = {}
check("other size: dps is max minus members", missing(15), "0/0/13")
check("unknown activity", Li.Missing(999), nil)
UnitIsGroupLeader, GetNumGroupMembers, IsInRaid, UnitGroupRolesAssigned = nil, nil, nil, nil

-- whisper expansion
lfg.level = 42
UnitClass = function() return "Priester", "PRIEST" end
ns.Roles.Set({ healer = true })
check("expansion", Li.Expand("Hi! {role}, {level} {class} for {activity}", 11), "Hi! Healer, 42 Priester for Ragefire Chasm")
check("expansion twice", Li.Expand("{level}{level}", 11), "4242")
check("unknown placeholder kept", Li.Expand("{foo} {role}", 11), "{foo} Healer")
lfg.active = { activityIDs = { 12 } }
check("activity from my listing", Li.Expand("{activity}"), "Molten Core")
lfg.active = nil
check("no activity expands empty", Li.Expand("[{activity}]"), "[]")
check("default whisper template expands", Li.Expand(Settings.Get("whisperTemplates")[1], 11),
    "Hi! Still looking for Healer? I'm a level 42 Priester.")
ns.Roles.Set({ healer = true, dps = true })
check("{role} is my selected roles", Li.Expand("{role}", 11), "Healer/DPS")
ForeverGroupFinderChar.roles = nil
UnitClass = nil

-- comment editor
local textSet, setCalls = nil, 0
local box = { SetText = function(self, t) setCalls = setCalls + 1; textSet = t end }
LFGListingComment = { EditBox = box }
local shown, loaded = 0, {}
LFGVanilla_ShowFrame = function(tab) shown = shown + 1; loaded.tab = tab end
C_AddOns = { LoadAddOn = function(name) loaded.name = name; return true end }
lfg.authenticated = {}
check("CanComment false without authenticator", Li.CanComment(2), false)
check("editor unavailable without authenticator", Li.OpenCommentEditor("text", 2), "UNAVAILABLE")
check("Blizzard's box untouched without authenticator", setCalls, 0)
check("Blizzard finder not opened without authenticator", shown, 0)
lfg.authenticated[2] = true
check("CanComment true", Li.CanComment(2), true)
check("CanComment defaults to the category setting", Li.CanComment(), true)
check("editor prefills", Li.OpenCommentEditor("LF healer", 2), "PREFILLED")
check("prefill text", textSet, "LF healer")
check("addon loaded", loaded.name, "Blizzard_GroupFinder_VanillaStyle")
check("finder shown on tab 1", loaded.tab, 1)
setCalls = 0
check("empty text opens without writing", Li.OpenCommentEditor("", 2), "OPENED")
check("nothing written for empty text", setCalls, 0)
box.SetText = function() error("Call is illegal when disabled by security settings") end
local r1, r2 = Li.OpenCommentEditor("LF healer", 2)
check("illegal write falls back to copy", r1, "COPY")
check("copy text returned", r2, "LF healer")
LFGListingComment = nil
check("missing box falls back to copy", (Li.OpenCommentEditor("x", 2)), "COPY")
LFGVanilla_ShowFrame = nil
check("no Blizzard finder", Li.OpenCommentEditor("x", 2), "UNAVAILABLE")
LFGVanilla_ShowFrame, C_AddOns = nil, nil
lfg.reset()

section("Window")
local W, Side, LP, Memory = ns.Window, ns.Side, ns.ListingPanel, ns.Memory
lfg.reset()
lfg.level = 20
lfg.cats = { 2, 114 }
lfg.catNames = { [2] = "Dungeons", [114] = "Raids" }
lfg.activities = {
    [21] = { categoryID = 2, fullName = "Ragefire Chasm", shortName = "RFC", minLevelSuggestion = 13, maxLevelSuggestion = 18, maxNumPlayers = 5 },
    [22] = { categoryID = 2, fullName = "The Deadmines", shortName = "DM", minLevelSuggestion = 18, maxLevelSuggestion = 23, maxNumPlayers = 5 },
    [23] = { categoryID = 2, fullName = "Shadowfang Keep", shortName = "SFK", minLevelSuggestion = 22, maxLevelSuggestion = 30, maxNumPlayers = 5 },
    [24] = { categoryID = 2, fullName = "Wailing Caverns", shortName = "WC", minLevelSuggestion = 17, maxLevelSuggestion = 24, maxNumPlayers = 5 },
    [31] = { categoryID = 114, fullName = "Molten Core", shortName = "MC", minLevelSuggestion = 60, maxLevelSuggestion = 60, maxNumPlayers = 40 },
}
M.Fire("LFG_LIST_AVAILABILITY_UPDATE")   -- Activities forgets what it cached
M.state.time = M.state.time + 100
local function click(frame, button) return lfg.click(frame:GetScript("OnClick"), frame, button or "LeftButton") end
local function searches() return #lfg.searches end
-- A menu entry is clicked like a button: with a hardware event.
local function menuClick(item) return lfg.click(M.MenuClick, item) end

-- Opening by click searches once.
lfg.click(W.Toggle)
local f = W.Frame()
check("window frame built", f ~= nil and f:GetName(), "ForeverGroupFinderWindow")
check("window shown", W.IsShown(), true)
check("ESC closes it", (function()
    for _, n in ipairs(UISpecialFrames) do if n == "ForeverGroupFinderWindow" then return true end end
    return false
end)(), true)
check("title", f.header.title:GetText(), "Group Finder")
check("opening searches", searches(), 1)
check("search in the category", lfg.searches[1][1], 2)
check("no search blocked", #lfg.blocked, 0)
check("window size from the settings", f:GetWidth() .. "x" .. f:GetHeight(), "720x460")
check("nothing secure", (function()
    for _, fr in ipairs(M.frames) do if fr._secure then return false end end
    return true
end)(), true)

-- The activity list follows the level switch.
local function visible()
    local out = {}
    for _, item in ipairs(Side.Items()) do
        if item:IsShown() and item.activity then out[#out + 1] = item.activity.id end
    end
    return table.concat(out, ",")
end
check("switch on: fitting only", visible(), "24,22")
check("switch box checked", Side.Panel().levelBox:GetChecked(), true)
check("switch label", Side.Panel().levelText:GetText(), "Only in my level range")
M.state.time = M.state.time + 5
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
click(Side.Panel().level)
check("switch off: everything", visible(), "24,22,21,23")
check("switch setting", S("levelRangeOnly"), false)
check("the switch searched", searches(), 2)
local rfc
for _, item in ipairs(Side.Items()) do if item.activity and item.activity.id == 21 then rfc = item end end
check("too low is grey", rfc and rfc.name._textColor[1], ns.Controls.GREY[1])
check("range shown", rfc and rfc.range:GetText(), "13-18")
click(Side.Panel().level)
check("switch on again", visible(), "24,22")

-- Ticking searches once; the throttle drops a second tick.
M.state.time = M.state.time + 5
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local before = searches()
click(Side.Items()[2])
check("ticking searches", searches(), before + 1)
check("ticked activity searched", lfg.searches[#lfg.searches][7] and lfg.searches[#lfg.searches][7][1], 22)
check("ticked", W.Checked()[22], true)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
click(Side.Items()[1])
check("second tick inside the interval: no search", searches(), before + 1)
check("still ticked", W.Checked()[24], true)
check("my listing shows both", LP.Frame().chips[1]:IsShown() and LP.Frame().chips[2]:IsShown(), true)
check("listing chips are display only", (function()
    local n = searches()
    click(LP.Frame().chips[1])
    return W.Checked()[24] == true and W.Checked()[22] == true and searches() == n
end)(), true)
check("listing chip tooltip points to the activity list", (function()
    LP.Frame().chips[1]:GetScript("OnEnter")(LP.Frame().chips[1])
    local t = GameTooltip._text
    LP.Frame().chips[1]:GetScript("OnLeave")(LP.Frame().chips[1])
    return t
end)(), "Change the activities in the activity list.")
check("refresh shows the age", f.header.note:GetText(), "0 s ago")
M.state.time = M.state.time + 4
click(Side.Items()[1])
check("after the interval it searches again", searches(), before + 2)
check("unticked", W.Checked()[24], nil)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

-- The clock never searches.
local n = searches()
M.state.time = M.state.time + 30
f:GetScript("OnUpdate")(f, 5)
check("ticker: no search", searches(), n)
check("ticker: nothing blocked", #lfg.blocked, 0)
check("ticker updates the age", f.header.note:GetText(), "30 s ago")

-- Keyed searches outside a click are blocked by the client: the window
-- calls Search only from clicks (opening, ticking, chips, refresh).
check("refresh button searches", (function()
    M.state.time = M.state.time + 5
    local k = searches()
    click(f.header.refresh)
    return searches() - k
end)(), 1)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

-- Activities with the switch on: my active listing's stay.
lfg.active = { activityIDs = { 23 }, comment = "", duration = 1800 }
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check("listing activity out of range stays visible", visible():find("23", 1, true) ~= nil, true)
lfg.active = nil
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check("gone again without the listing", visible():find("23", 1, true), nil)

-- Category switch through the radio buttons.
local cats = Side.Panel().cats
local function catTexts()
    local t = {}
    for _, r in ipairs(cats) do if r:IsShown() then t[#t + 1] = r.label:GetText() end end
    return table.concat(t, ",")
end
check("radios for the available categories", catTexts(), "Dungeons,Raids")
check("current category ticked", cats[1].box:GetChecked() and not cats[2].box:GetChecked(), true)
check("radios side by side", cats[2]._points.TOPLEFT[3] > cats[1]._points.TOPLEFT[3]
    and cats[2]._points.TOPLEFT[4] == cats[1]._points.TOPLEFT[4], true)
check("no category dropdown any more", Side.Panel().category, nil)
M.state.time = M.state.time + 5
local k = searches()
click(cats[2])
check("radio click searches", searches(), k + 1)
check("radio searched the new category", lfg.searches[#lfg.searches][1], 114)
check("new category ticked", cats[2].box:GetChecked() and not cats[1].box:GetChecked(), true)
check("category stored", S("category"), 114)
check("category switch clears ticks", next(W.Checked()), nil)
check("raids: MC out of range hidden", visible(), "")
check("same radio again: no search", (function()
    M.state.time = M.state.time + 5
    local n = searches()
    click(cats[2])
    return searches() - n
end)(), 0)
-- Many categories wrap to a second line; the search box moves down.
lfg.cats = { 2, 114, 116, 118, 120 }
lfg.catNames = { [2] = "Dungeons", [114] = "Raids", [116] = "Quests & Zones", [118] = "Battlegrounds", [120] = "Custom" }
M.Fire("LFG_LIST_AVAILABILITY_UPDATE")
Side.Refresh()
check("five radios", catTexts(), "Dungeons,Raids,Quests & Zones,Battlegrounds,Custom")
check("wrapped to more lines", cats[5]._points.TOPLEFT[4] < cats[1]._points.TOPLEFT[4], true)
check("all inside the panel", (function()
    for _, r in ipairs(cats) do
        if r._points.TOPLEFT[3] + r:GetWidth() > S("sideWidth") - 6 + 1 then return false end
    end
    return true
end)(), true)
check("search box below the radios", Side.Panel().search._points.TOPLEFT[4] < cats[5]._points.TOPLEFT[4], true)
lfg.cats = { 2, 114 }
lfg.catNames = { [2] = "Dungeons", [114] = "Raids" }
M.Fire("LFG_LIST_AVAILABILITY_UPDATE")
Settings.Set("category", nil)
W.SetChecked(22, true)
Side.Refresh()
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

-- Rows from results.
local function result(id, leader, members, extra)
    local r = { searchResultID = id, activityIDs = { 22 }, leaderName = leader, comment = "c" .. id, numMembers = #members,
        age = 60, numCharFriends = 0, numBNetFriends = 0, numGuildMates = 0, isDelisted = false }
    for key, v in pairs(extra or {}) do r[key] = v end
    lfg.results[id] = r
    lfg.members[id] = members
    lfg.counts[id] = { TANK = 0, HEALER = 0, DAMAGER = #members, TANK_REMAINING = 1, HEALER_REMAINING = 1, DAMAGER_REMAINING = 0 }
end
local function member(name, class, level, area, roles)
    return { name = name, level = level or 20, classFilename = class, assignedRole = "DAMAGER", areaName = area,
        lfgRoles = roles or { tank = false, healer = false, dps = true }, isLeader = true }
end
result(1, "Grimnar", { member("Grimnar", "WARRIOR"), member("Ilvea", "MAGE") }, { numGuildMates = 1 })
result(2, "Thal", { member("Thal", "PRIEST"), member("Ra", "ROGUE"), member("Ho", "HUNTER") }, { age = 10 })
result(3, "Solo", { member("Solo", "MAGE", 21, "Stormwind City", { tank = true, healer = false, dps = true }) },
    { activityIDs = { 22, 24, 23 }, comment = "tank lf" })
ForeverGroupFinderChar.roles = nil   -- my roles: the first allowed (tank)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local built = W.Built()
check("groups built", #built.groups, 2)
check("players built", #built.players, 1)
local used = f.pool.used
check("rows: divider, 2 groups, divider, 1 player", #used, 5)
check("groups divider", used[1].text:GetText(), "Groups (2)")
check("players divider", used[4].text:GetText(), "Players (1)")
check("group row kind", used[2].kind, "GROUP")
check("group activity name", used[2].activity:GetText(), "The Deadmines")
check("guild tag", used[2].entry.id == 1 and used[2].tag:GetText() or used[3].tag:GetText(), "Guild")
local g1 = used[2]
check("free slots from the counts (tank, healer)", (function()
    local free = {}
    for _, sq in ipairs(g1.squares) do if sq:IsShown() and sq.free then free[#free + 1] = sq.role._atlas end end
    return table.concat(free, ",")
end)(), "groupfinder-icon-role-large-tank,groupfinder-icon-role-large-heal")
check("member slot shows the role on the class colour", g1.squares[1].role._atlas == "groupfinder-icon-role-large-dps"
    and g1.squares[1].fill:IsShown(), true)
check("green edge when there is room for my role", g1.edge:IsShown(), true)
local p1 = used[5]
check("player row kind", p1.kind, "PLAYER")
check("player name", p1.name:GetText(), "Solo")
check("player name in class colour", p1.name._textColor[1], RAID_CLASS_COLORS.MAGE.r)
check("player level", p1.level:GetText(), "21")
check("player location", p1.area:GetText(), "Stormwind City")
check("player chips for the activities that fit", (function()
    local t = {}
    for i = 1, 3 do t[#t + 1] = p1.chips[i] and p1.chips[i]:IsShown() and p1.chips[i].text:GetText() or "-" end
    return table.concat(t, ",")
end)(), "DM,WC,SFK")
check("abbreviated: all fit, nothing counted", p1.more:GetText(), "")
p1.chips[1]:GetScript("OnEnter")(p1.chips[1])
check("chip tooltip: full name", GameTooltip._lines and GameTooltip._lines[1] and GameTooltip._lines[1][1], "The Deadmines")
check("chip tooltip: levels", GameTooltip._lines[2] and GameTooltip._lines[2][1], "Levels 18 to 23")
p1.chips[1]:GetScript("OnLeave")(p1.chips[1])
check("row tooltip keeps full names", (function()
    for _, line in ipairs(ns.Rows.TooltipLines(p1.entry, 0)) do
        if (line.text or ""):find("The Deadmines", 1, true) then return true end
    end
    return false
end)(), true)
check("player role column: tank and damage, large", p1.roles[1]:IsShown() and p1.roles[3]:IsShown()
    and not p1.roles[2]:IsShown() and p1.roles[1]._atlas, "groupfinder-icon-role-large-tank")
check("role icons side by side, the same size", p1.roles[1]._w == p1.roles[3]._w and p1.roles[1]._w >= 18, true)
check("one role fills the row height", (ns.Rows.RoleColumn(34, 1)), 28)
check("level beside the roles, larger", p1.level._font[2] > S("nameSize"), true)
check("player roles: tank shown", p1.roles[1]:IsShown(), true)
check("player roles: healer hidden", p1.roles[2]:IsShown(), false)
check("player comment", p1.comment:GetText(), "tank lf")
check("player age", p1.age:GetText(), "1 min")
check("player invite button", p1.invite:IsShown(), true)
click(p1.invite)
check("invite from the player row", M.invited[#M.invited], "Solo")

-- In place: an update changes the row, not the order.
local firstID = used[2].entry.id
local firstRow = built.groups[1]
lfg.results[firstID].comment = "now full"
lfg.results[firstID].age = 9999
M.Fire("LFG_LIST_SEARCH_RESULT_UPDATED", firstID)
check("same row table", W.Built().groups[1], firstRow)
check("row updated in place", firstRow.comment, "now full")
check("widget shows the new comment", used[2].comment:GetText(), "now full")
check("order kept", used[2].entry.id, firstID)
lfg.results[firstID] = nil
M.Fire("LFG_LIST_SEARCH_RESULT_UPDATED", firstID)
check("vanished result: delisted", firstRow.delisted, true)
check("delisted is struck through", used[2].strike:IsShown(), true)
check("delisted is dimmed", used[2].activity:GetAlpha() < 1, true)
check("unknown id ignored", pcall(M.Fire, "LFG_LIST_SEARCH_RESULT_UPDATED", 999), true)
result(firstID, firstID == 1 and "Grimnar" or "Thal", firstID == 1 and { member("Grimnar", "WARRIOR"), member("Ilvea", "MAGE") }
    or { member("Thal", "PRIEST"), member("Ra", "ROGUE"), member("Ho", "HUNTER") })
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
used = f.pool.used

-- Tooltip.
local groupRow
for _, row in ipairs(used) do if row.entry and row.entry.id == 1 then groupRow = row end end
groupRow:GetScript("OnEnter")(groupRow)
local tipText = {}
for _, line in ipairs(GameTooltip._lines or {}) do tipText[#tipText + 1] = table.concat(line, "|") end
tipText = table.concat(tipText, "\n")
check("tooltip: activity", tipText:find("The Deadmines", 1, true) ~= nil, true)
check("tooltip: every member", tipText:find("Grimnar (20)", 1, true) ~= nil and tipText:find("Ilvea (20)", 1, true) ~= nil, true)
check("tooltip: class and role", tipText:find("WARRIOR - DPS", 1, true) ~= nil, true)
check("tooltip: comment", tipText:find("c1", 1, true) ~= nil, true)
check("tooltip: age", tipText:find("Listed 1 min ago", 1, true) ~= nil, true)
groupRow:GetScript("OnLeave")(groupRow)
local tl = ns.Rows.TooltipLines(W.Built().players[1], 0)
check("player tooltip: area", (function()
    for _, line in ipairs(tl) do if (line.right or ""):find("Stormwind City", 1, true) then return true end end
    return false
end)(), true)
check("player tooltip: wanted roles", (function()
    for _, line in ipairs(tl) do if line.text == "Roles: Tank, DPS" then return true end end
    return false
end)(), true)

-- Left click on a group opens the detail panel (no whisper).
local D = ns.Detail
local tells = #M.tells
click(groupRow)
check("group left click does not whisper", #M.tells, tells)
check("detail panel open", D.IsShown(), true)
check("detail shows this group", D.OpenID(), 1)
check("opening details does not mark seen", Memory.IsSeen(groupRow.entry.key), false)
check("not dimmed by opening", groupRow.activity:GetAlpha(), 1)
check("green edge stays with the panel open", groupRow.edge:IsShown(), true)
for i, e in ipairs(D.ButtonExtents()) do
    check("detail button " .. i .. " inside the panel", e.left >= 0 and e.right <= e.width, true)
    check("detail button " .. i .. " label fits", D.Frame().buttons[i].label._w <= D.Frame().buttons[i]:GetWidth(), true)
end
check("five detail buttons (no invite for a group)", #D.ButtonExtents(), 5)
check("no invite button on the details", D.Frame().invite, nil)
check("row 1: whisper, template", D.Frame().whisper._points.BOTTOMLEFT[4] == D.Frame().template._points.BOTTOMLEFT[4]
    and D.Frame().whisper._points.BOTTOMLEFT[4] > D.Frame().seen._points.BOTTOMLEFT[4], true)
check("row 2: seen, hide, ignore", D.Frame().seen._points.BOTTOMLEFT[4] == D.Frame().ignore._points.BOTTOMLEFT[4], true)
check("row 1 buttons share the width", D.Frame().whisper:GetWidth() > D.Frame().seen:GetWidth(), true)
check("docked right with room", D.Frame().side, "RIGHT")
f._rect = { 1500, 300, 720, 460 }
D.Dock()
check("docked left without room on the right", D.Frame().side, "LEFT")
f._rect = nil
D.Dock()
check("detail docked to the window", D.Frame()._points.TOPLEFT[1], f)
check("detail title", D.Frame().header.title:GetText(), "The Deadmines")
check("selected row outlined", groupRow.selected[1]:IsShown(), true)
check("detail ESC-closable", (function()
    for _, n in ipairs(UISpecialFrames) do if n == "ForeverGroupFinderDetail" then return true end end
    return false
end)(), true)
local function detailTexts()
    local t = {}
    for _, line in ipairs(D.Lines(D.Row(), 0)) do
        if line.kind == "member" then t[#t + 1] = "M:" .. line.member.name .. ":" .. tostring(line.role)
        elseif line.kind == "free" then t[#t + 1] = "F:" .. tostring(line.role)
        else t[#t + 1] = line.text end
    end
    return table.concat(t, "|")
end
check("detail lines", detailTexts(), "Activities|The Deadmines (18-23)|Leader: Grimnar|Listed 1 min ago|Comment|c1"
    .. "|Members (2)|M:Grimnar:DAMAGER|M:Ilvea:DAMAGER|F:TANK|F:HEALER")
check("member lines rendered", D.Frame().members[1]:IsShown() and D.Frame().members[1].name:GetText(), "Grimnar")
check("free line rendered", D.Frame().members[3].name:GetText(), "Free: Tank")
local pd = D.Frame()
click(pd.whisper)
check("detail whispers the leader", M.tells[#M.tells].name, "Grimnar")
check("whispered row is seen", Memory.IsSeen(groupRow.entry.key), true)
check("seen row dimmed", groupRow.activity:GetAlpha(), 0.45)
check("seen row keeps its frame at full alpha", groupRow:GetAlpha(), 1)
check("seen row keeps the green edge", groupRow.edge:IsShown() and groupRow.edge:GetAlpha(), 1)
click(pd.template)
check("detail template menu", M.LastMenu().items[1] and M.LastMenu().items[1].text ~= nil, true)
-- live update and delisting
lfg.results[1].comment = "need tank now"
M.Fire("LFG_LIST_SEARCH_RESULT_UPDATED", 1)
check("detail updates live", detailTexts():find("need tank now", 1, true) ~= nil, true)
local saved1, savedM1 = lfg.results[1], lfg.members[1]
lfg.results[1] = nil
M.Fire("LFG_LIST_SEARCH_RESULT_UPDATED", 1)
check("detail shows delisted", detailTexts():sub(1, 16), "No longer listed")
lfg.results[1], lfg.members[1] = saved1, savedM1
lfg.results[1].comment = "c1"
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("new result set: same group, fresh row", D.OpenID() == 1 and D.Row().delisted, false)
used = f.pool.used
for _, row in ipairs(used) do if row.entry and row.entry.id == 1 then groupRow = row end end
local otherRow
for _, row in ipairs(used) do if row.entry and row.entry.id == 2 then otherRow = row end end
click(otherRow)
check("another group switches the panel", D.OpenID(), 2)
click(otherRow)
check("the same row again closes it", D.IsShown(), false)
click(groupRow)
click(pd.header.close)
check("X closes it", D.IsShown(), false)
click(groupRow)
W.Hide()
check("closing the window closes it", D.IsShown(), false)
lfg.click(W.Toggle)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
used = f.pool.used
for _, row in ipairs(used) do if row.entry and row.entry.id == 1 then groupRow = row end end
local playerRow
for _, row in ipairs(used) do if row.kind == "PLAYER" then playerRow = row end end
tells = #M.tells
click(playerRow)
check("player left click still whispers", M.tells[#M.tells].name == "Solo" and #M.tells, tells + 1)
check("player click opens no panel", D.IsShown(), false)
-- Slots: Tank, Healer, Damage, unknown; free places in the same order.
local function slotText(entry)
    local t = {}
    for _, sl in ipairs(ns.Rows.Slots(entry)) do
        t[#t + 1] = (sl.free and "free:" or (sl.member.name .. ":")) .. tostring(sl.role)
    end
    return table.concat(t, ",")
end
check("slots ordered by role", slotText({ activityIDs = { 22 }, members = {
    { name = "D", role = "DAMAGER" }, { name = "X" }, { name = "H", role = "HEALER" }, { name = "T", role = "TANK" } },
    counts = { TANK_REMAINING = 0, HEALER_REMAINING = 1, DAMAGER_REMAINING = 2 } }),
    "T:TANK,H:HEALER,D:DAMAGER,X:nil,free:HEALER,free:DAMAGER,free:DAMAGER")
check("without counts free places up to the size", slotText({ activityIDs = { 22 }, members = { { name = "A", role = "TANK" } } }),
    "A:TANK,free:nil,free:nil,free:nil,free:nil")
local flagged = D.Lines({ activityIDs = { 22 }, leader = "L", voice = 1, newPlayerFriendly = true, friend = 2, guild = 0,
    members = {}, counts = {} }, 0)
local flagText = {}
for _, line in ipairs(flagged) do flagText[#flagText + 1] = line.text or "" end
flagText = table.concat(flagText, "|")
check("detail: voice flag", flagText:find("Voice chat", 1, true) ~= nil, true)
check("detail: new players flag", flagText:find("New players welcome", 1, true) ~= nil, true)
check("detail: friends and guild", flagText:find("Friends: 2, guild: 0", 1, true) ~= nil, true)
-- Hide and Ignore from the panel close it.
click(groupRow)
click(D.Frame().hide)
check("detail hide: hidden", Memory.IsHidden(ns.Memory.Key({ leaderName = "Grimnar", activityIDs = { 22 } })), true)
check("detail hide: panel closed", D.IsShown(), false)
ns.AccountDB().memory.hidden = {}
W.Rebuild()
used = f.pool.used
for _, row in ipairs(used) do if row.entry and row.entry.id == 1 then groupRow = row end end
click(groupRow)
click(D.Frame().ignore)
check("detail ignore", Memory.IsIgnored("Grimnar"), true)
check("detail ignore: panel closed", D.IsShown(), false)
Memory.SetIgnored("Grimnar", false)
used = f.pool.used
for _, row in ipairs(used) do if row.entry and row.entry.id == 1 then groupRow = row end end
UnitIsGroupLeader = function() return false end
M.state.group = true
UnitIsGroupLeader, M.state.group = nil, nil
D.Close()
Memory.MarkSeen(groupRow.entry.key)
W.RefreshRows()

-- Right click menu.
click(groupRow, "RightButton")
local menu = M.LastMenu()
check("group menu: no invite", M.MenuTexts(menu), "Grimnar,Whisper,Whisper template,-,Mark as seen,Hide,Ignore the leader")
M.MenuClick(M.MenuFind(menu, "Whisper"))
check("menu whisper", M.tells[#M.tells].name, "Grimnar")
UnitClass = function() return "Warrior", "WARRIOR" end
click(groupRow, "RightButton")
menu = M.LastMenu()
local tmpl = M.MenuFind(menu, "Whisper template")
check("whisper templates expanded", tmpl.items[1] and tmpl.items[1].text, "Hi! Still looking for Tank? I'm a level 20 Warrior.")
M.MenuClick(tmpl.items[1])
check("template whisper text", M.tells[#M.tells].text, "Hi! Still looking for Tank? I'm a level 20 Warrior.")
UnitClass = nil
do
local playerEntry = W.Built().players[1]
ns.Menu.OpenRowMenu(f.pool.used[2], playerEntry)
local pMenu = M.LastMenu()
check("player menu keeps invite", M.MenuFind(pMenu, "Invite") ~= nil, true)
M.MenuClick(M.MenuFind(pMenu, "Invite"))
check("player menu invite", M.invited[#M.invited], playerEntry.leader)
end
local key1 = groupRow.entry.key
M.MenuClick(M.MenuFind(menu, "Hide"))
check("hidden in memory", Memory.IsHidden(key1), true)
check("hidden row gone", #W.Built().groups, 1)
local other = W.Built().groups[1]
click(f.pool.used[2], "RightButton")
M.MenuClick(M.MenuFind(M.LastMenu(), "Ignore the leader"))
check("leader ignored", Memory.IsIgnored(other.leader), true)
check("ignored group gone", #W.Built().groups, 0)
Memory.Unignore(other.leader)
local store = ns.AccountDB().memory
store.hidden, store.seen = {}, {}
W.Rebuild()
check("back after unhide/unignore", #W.Built().groups, 2)

-- Our own menu when the client has no MenuUtil.
local menuUtil = MenuUtil
MenuUtil = nil
local own
for _, row in ipairs(f.pool.used) do if row.kind == "PLAYER" then own = row end end
own = ns.Menu.OpenRowMenu(own, own.entry)
check("own menu shown", own ~= nil and own:IsShown(), true)
local inviteLine
for _, line in ipairs(own.lines) do if line:IsShown() and line.text:GetText() == "Invite" then inviteLine = line end end
check("own menu has Invite", inviteLine ~= nil, true)
local invites = #M.invited
inviteLine:GetScript("OnClick")(inviteLine)
check("own menu invites", #M.invited, invites + 1)
check("own menu closes", own:IsShown(), false)
MenuUtil = menuUtil

-- Filter chips toggle their settings.
local chips = f.filters.chips
check("no role chip in the filter bar", chips.filterMyRole, nil)
local room = LP.Frame().roomOnly
check("room toggle with my roles", room:IsShown() and room.label:GetText(), "Only room for me")
check("room toggle on by default", room.on, true)
check("room filter on by default", S("filterMyRole"), true)
M.state.time = M.state.time + 5
k = searches()
click(room)
check("room toggle clears filterMyRole", S("filterMyRole"), false)
check("room toggle searched", searches(), k + 1)
check("room toggle shows off", LP.Frame().roomOnly.on, false)
-- Off: a group without room for my roles stays, dimmed as a seen one, below.
result(7, "Fullup", { member("Fullup", "WARRIOR"), member("F2", "PRIEST") })
lfg.counts[7] = { TANK = 1, HEALER = 1, DAMAGER = 0, TANK_REMAINING = 0, HEALER_REMAINING = 0, DAMAGER_REMAINING = 3 }
result(8, "Unknown", { member("Unknown", "MAGE"), member("U2", "MAGE") })
lfg.counts[8] = nil
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local fullRow, unknownRow
for _, row in ipairs(f.pool.used) do
    if row.entry and row.entry.id == 7 then fullRow = row end
    if row.entry and row.entry.id == 8 then unknownRow = row end
end
check("no room: listed with the filter off", fullRow ~= nil, true)
check("no room: marked", fullRow.entry.noRoom, true)
check("no room: dimmed like seen", fullRow.activity:GetAlpha(), S("seenAlpha") / 100)
check("no room: frame keeps full alpha", fullRow:GetAlpha(), 1)
check("no room: no green edge", fullRow.edge:IsShown(), false)
check("no room: below the groups with room", (function()
    local groups = W.Built().groups
    local seenFull = false
    for _, r in ipairs(groups) do
        if r.id == 7 then seenFull = true elseif seenFull and r.freeForMe then return false end
    end
    return seenFull
end)(), true)
check("unknown counts: not dimmed", unknownRow ~= nil and unknownRow.entry.noRoom == false and unknownRow.activity:GetAlpha(), 1)
check("room for me: not marked", W.Built().groups[1].noRoom, false)
Settings.Set("noRoomAlpha", 70)
for _, row in ipairs(f.pool.used) do if row.entry and row.entry.id == 7 then fullRow = row end end
check("no room dim amount applies", fullRow.activity:GetAlpha(), 0.7)
Settings.Set("noRoomAlpha", nil)
for _, row in ipairs(f.pool.used) do if row.entry and row.entry.id == 7 then fullRow = row end end
ForeverGroupFinderChar.roles = { tank = true, healer = false, dps = true }
W.Rebuild()
check("a second role with room: not dimmed", (function()
    for _, r in ipairs(W.Built().groups) do if r.id == 7 then return r.noRoom end end
end)(), false)
ForeverGroupFinderChar.roles = nil
W.Rebuild()
-- The detail panel says so.
click(fullRow)
check("detail note: no room", D.Frame().header.note:GetText(), "No room for you")
check("detail note in red", D.Frame().header.note._textColor[1], ns.Controls.RED[1])
for _, row in ipairs(f.pool.used) do if row.entry and row.entry.id == 1 then click(row) end end
check("detail note empty with room", D.Frame().header.note:GetText(), "")
D.Close()
M.state.time = M.state.time + 5
click(room)
check("room toggle sets it again", S("filterMyRole"), true)
check("room toggle shows on", LP.Frame().roomOnly.on, true)
check("on: the group without room is hidden", (function()
    for _, r in ipairs(W.Built().groups) do if r.id == 7 then return false end end
    return true
end)(), true)
check("on: unknown counts hidden too (no known room, as before)", (function()
    for _, r in ipairs(W.Built().groups) do if r.id == 8 then return true end end
    return false
end)(), false)
check("room toggle: players stay", #W.Built().players, 1)
lfg.results[7], lfg.results[8] = nil, nil
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
click(chips.filterLevelFits)
check("level chip", S("filterLevelFits"), true)
click(chips.filterLevelFits)
click(chips.hideSeen)
check("hide seen chip", S("hideSeen"), true)
click(chips.hideSeen)
check("hide seen off", S("hideSeen"), false)
click(chips.language)
local langMenu = M.LastMenu()
menuClick(M.MenuFind(langMenu, "Deutsch"))
check("language stored", table.concat(S("languages"), ","), "deDE")
check("language chip counts", chips.language.label:GetText(), "Language (1)")
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
M.state.time = M.state.time + 5
click(f.header.refresh)
check("language filter searched", lfg.searches[#lfg.searches][4] and lfg.searches[#lfg.searches][4].deDE, true)
click(chips.language)
menuClick(M.MenuFind(M.LastMenu(), "Deutsch"))
check("language removed", #S("languages"), 0)
check("nothing stored for no languages", ns.DB().languages, nil)
W.SetTextFilter("thal")
check("text filter", #W.Built().groups, 1)
W.SetTextFilter("")
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

-- My listing: post, remove.
local lp = LP.Frame()
check("post label", lp.post.label:GetText(), "Post")
check("status not listed", lp.status:GetText(), "not listed")
check("no separate remove button", lp.remove, nil)
check("roles shown", lp.roles.tank:IsShown(), true)
check("my role preselected", LP.Roles().tank, true)
click(lp.roles.healer)
check("role toggled", LP.Roles().healer, true)
click(lp.post)
check("post creates the listing", lfg.creates[#lfg.creates].activityIDs[1], 22)
check("roles posted", lfg.roles and lfg.roles.healer, true)
lfg.active.duration = 1800
M.Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
check("listed and unchanged: Remove", lp.post.label:GetText(), "Remove")
click(lp.roles.healer)
check("roles changed: Update", lp.post.label:GetText(), "Update")
local upd = #lfg.updates
click(lp.post)
check("update sends the listing", #lfg.updates, upd + 1)
check("updated roles", lfg.roles.healer, false)
check("unchanged again: Remove", lp.post.label:GetText(), "Remove")
W.SetChecked(24, true)
W.ListingChanged()
check("activities changed: Update", lp.post.label:GetText(), "Update")
W.SetChecked(24, false)
W.ListingChanged()
check("status listed", lp.status:GetText(), "listed, 30 min left")
-- Expiry warning with Extend.
M.state.time = M.state.time + 1600
f:GetScript("OnUpdate")(f, 1)
check("expiry warning shown", lp.warningText:IsShown() and lp.extend:IsShown(), true)
local updates = #lfg.updates
click(lp.extend)
check("extend re-posts", #lfg.updates, updates + 1)
check("warning gone after extend", LP.Warning(), false)
local removedBefore = lfg.removed
click(lp.roles.healer)
click(lp.post, "RightButton")
check("right click removes even when changed", lfg.removed, removedBefore + 1)
click(lp.roles.healer)
check("remove", lfg.removed > 0, true)
check("not listed after remove", lp.status:GetText(), "not listed")
lp.post.off = false
W.SetCheckedList({})
W.ListingChanged()
check("post greyed without activities", lp.post.off, true)
W.SetChecked(22, true)
W.ListingChanged()

-- Comment: greyed without an authenticator; copy box on "COPY".
lfg.authenticated = {}
W.ListingChanged()
check("comment button greyed", lp.comment.off, true)
check("greyed tooltip", lp.comment.offTip, "Comments need an authenticator on your account")
lp.comment:GetScript("OnEnter")(lp.comment)
check("greyed tooltip shown", GameTooltip._text, "Comments need an authenticator on your account")
lp.comment:GetScript("OnLeave")(lp.comment)
click(lp.comment)
check("greyed: no copy box", LP.CopyText(), nil)
ns.Listing.SaveTemplate("Heal DM", { 22, 24 }, { tank = false, healer = true, dps = false }, "LF2M heal")
click(lp.template)
local tMenu = M.LastMenu()
check("template menu", M.MenuFind(tMenu, "Heal DM") ~= nil and M.MenuFind(tMenu, "Save as template...") ~= nil, true)
M.state.time = M.state.time + 5
k = searches()
menuClick(M.MenuFind(tMenu, "Heal DM"))
check("template ticks its activities", table.concat(W.CheckedList(), ","), "22,24")
check("template roles", LP.Roles().healer and not LP.Roles().tank, true)
check("template comment ready", LP.TemplateComment(), "LF2M heal")
check("applying searched", searches(), k + 1)
lfg.authenticated[2] = true
LFGVanilla_ShowFrame = function() end
W.ListingChanged()
check("comment button active", lp.comment.off, false)
click(lp.comment)
check("copy text", LP.CopyText(), "LF2M heal")
check("copy box shown", lp.copy:IsShown(), true)
check("copy box holds the text", lp.copy:GetText(), "LF2M heal")
click(lp.copyClose)
check("copy box closed", lp.copy:IsShown(), false)
LFGVanilla_ShowFrame = nil
StaticPopupDialogs.FOREVERGROUPFINDER_TEMPLATE_NAME.OnAccept({ GetEditBox = function() return { GetText = function() return "Mine" end } end })
check("save template from the popup", ns.Listing.ApplyTemplate("Mine") ~= nil, true)
click(lp.template)
M.MenuClick(M.MenuFind(M.MenuFind(M.LastMenu(), "Delete"), "Mine"))
check("delete template", ns.Listing.ApplyTemplate("Mine"), nil)

-- Leader line only when leading.
check("no leader line solo", lp.leader:IsShown(), false)
UnitIsGroupLeader = function() return true end
GetNumGroupMembers = function() return 2 end
IsInRaid = function() return false end
UnitGroupRolesAssigned = function(unit) return unit == "player" and "TANK" or "DAMAGER" end
M.state.group = true
W.ListingChanged()
check("leader line shown", lp.leader:IsShown(), true)
check("leader line text", lp.leader:GetText(), "Missing: 1 Healer, 2 DPS")
check("my roles stay in a group", lp.roles.tank:IsShown(), true)
UnitClass = function() return "Warrior", "WARRIOR" end
W.ListingChanged()
check("warrior: healer role hidden", lp.roles.healer:IsShown(), false)
check("warrior: tank and dps offered", lp.roles.tank:IsShown() and lp.roles.dps:IsShown(), true)
UnitClass = nil
UnitIsGroupLeader = function() return false end
W.ListingChanged()
check("leader line hidden when not leading", lp.leader:IsShown(), false)
UnitIsGroupLeader, GetNumGroupMembers, IsInRaid, UnitGroupRolesAssigned = nil, nil, nil, nil
M.state.group = nil

-- Lock, resize arrows, combat.
Settings.SetLocked(true)
check("grips hidden when locked", f.grips.TOPLEFT:IsShown(), false)
Settings.SetLocked(false)
check("grips back", f.grips.TOPLEFT:IsShown(), true)
Settings.Set("width", 800)
check("width setting applied", f:GetWidth(), 800)
Settings.Set("width", nil)
M.state.combat = true
check("closes in combat", pcall(W.Toggle), true)
check("opens in combat", pcall(lfg.click, W.Toggle), true)
check("nothing waits for combat", ns.PendingAfterCombat(), 0)
M.state.combat = false
-- The list follows the ticks at once; a dropped search marks it outdated.
local function sideItem(id)
    for _, item in ipairs(Side.Items()) do if item:IsShown() and item.activity and item.activity.id == id then return item end end
end
lfg.results[2].activityIDs = { 24 }
result(9, "Raider", { member("Raider", "WARRIOR"), member("R2", "MAGE") }, { activityIDs = { 31 } })
M.state.time = M.state.time + 10
W.SetCheckedList({ 22, 24 })
Side.Refresh()
click(f.header.refresh)
check("current query searched", table.concat(lfg.searches[#lfg.searches][7], ","), "22,24")
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("results for the current query: not outdated", W.Outdated(), false)
check("no glow", f.header.refresh.glow:IsShown(), false)
check("both ticked activities listed", #W.Built().groups, 2)
check("the raid is not ticked", (function()
    for _, r in ipairs(W.Built().groups) do if r.id == 9 then return false end end
    return true
end)(), true)
k = searches()
click(sideItem(24))
check("untick inside the interval: no search", searches(), k)
check("untick filters the list at once", #W.Built().groups, 1)
check("the list is marked outdated", W.Outdated(), true)
check("refresh glows", f.header.refresh.glow:IsShown() and f.header.refresh.on, true)
f.header.refresh:GetScript("OnEnter")(f.header.refresh)
check("outdated tooltip", GameTooltip._text, "Click to load results for your current selection.")
f.header.refresh:GetScript("OnLeave")(f.header.refresh)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("results for the old query: still outdated", W.Outdated(), true)
check("still filtered to the ticks", #W.Built().groups, 1)
M.state.time = M.state.time + 2
click(f.header.refresh)
check("the next click searches the current query", table.concat(lfg.searches[#lfg.searches][7], ","), "22")
check("searching the current query: not outdated", W.Outdated(), false)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("its results clear the mark", W.Outdated(), false)
check("glow gone", f.header.refresh.glow:IsShown(), false)
W.SetCheckedList({})
W.Rebuild()
check("nothing ticked: the whole category", #W.Built().groups, 2)
check("nothing ticked: other categories left out", (function()
    for _, r in ipairs(W.Built().groups) do if r.id == 9 then return false end end
    return true
end)(), true)
check("a raid result with raids chosen", (function()
    Settings.Set("category", 114)
    W.Rebuild()
    local n = #W.Built().groups
    Settings.Set("category", nil)
    return n
end)(), 1)
lfg.results[9] = nil
W.SetChecked(22, true)
W.Rebuild()
-- Player rows: chips flow over both lines, the comment after them.
do
lfg.activities[25] = { categoryID = 2, fullName = "Blackfathom Deeps", shortName = "BFD", minLevelSuggestion = 20, maxLevelSuggestion = 30, maxNumPlayers = 5 }
lfg.activities[26] = { categoryID = 2, fullName = "Gnomeregan", shortName = "Gnome", minLevelSuggestion = 24, maxLevelSuggestion = 34, maxNumPlayers = 5 }
Settings.Set("abbreviate", false)   -- full names: the flow over two lines
local chipPool = ns.Rows.NewPool(CreateFrame("Frame", nil, UIParent))
local function playerWith(ids, comment)
    local row = chipPool:Acquire("PLAYER")
    ns.Rows.Layout(row, { id = 77, kind = "PLAYER", activityIDs = ids, leader = "Chip", comment = comment, age = 5,
        members = { { name = "Chip", level = 20, classFile = "MAGE" } }, roles = { dps = true } }, 800, 0)
    return row
end
local one = playerWith({ 22 }, "lf group")
check("1 activity: one line", one.chipLines, 1)
check("1 activity: comment on line 2", one.comment:IsShown() and one.comment:GetText(), "lf group")
local three = playerWith({ 21, 22, 23 }, "three")
check("3 activities: all shown", three.shownChips, 3)
check("3 activities: no +n", three.more:GetText(), "")
check("3 activities: comment still shown", three.comment:IsShown(), true)
local six = playerWith({ 21, 22, 23, 24, 25, 26 }, "six")
check("6 activities: both lines used", six.chipLines, 2)
check("6 activities: more than one line holds", six.shownChips > 4, true)
check("6 activities: chips on line 2", six.chips[6]:IsShown() and six.chips[6]._points.TOPLEFT[4] < -3, true)
check("6 activities: +n counts the hidden ones", six.more:GetText(), six.shownChips < 6 and ("+" .. (6 - six.shownChips)) or "")
check("6 activities: comment only when room is left", six.comment:IsShown() == (six.comment._w >= 40), true)
local many = playerWith({ 21, 22, 23, 24, 25, 26, 31, 21, 22, 23 }, "hidden")
check("overflow: +n", many.more:GetText():match("^%+%d+$") ~= nil, true)
check("overflow: comment in the tooltip only", many.comment:IsShown(), false)

-- List look settings apply live.
Settings.Set("groupRoleIconSize", 20)
local gRow
for _, row in ipairs(f.pool.used) do if row.kind == "GROUP" then gRow = row end end
check("group role icon size applied", gRow.squares[1]:GetWidth(), 20)
Settings.Set("groupRoleIconSize", nil)
Settings.Set("openEdgeColor", { 0, 0, 1 })
check("edge colour applied", gRow.edge._texColor[3], 1)
Settings.Set("openEdgeColor", nil)
Settings.Set("seenAlpha", 70)
Memory.MarkSeen(gRow.entry.key)
W.RefreshRows()
check("seen dim amount applied", gRow.activity:GetAlpha(), 0.7)
Settings.Set("seenAlpha", nil)
ns.AccountDB().memory.seen = {}
W.RefreshRows()
local pRow
for _, row in ipairs(f.pool.used) do if row.kind == "PLAYER" then pRow = row end end
Settings.Set("classColorNames", false)
check("names in the name colour when class colours are off", pRow.name._textColor[1] == 1 and pRow.name._textColor[2] == 1, true)
Settings.Set("classColorNames", nil)
check("class colour back", pRow.name._textColor[1], RAID_CLASS_COLORS.MAGE.r)
Settings.Set("levelSize", 20)
check("level size applied", pRow.level._font[2], 20)
Settings.Set("levelSize", nil)
Settings.Set("playerRoleIconSize", 40)
check("player role icon size applied (two roles: 75 %)", pRow.roles[3]._w, 30)
Settings.Set("playerRoleIconSize", nil)
Settings.Set("chipBorderColor", { 1, 0, 0 })
check("chip border colour applied", pRow.chips[1].edges[1]._texColor[1], 1)
Settings.Set("chipBorderColor", nil)
check("bad colour import skipped", ns.Share.Import("FGF1:ts13:openEdgeColors3:red}"), true)
check("bad colour not stored", ns.DB().openEdgeColor, nil)
check("size import clamped", (function() ns.Share.Import("FGF1:ts17:groupRoleIconSizen99;}"); return S("groupRoleIconSize") end)(), 28)
Settings.ResetProfile()
end

-- Undo for hide / ignore; the counters lead to the lists in the options.
do
local U = ns.Undo
U.Clear()
local mem = ns.AccountDB().memory
mem.hidden, mem.seen, mem.ignore = {}, {}, {}
lfg.results, lfg.members, lfg.counts = {}, {}, {}
result(1, "Grimnar", { member("Grimnar", "WARRIOR"), member("Ilvea", "MAGE") })
result(2, "Thal", { member("Thal", "PRIEST"), member("Ra", "ROGUE") })
W.SetCheckedList({ 22 })
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
local k = searches()
local function rowOf(id)
    for _, row in ipairs(f.pool.used) do if row.entry and row.entry.id == id then return row end end
end
check("no counters without entries", f.filters.chips.ignored:IsShown() or f.filters.chips.hidden:IsShown(), false)
-- Hide from the details.
click(rowOf(1))
click(D.Frame().hide)
check("hidden from the details", #W.Built().groups, 1)
check("undo bar shown", f.undo:IsShown(), true)
check("undo bar text", f.undo.text:GetText(), "Group hidden")
check("undo button", f.undo.button.label:GetText(), "Undo")
check("hidden counter", f.filters.chips.hidden:IsShown() and f.filters.chips.hidden.label:GetText(), "Hidden (1)")
click(f.undo.button)
check("undo brings the group back", #W.Built().groups, 2)
check("undo bar gone", f.undo:IsShown(), false)
check("hidden counter gone", f.filters.chips.hidden:IsShown(), false)
-- Ignore from the menu; the bar goes after a few seconds.
click(rowOf(2), "RightButton")
M.MenuClick(M.MenuFind(M.LastMenu(), "Ignore the leader"))
check("ignored from the menu", Memory.IsIgnored("Thal"), true)
check("undo bar names the leader", f.undo:IsShown() and f.undo.text:GetText(), "Thal ignored")
check("ignored counter", f.filters.chips.ignored:IsShown() and f.filters.chips.ignored.label:GetText(), "Ignored (1)")
M.state.time = M.state.time + 3
W.Tick()
check("bar still there after 3 s", f.undo:IsShown(), true)
M.state.time = M.state.time + 6
W.Tick()
check("bar gone after 8 s", f.undo:IsShown(), false)
check("still ignored after the bar", Memory.IsIgnored("Thal"), true)
click(f.undo.button)
check("a late undo does nothing", Memory.IsIgnored("Thal"), true)
-- Ignore from the details, undone.
click(rowOf(1))
click(D.Frame().ignore)
check("ignored from the details", Memory.IsIgnored("Grimnar"), true)
check("details closed", D.IsShown(), false)
click(f.undo.button)
check("undo unignores", Memory.IsIgnored("Grimnar"), false)
check("none of it searched", searches(), k)
-- The counter opens the ignore list in the options.
click(f.filters.chips.ignored)
check("counter opens the options", ns.Options.IsShown(), true)
check("on the list page", (function()
    local pg = M.byName["ForeverGroupFinderPagelist"]
    return pg ~= nil and pg:IsShown()
end)(), true)
local ignoreHeader
for _, row in ipairs(M.byName["ForeverGroupFinderPagelist"].rows) do
    if row.labelKey == "OPT_IGNORE" then ignoreHeader = row end
end
check("scrolled to the ignore list", ns.Options.ScrollOffset() > 0 and ns.Options.ScrollOffset(), ignoreHeader.stackY)
check("ignored leader listed", itemFor("Thal") ~= nil, true)
check("hint mentions unignore", (function()
    for _, fr in ipairs(M.frames) do
        if fr.text and fr.text._text and fr.text._text:find("/fgf unignore", 1, true) and fr:IsVisible() then return true end
    end
    return false
end)(), true)
local thal = itemFor("Thal")
thal.button:GetScript("OnClick")(thal.button)
check("removed in the options", Memory.IsIgnored("Thal"), false)
check("back in the list", #W.Built().groups, 2)
-- Hidden groups in the options: one by one, or all.
U.Hide(W.Built().groups[1])
U.Hide(W.Built().groups[1])
check("two hidden", #Memory.HiddenList(), 2)
check("hidden list entry", Memory.HiddenList()[1].leader ~= nil and #Memory.HiddenList()[1].activityIDs, 1)
check("remaining time", Memory.HiddenList()[1].remaining <= S("memoryMinutes") * 60, true)
ns.Options.Toggle()
click(f.filters.chips.hidden)
local hiddenHeader
for _, row in ipairs(M.byName["ForeverGroupFinderPagelist"].rows) do
    if row.labelKey == "OPT_HIDDEN" then hiddenHeader = row end
end
check("counter opens the hidden groups", ns.Options.ScrollOffset(), hiddenHeader.stackY)
local itemText = "Grimnar - The Deadmines (30 min left)"
check("hidden group listed with activity and time", itemFor(itemText) ~= nil, true)
local g = itemFor(itemText)
g.button:GetScript("OnClick")(g.button)
check("one unhidden", #Memory.HiddenList(), 1)
check("its group back", #W.Built().groups, 1)
local unhide
for _, fr in ipairs(M.frames) do
    if fr.text and fr.text._text == "Unhide all" and fr:IsVisible() then unhide = fr end
end
check("unhide all button", unhide ~= nil, true)
unhide:GetScript("OnClick")(unhide)
check("all unhidden", #Memory.HiddenList(), 0)
check("all groups back", #W.Built().groups, 2)
check("empty hint", (function()
    for _, fr in ipairs(M.frames) do
        if fr.text and fr.text._text == "No group is hidden." and fr:IsVisible() then return true end
    end
    return false
end)(), true)
ns.Options.Toggle()
U.Clear()
end

-- The header as Forever Quest Log's (Tracker.lua): 32 high, shine and line,
-- grip and title, the age as a grey note, flat 22 px icon buttons from the
-- right edge, 5 in and 1 apart.
do
local H, hd = ns.Header, f.header
check("header height", hd:GetHeight(), 32)
check("header spans the top", hd._points.TOPLEFT ~= nil and hd._points.TOPRIGHT ~= nil, true)
check("header shine under the rounded corners", (hd.shine._masks or 0) > 0, true)
check("header shine gradient", hd.shine._gradient and hd.shine._gradient[1], "VERTICAL")
check("header line", hd.line:IsShown() and hd.line._texColor[4], 0.45)
Settings.Set("headerLine", false)
check("header line follows the setting", hd.line:IsShown(), false)
Settings.Set("headerLine", nil)
check("buttons right to left", hd.buttons[1] == hd.close and hd.buttons[2] == hd.options and hd.buttons[3] == hd.lock
    and hd.buttons[4] == hd.refresh, true)
for i, b in ipairs(hd.buttons) do
    check("header button " .. i .. " size", b:GetWidth() .. "x" .. b:GetHeight(), "22x22")
    check("header button " .. i .. " place", b._points.RIGHT[3], -(5 + (i - 1) * 23))
end
check("options icon", hd.options.icon._texture, ns.Media.Icon("Gear"))
check("refresh icon", hd.refresh.icon._texture, ns.Media.Icon("Reset"))
check("icon size", hd.options.icon:GetWidth(), 14)
check("close is a drawn cross", #hd.close.lines, 2)
check("no gold box on the refresh button", hd.refresh.edges, nil)
check("title in the header style", hd.title._font[2], 18)
check("title after the grip while unlocked", hd.title._points.LEFT[3], 26)
check("grip while unlocked", hd.grip:IsShown(), true)
check("lock blue while unlocked", hd.lock.icon._vertex[1], ns.Controls.ACCENT[1])
check("unlock icon", hd.lock.icon._texture, ns.Media.Icon("Unlock"))
Settings.SetLocked(true)
check("title at 10 when locked", hd.title._points.LEFT[3], 10)
check("no grip when locked", hd.grip:IsShown(), false)
check("lock dim when locked", hd.lock.icon._vertex[1], H.OFF[1])
check("lock icon", hd.lock.icon._texture, ns.Media.Icon("Lock"))
hd:GetScript("OnMouseDown")(hd, "LeftButton")
check("locked: no drag", f.moving, nil)
M.state.ctrl = true
hd:GetScript("OnMouseDown")(hd, "LeftButton")
check("locked: Ctrl drags", f.moving, true)
hd:GetScript("OnMouseUp")(hd, "LeftButton")
M.state.ctrl = nil
Settings.SetLocked(false)
check("note after the title", hd.note._points.BOTTOMLEFT[1], hd.title)
check("note smaller than the title", hd.note._font[2], 15)
check("note grey", hd.note._textColor[1], H.NOTE[1])
check("refresh idle when not outdated", W.Outdated() and true or hd.refresh.icon._vertex[1], W.Outdated() and true or H.IDLE[1])
hd.options:GetScript("OnEnter")(hd.options)
check("hover colour", hd.options.icon._vertex[1], H.HOVER[1])
hd.options:GetScript("OnLeave")(hd.options)
check("idle again", hd.options.icon._vertex[1], H.IDLE[1])
click(hd.options)
check("gear opens the options", ns.Options.IsShown(), true)
ns.Options.Toggle()
end

-- Layouts: the same parts, arranged three ways; switched live.
do
local Layouts, Column = ns.Layouts, ns.Column
lfg.results, lfg.members, lfg.counts = {}, {}, {}
result(1, "Grimnar", { member("Grimnar", "WARRIOR"), member("Ilvea", "MAGE") })
result(3, "Solo", { member("Solo", "MAGE", 21, "Stormwind City", { tank = true, healer = false, dps = true }) })
result(4, "Healy", { member("Healy", "PRIEST", 20, "Ironforge", { tank = false, healer = true, dps = false }) })
result(5, "Stabby", { member("Stabby", "ROGUE", 19, "Darnassus", { tank = false, healer = false, dps = true }) })
W.SetCheckedList({ 22 })
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
check("layout default", Layouts.Current(), "SIDEBAR")
check("sidebar: activity column shown", f.side:IsShown(), true)
check("sidebar: no activity button", f.activity:IsShown(), false)
check("sidebar: no details column", f.detail:IsShown() or f.column:IsShown(), false)
check("sidebar: list beside the column", f.listWidth, 720 - 190 - 1 - 16)
check("sidebar: listing on the right", f.listing._points.TOPLEFT[3], 190 + 1 + 8)
check("an unknown layout counts as the sidebar", (function()
    ns.DB().layout = "BOGUS"
    local m = Layouts.Current()
    ns.DB().layout = nil
    return m
end)(), "SIDEBAR")

-- Stacked: live, its own size, the activity list in a popup.
local k = searches()
Settings.Set("layout", "STACKED")
check("switching does not search", searches(), k)
check("stacked: own size", f:GetWidth() .. "x" .. f:GetHeight(), "480x560")
check("stacked: activity column gone", f.side:IsShown(), false)
check("stacked: activity button at the top", f.activity:IsShown() and f.activity._points.TOPLEFT[4], -(ns.Header.HEIGHT + 8))
check("stacked: button names the category and the ticks", f.activity.label:GetText(), "Dungeons (1)")
check("stacked: list over the full width", f.listWidth, 480 - 16)
check("stacked: listing below the button", f.listing._points.TOPLEFT[4] < f.activity._points.TOPLEFT[4], true)
check("stacked: filters below the listing", f.filters._points.TOPLEFT[4] < f.listing._points.TOPLEFT[4], true)
check("stacked: rows laid out for the width", f.pool.used[2]:GetWidth(), 480 - 16)
click(f.activity)
check("popup opens", f.popup:IsShown(), true)
check("the activity list shows in it", f.side:IsShown(), true)
check("the list sits in the popup", f.side._points.TOPLEFT[1], f.popup)
check("popup above the window's parts", f.side:GetFrameStrata(), "DIALOG")
check("popup title", f.popup.header.title:GetText(), "Activities")
check("popup header as the window's", f.popup.header:GetHeight() .. "/" .. f.popup.header.close:GetWidth(), "32/22")
check("popup header shine clipped", (f.popup.header.shine._masks or 0) > 0, true)
check("popup has the category radios and switch", Side.Panel().cats[1]:IsShown() and Side.Panel().level:IsShown(), true)
check("popup list: the same items", visible():find("24,22", 1, true) ~= nil, true)
M.state.time = M.state.time + 5
k = searches()
click(sideItem(24))
check("popup tick searches (same path)", searches(), k + 1)
check("popup tick searched the ticks", table.concat(lfg.searches[#lfg.searches][7], ","), "22,24")
check("button counts the ticks", f.activity.label:GetText(), "Dungeons (2)")
check("popup stays open for more ticks", f.popup:IsShown(), true)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
click(sideItem(24))
check("second popup tick inside the interval: no search", searches(), k + 1)
check("and the list is marked outdated", W.Outdated(), true)
M.state.time = M.state.time + 5
click(Side.Panel().level)
check("popup level switch searches", searches(), k + 2)
click(Side.Panel().level)
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
click(f.popup.header.close)
check("popup X closes it", f.popup:IsShown() or f.side:IsShown(), false)
click(f.activity)
click(f.activity)
check("the button closes it again", f.popup:IsShown(), false)
-- Group details float as in the sidebar layout.
local gRow
for _, row in ipairs(f.pool.used) do if row.entry and row.entry.id == 1 then gRow = row end end
click(gRow)
check("stacked: details in the floating panel", D.Frame():IsShown() and D.OpenID(), 1)
check("detail header as the window's", D.Frame().header:GetHeight() .. "/" .. D.Frame().header.close:GetWidth(), "32/22")
check("detail header title style", D.Frame().header.title._font[2], 18)
check("detail close at the quest log's place", D.Frame().header.close._points.RIGHT[3], -5)
check("detail shine clipped", (D.Frame().header.shine._masks or 0) > 0, true)
check("stacked: detail click does not mark seen", Memory.IsSeen(gRow.entry.key), false)
-- Sizes per layout: a resize writes the current layout's keys.
f._rect = { 700, 200, 480, 560 }
local grip = f.grips.BOTTOMRIGHT
M.state.cursorX, M.state.cursorY = 1180, 200
grip:GetScript("OnMouseDown")(grip, "LeftButton")
M.state.cursorX, M.state.cursorY = 1200, 160
grip:GetScript("OnUpdate")(grip, 0.1)
check("dragging: live size", f:GetWidth(), 500)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
f._rect = nil
check("stacked size stored", S("stackedWidth") .. "x" .. S("stackedHeight"), "500x600")
check("sidebar size untouched", S("width") .. "x" .. S("height"), "720x460")
check("stacked: window follows its size", f:GetWidth(), 500)
check("stacked: width range", (Layouts.Ranges())[1], 420)

-- Details: list left, the open group's details in the column, listing below.
Settings.Set("layout", "DETAILS")
check("details: own size", f:GetWidth() .. "x" .. f:GetHeight(), "880x480")
check("details: open group moves into the column", D.OpenID(), 1)
check("details: floating panel closed", D.Frame():IsShown(), false)
check("details: embedded shown", f.detail:IsShown(), true)
check("details: embedded title", f.detail.header.title:GetText(), "The Deadmines")
check("details: embedded no-room note empty with room", f.detail.header.note:GetText(), "")
D.Row().noRoom = true
D.Refresh()
check("details: embedded no-room note", f.detail.header.note:GetText(), "No room for you")
D.Row().noRoom = false
D.Refresh()
check("details: embedded members", f.detail.members[1]:IsShown() and f.detail.members[1].name:GetText(), "Grimnar")
check("details: column right of the list", f.detail._points.TOPLEFT[3], 880 - Layouts.COLUMN_W)
check("details: list left of the column", f.listWidth, 880 - Layouts.COLUMN_W - 1 - 16)
check("details: activity button over the list", f.activity:IsShown(), true)
check("details: listing in the column", f.listing._points.TOPLEFT[3], 880 - Layouts.COLUMN_W + 8)
check("details: listing at the top of the column", f.listing._points.TOPLEFT[4], -(ns.Header.HEIGHT + 8))
check("details: listing level with the activity button", f.listing._points.TOPLEFT[4], f.activity._points.TOPLEFT[4])
check("details: rule under the listing", f.rule._points.TOPLEFT[4] < f.listing._points.TOPLEFT[4] - f.listing:GetHeight() + 1, true)
check("details: details below the rule", f.detail._points.TOPLEFT[4] < f.rule._points.TOPLEFT[4], true)
check("details: details fill to the bottom", -f.detail._points.TOPLEFT[4] + f.detail:GetHeight(), 480)
check("details: leader view below the rule", f.column._points.TOPLEFT[4] < f.rule._points.TOPLEFT[4], true)
check("details: detail buttons at the details' foot", f.detail.whisper._points.BOTTOMLEFT[1], f.detail)
check("details: listing narrow", f.listing:GetWidth(), Layouts.COLUMN_W - 16)
check("details: leader view hidden with a group open", f.column:IsShown(), false)
for i, e in ipairs(D.ButtonExtents(f.detail)) do
    check("embedded button " .. i .. " inside the column", e.left >= 0 and e.right <= e.width, true)
end
check("details: rows laid out for the narrower list", f.pool.used[2]:GetWidth(), 880 - Layouts.COLUMN_W - 1 - 16)
local tells = #M.tells
click(f.detail.whisper)
check("embedded whisper", #M.tells, tells + 1)
check("embedded: no invite", f.detail.invite, nil)
check("embedded: five buttons", #D.ButtonExtents(f.detail), 5)
for _, row in ipairs(f.pool.used) do if row.entry and row.entry.id == 1 then gRow = row end end
click(gRow)
check("same row again clears the column", D.OpenID(), nil)
check("embedded hidden", f.detail:IsShown(), false)
check("not leading: the hint", f.column:IsShown() and f.column.note:GetText(), "Click a group in the list to see its members, comment and actions here.")
click(gRow)
click(f.detail.header.close)
check("embedded X clears it", D.OpenID(), nil)
-- Leading a group: missing roles and the fitting solo players.
UnitIsGroupLeader = function() return true end
GetNumGroupMembers = function() return 2 end
IsInRaid = function() return false end
UnitGroupRolesAssigned = function(unit) return unit == "player" and "TANK" or "DAMAGER" end
M.state.group = true
W.ListingChanged()
check("leader column shown", f.column:IsShown(), true)
check("leader column: missing roles", f.column.title:GetText(), "Missing: 1 Healer, 2 DPS")
local fitNames = {}
for _, row in ipairs(Column.Players()) do fitNames[#fitNames + 1] = row.leader end
table.sort(fitNames)
check("leader column: players for missing roles", table.concat(fitNames, ","), "Healy,Solo,Stabby")
check("leader column: count", f.column.note:GetText(), "Players who fit (3)")
check("Fitting: only missing roles", (function()
    local out = Column.Fitting(W.Built().players, { TANK = 0, HEALER = 1, DAMAGER = 0 })
    return #out == 1 and out[1].leader
end)(), "Healy")
check("Fitting: none when not leading", #Column.Fitting(W.Built().players, nil), 0)
local line1 = f.column.lines[1]
check("leader line: invite button", line1.invite:IsShown(), true)
click(line1.invite)
check("one-click invite", M.invited[#M.invited], line1.invite.row.leader)
check("leader line: role icon", line1.roles[1]._atlas ~= nil, true)
UnitGroupRolesAssigned = function(unit) return unit == "player" and "TANK" or (unit == "party1" and "HEALER" or "DAMAGER") end
GetNumGroupMembers = function() return 5 end
W.ListingChanged()
check("complete group: no players", #Column.Players(), 0)
UnitIsGroupLeader, GetNumGroupMembers, IsInRaid, UnitGroupRolesAssigned = nil, nil, nil, nil
M.state.group = nil
W.ListingChanged()
check("leader view gone", f.column.title:GetText(), "Group details")
-- The popup in the details layout searches the same way.
click(f.activity)
check("details: popup", f.popup:IsShown() and f.side:IsShown(), true)
M.state.time = M.state.time + 5
k = searches()
click(sideItem(24))
check("details: popup tick searches", searches(), k + 1)
click(sideItem(24))
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
-- Back to the sidebar: popup closed, the column back, the size back.
click(gRow)
Settings.Set("layout", nil)
check("sidebar again: size", f:GetWidth() .. "x" .. f:GetHeight(), "720x460")
check("sidebar again: popup closed", f.popup:IsShown(), false)
check("sidebar again: activity column", f.side:IsShown() and f.side._points.TOPLEFT[1], f)
check("sidebar again: back in the window's strata", f.side:GetFrameStrata(), "MEDIUM")
check("sidebar again: details float", D.Frame():IsShown() and D.OpenID(), 1)
check("sidebar again: column hidden", f.detail:IsShown() or f.column:IsShown(), false)
D.Close()
-- Every layout builds and lists the rows.
for _, mode in ipairs(Layouts.ORDER) do
    Settings.Set("layout", mode)
    check(mode .. ": builds the rows", #f.pool.used > 0 and f.pool.used[2].kind, "GROUP")
    check(mode .. ": group roles Tank, Healer, DPS", ns.Rows.Slots({ activityIDs = { 22 }, members = {
        { name = "d", role = "DAMAGER" }, { name = "h", role = "HEALER" }, { name = "t", role = "TANK" } } })[1].role, "TANK")
    local pr
    for _, row in ipairs(f.pool.used) do if row.kind == "PLAYER" then pr = row end end
    check(mode .. ": player row role column and level", pr ~= nil and (pr.roles[1]:IsShown() or pr.roles[2]:IsShown() or pr.roles[3]:IsShown()) and pr.level:GetText() ~= nil, true)
    check(mode .. ": one listing button", LP.Frame().post:IsShown() and LP.Frame().remove == nil, true)
    check(mode .. ": window size from its keys", f:GetWidth(), S((Layouts.SizeKeys(mode))))
end
Settings.Set("layout", nil)
-- Options: the dropdown, the description, the size sliders of the layout.
ns.Options.Open("window")
check("layout dropdown on the Window page", rowFor("Layout", "button") ~= nil, true)
check("layout description", (function()
    for _, fr in ipairs(M.frames) do
        if fr.text and fr.text._text and fr.text._text:find("activity list as a column", 1, true) and fr:IsVisible() then return true end
    end
    return false
end)(), true)
Settings.Set("layout", "STACKED")
check("description follows the layout", (function()
    for _, fr in ipairs(M.frames) do
        if fr.text and fr.text._text and fr.text._text:find("Narrow:", 1, true) and fr:IsVisible() then return true end
    end
    return false
end)(), true)
check("side width hidden for stacked", rowFor("Width of the side panel", "slider"), nil)
Settings.Set("layout", nil)
ns.Options.Toggle()
-- Import validation of the layout.
check("layout import: known value kept", ns.Share.Import("FGF1:ts6:layouts7:DETAILS}") and S("layout"), "DETAILS")
Settings.Set("layout", nil)
check("layout import: unknown value skipped", ns.Share.Import("FGF1:ts6:layouts5:GRIDS}"), true)
check("layout import: not stored", ns.DB().layout, nil)
check("layout sizes clamped on import", ns.Share.Import("FGF1:ts12:stackedWidthn99999;}") and S("stackedWidth"), 900)
Settings.ResetProfile()
check("reset to the sidebar", f:GetWidth(), 720)
end

click(f.header.close)
check("close button", W.IsShown(), false)
check("no search was ever blocked", #lfg.blocked, 0)
ForeverGroupFinderChar.roles = nil
lfg.reset()

-- The invite label follows a language change (it was fixed at row creation).
Locale.Set("frFR"); ns.Window.Refresh()
check("invite label follows the language", (function() for _, r in ipairs(ns.Window.Frame().pool.used) do if r.kind == "PLAYER" and r.invite:IsShown() then return r end end end)().invite.label:GetText(), ns.L.INVITE)
check("invite label is French", ns.L.INVITE, "Inviter")
Locale.Set("AUTO"); ns.Window.Refresh()
check("invite label back to the game language", (function() for _, r in ipairs(ns.Window.Frame().pool.used) do if r.kind == "PLAYER" and r.invite:IsShown() then return r end end end)().invite.label:GetText(), ns.L.INVITE)

section("Blizzard redirection")
local B = ns.Blizzard
lfg.reset()
lfg.cats, lfg.catNames = { 2, 114 }, { [2] = "Dungeons", [114] = "Raids" }
lfg.activities = {
    [21] = { categoryID = 2, fullName = "Ragefire Chasm", shortName = "RFC", minLevelSuggestion = 13, maxLevelSuggestion = 18, maxNumPlayers = 5 },
    [31] = { categoryID = 114, fullName = "Molten Core", shortName = "MC", minLevelSuggestion = 60, maxLevelSuggestion = 60, maxNumPlayers = 40 },
}
M.Fire("LFG_LIST_AVAILABILITY_UPDATE")
LFGVanilla_ShowFrame, LFGVanilla_ToggleFrame = nil, nil
W.Hide()
-- A search may run again: the last one answered, the interval passed.
local function nextSearch()
    M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    M.state.time = M.state.time + 100
end
nextSearch()
check("hooked names are strings", (function()
    for _, name in ipairs(B.HOOKED) do if type(name) ~= "string" or name:find("[:%.]") then return false end end
    return true
end)(), true)
check("the toggle and show globals are hooked", table.concat(B.HOOKED, ","), "LFGVanilla_ToggleFrame,LFGVanilla_ShowFrame")
check("nothing hooked before Blizzard's finder loads", B.IsHooked("LFGVanilla_ToggleFrame"), false)
local hooksBefore = #M.hooks
local parent = M.LoadBlizzardFinder()
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
check("toggle hooked when it loads", B.IsHooked("LFGVanilla_ToggleFrame"), true)
check("show hooked when it loads", B.IsHooked("LFGVanilla_ShowFrame"), true)
B.Hook()
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
check("each hooked once", #M.hooks - hooksBefore, 2)
check("some hook exists", #M.hooks > 0, true)
for i, h in ipairs(M.hooks) do check("hook " .. i .. " (" .. tostring(h.name) .. ") is on a global", h.target, "global") end

-- The key binding: LFGVanilla_ToggleFrame(1).
local n = searches()
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("binding opens ours", W.IsShown(), true)
check("its search counts as the key press", searches(), n + 1)
check("Blizzard's window closed again", parent:IsShown(), false)
check("through Blizzard's own toggle, no tab", M.blizzard.toggles[2], "none")
check("closed once", M.blizzard.hides, 1)
nextSearch()
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("binding again closes ours", W.IsShown(), false)
check("Blizzard's stays closed", parent:IsShown(), false)
check("no search on closing", searches(), n + 1)
-- The micro button and the eye: LFGVanilla_ToggleFrame().
M.SecurePress(LFGVanilla_ToggleFrame)
check("micro button opens ours", W.IsShown(), true)
check("micro button: Blizzard's closed", parent:IsShown(), false)
nextSearch()
M.SecurePress(LFGVanilla_ToggleFrame)
check("micro button closes ours", W.IsShown(), false)
-- The queue status button / the eye's menu: LFGVanilla_ShowFrame(1).
M.SecurePress(LFGVanilla_ShowFrame, 1)
check("show opens ours", W.IsShown(), true)
check("show: Blizzard's closed", parent:IsShown(), false)
nextSearch()
M.SecurePress(LFGVanilla_ShowFrame, 2)
check("show keeps ours open", W.IsShown(), true)
W.Hide()
check("nothing refused out of combat", M.blizzard.refused, 0)
-- The Who list (tab 3) is Blizzard's.
M.SecurePress(LFGVanilla_ToggleFrame, 3)
check("who tab: Blizzard's opens", parent:IsShown(), true)
check("who tab: ours stays closed", W.IsShown(), false)
M.SecurePress(LFGVanilla_ToggleFrame, 3)
check("who tab: Blizzard's closes", parent:IsShown(), false)
-- Switched off: Blizzard's finder as usual.
Settings.Set("replaceBlizzard", false)
nextSearch()
n = searches()
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("off: Blizzard's opens", parent:IsShown(), true)
check("off: ours stays closed", W.IsShown(), false)
check("off: no search", searches(), n)
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("off: Blizzard's closes", parent:IsShown(), false)
Settings.Set("replaceBlizzard", nil)
-- Our comment editor opens Blizzard's listing tab on purpose.
lfg.authenticated[2] = true
local hidesBefore = M.blizzard.hides
lfg.click(ns.Listing.OpenCommentEditor, "", 2)
check("comment editor: Blizzard's tab stays open", parent:IsShown(), true)
check("comment editor: not closed by us", M.blizzard.hides, hidesBefore)
check("comment editor: ours not opened by it", W.IsShown(), false)
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("binding then closes Blizzard's", parent:IsShown(), false)
check("and does not open ours", W.IsShown(), false)
lfg.authenticated[2] = nil
-- In combat the panel manager refuses us: both stay, Blizzard's closes after.
nextSearch()
M.state.combat = true
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("combat: ours opens", W.IsShown(), true)
check("combat: Blizzard's left open", parent:IsShown(), true)
check("combat: we did not try", M.blizzard.refused, 0)
check("combat: closing waits", ns.PendingAfterCombat(), 1)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("after combat: Blizzard's closed", parent:IsShown(), false)
check("after combat: ours stays", W.IsShown(), true)
M.state.combat = true
M.SecurePress(LFGVanilla_ToggleFrame, 1)
nextSearch()
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("combat: second press closes both", W.IsShown() or parent:IsShown(), false)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("combat: nothing waits", ns.PendingAfterCombat(), 0)
-- LFG_LIST_SHOW_SEARCH (a "find a group" link, inside its click): Blizzard's
-- browse frame answers it too and searches; one request, one search, with
-- the event's activities, whichever handler runs first.
local browse = M.blizzard.browse
local function lastSearch()
    local q = lfg.searches[#lfg.searches]
    return q[1] .. ":" .. table.concat(q[7] or {}, ",")
end
for _, order in ipairs({ "ours first", "Blizzard's first" }) do
    W.Hide()
    Settings.SetMany({ category = nil, levelRangeOnly = nil })
    W.ResetChecked()
    M.fireFirst = order == "Blizzard's first" and browse or nil
    nextSearch()
    n = searches()
    lfg.click(M.Fire, "LFG_LIST_SHOW_SEARCH", { 31, 21 }, true)
    check(order .. ": show search opens ours", W.IsShown(), true)
    check(order .. ": exactly one search", searches(), n + 1)
    check(order .. ": it searched the event's activities", lastSearch(), "114:31")
    check(order .. ": our category", S("category"), 114)
    check(order .. ": our activities", table.concat(W.CheckedList(), ","), "31")
    check(order .. ": all levels", S("levelRangeOnly"), false)
    check(order .. ": the window waits for that search", W.Status(), "searching")
    check(order .. ": Blizzard's window closed", parent:IsShown(), false)
    M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check(order .. ": its results are ours", W.Status(), "idle")
    -- Again while our window is open.
    M.state.time = M.state.time + 100
    n = searches()
    lfg.click(M.Fire, "LFG_LIST_SHOW_SEARCH", { 21 }, false)
    check(order .. ": open: exactly one search", searches(), n + 1)
    check(order .. ": open: its activities", lastSearch(), "2:21")
    check(order .. ": open: our category", S("category") .. ":" .. table.concat(W.CheckedList(), ","), "2:21")
    check(order .. ": open: searching", W.Status(), "searching")
    M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
end
M.fireFirst = nil
-- Without Blizzard's finder nobody searches: an event never searches.
local answers = B.Answers
B.Answers = function() return false end
local browseEvents = browse._events
browse._events = {}
W.Hide()
n = searches()
M.Fire("LFG_LIST_SHOW_SEARCH", { 31 }, false)   -- outside a click: must not even try
B.Answers, browse._events = answers, browseEvents
check("no Blizzard finder: ours opens", W.IsShown(), true)
check("no Blizzard finder: no search", searches(), n)
check("no Blizzard finder: no search tried", #lfg.blocked, 0)
check("no Blizzard finder: not waiting for one", W.Status() ~= "searching", true)
Settings.SetMany({ category = nil, levelRangeOnly = nil })
W.ResetChecked()
-- A close queued in combat does not close the comment editor opened later.
W.Hide()
M.Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
M.state.combat = true
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("combat: a close waits", ns.PendingAfterCombat(), 1)
lfg.authenticated[2] = true
M.SecurePress(LFGVanilla_ToggleFrame, 1)      -- both closed by the key
lfg.click(ns.Listing.OpenCommentEditor, "", 2)
check("comment editor drops the waiting close", ns.PendingAfterCombat(), 0)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("comment editor stays open after combat", parent:IsShown(), true)
lfg.authenticated[2] = nil
M.SecurePress(LFGVanilla_ToggleFrame, 1)
check("closed by the key", parent:IsShown(), false)
W.Hide()
nextSearch()
n = searches()
lfg.click(SlashCmdList["FOREVERGROUPFINDER"], "search")
check("/fgf search from chat searches (a key press)", searches(), n + 1)
nextSearch()
lfg.click(SlashCmdList["FOREVERGROUPFINDER"], "search")
check("/fgf search while open searches again", searches(), n + 2)
W.Hide()
Settings.Set("replaceBlizzard", false)
lfg.click(M.Fire, "LFG_LIST_SHOW_SEARCH", { 21 }, false)
check("show search off: ours stays closed", W.IsShown(), false)
Settings.SetMany({ replaceBlizzard = nil, category = nil, levelRangeOnly = nil })
W.ResetChecked()
check("no search was blocked", #lfg.blocked, 0)
LFGVanilla_ShowFrame, LFGVanilla_ToggleFrame = nil, nil
lfg.reset()

section("Solo names")
lfg.reset()
lfg.results[5] = { searchResultID = 5, activityIDs = { 1 }, leaderName = "Lacey", numMembers = 1, age = 3 }
lfg.members[5] = { { level = 20, classFilename = "WARRIOR" } }
local r5 = ns.Finder.Result(5)
check("solo: member without a name gets leaderName", r5.members[1].name, "Lacey")
lfg.results[6] = { searchResultID = 6, activityIDs = { 1 }, numMembers = 1, age = 3 }
lfg.members[6] = { { level = 20 } }
lfg.leaders = { [6] = { name = "Ilvea", level = 20, classFilename = "MAGE", areaName = "Stormwind City" } }
local r6 = ns.Finder.Result(6)
check("solo: name from the leader info", r6.leaderName, "Ilvea")
check("solo: member name from the leader info", r6.members[1].name, "Ilvea")
check("solo: class from the leader info", r6.members[1].classFile, "MAGE")
check("solo: area from the leader info", r6.members[1].area, "Stormwind City")
check("solo row shows the name", ns.Results.Build({ r6 }, { filters = {} }).players[1].leader, "Ilvea")
lfg.results[7] = { searchResultID = 7, activityIDs = { 1 }, numMembers = 1, age = 3 }
lfg.members[7] = {}
lfg.leaders = { [7] = { name = "Grim", level = 21, classFilename = "WARRIOR" } }
check("solo without member info: member from the leader info", ns.Finder.Result(7).members[1].name, "Grim")
lfg.results[8] = { searchResultID = 8, activityIDs = { 1 }, numMembers = 1, age = 3 }
lfg.members[8] = { { level = 20 } }
lfg.leaders = { [8] = { level = 20 } }
check("no name anywhere: unknown (nil)", ns.Results.Build({ ns.Finder.Result(8) }, { filters = {} }).players[1].leader, nil)
lfg.secret = true
lfg.leaders = { [6] = { name = "Ilvea" } }
check("secret leader name stays nil", ns.Finder.Result(6).leaderName, nil)
lfg.secret = false
lfg.leaders = nil
lfg.reset()

section("Source rules")
-- Listing.lua may name exactly two Blizzard things: the comment box it prefills
-- (inside a pcall) and the global that shows the finder.
local function touchesBlizzardFinder(code, file)
    if file == "Listing.lua" then
        code = code:gsub("LFGListingComment", ""):gsub("LFGVanilla_ShowFrame", "")
    elseif file == "Blizzard.lua" then
        -- The one read of Blizzard's window: is it shown?
        code = code:gsub('type%(LFGParentFrame%) == "table" and LFGParentFrame:IsShown%(%)', "")
    end
    return code:find("LFGParentFrame", 1, true) or code:find("GroupFinder[%w_]*Frame") or code:find("LFGListing", 1, true)
end
check("lint: LFGListingComment allowed in Listing.lua", touchesBlizzardFinder("local b = LFGListingComment.EditBox", "Listing.lua"), nil)
check("lint: LFGVanilla_ShowFrame allowed in Listing.lua", touchesBlizzardFinder("LFGVanilla_ShowFrame(1)", "Listing.lua"), nil)
check("lint: LFGListingComment caught elsewhere", touchesBlizzardFinder("LFGListingComment.EditBox", "Window.lua") ~= nil, true)
check("lint: other LFGListing frames caught in Listing.lua", touchesBlizzardFinder("LFGListingFrame:Hide()", "Listing.lua") ~= nil, true)
check("lint: LFGParentFrame caught in Listing.lua", touchesBlizzardFinder("LFGParentFrame:Hide()", "Listing.lua") ~= nil, true)
check("lint: the IsShown read allowed in Blizzard.lua", touchesBlizzardFinder('return type(LFGParentFrame) == "table" and LFGParentFrame:IsShown() == true', "Blizzard.lua"), nil)
check("lint: other LFGParentFrame use caught in Blizzard.lua", touchesBlizzardFinder("LFGParentFrame:SetAlpha(0)", "Blizzard.lua") ~= nil, true)
check("lint: IsShown read caught elsewhere", touchesBlizzardFinder('type(LFGParentFrame) == "table" and LFGParentFrame:IsShown()', "Window.lua") ~= nil, true)
-- Blizzard.lua hooks by global name only (Blizzard.HOOKED, checked above).
local function strayHooks(code, file)
    if file == "Blizzard.lua" then code = code:gsub("hooksecurefunc%(name, function", "") end
    return code:find("hooksecurefunc")
end
check("lint: the named hook allowed in Blizzard.lua", strayHooks("hooksecurefunc(name, function(tab) end)", "Blizzard.lua"), nil)
check("lint: a method hook caught in Blizzard.lua", strayHooks("hooksecurefunc(LFGParentFrame, \"Show\", f)", "Blizzard.lua") ~= nil, true)
check("lint: a hook caught elsewhere", strayHooks("hooksecurefunc(name, function() end)", "Window.lua") ~= nil, true)
check("Listing.lua never calls SetText directly", (read("Listing.lua"):gsub("%-%-[^\n]*", "")):find("[:%.]SetText%s*%(") , nil)
for _, f in ipairs(tocFiles()) do
    local code = read(f):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    check("only Finder.lua calls C_LFGList (" .. f .. ")", f == "Finder.lua" or code:find("C_LFGList", 1, true) == nil, true)
    check("no CVar write in " .. f, code:find("SetCVar", 1, true), nil)
    check("no combat log event in " .. f, code:find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), nil)
    check("no hooksecurefunc call in " .. f, strayHooks(code, f), nil)
    -- The one allowed call closes the Settings panel before our options open.
    local rest = code
    if f == "Options/Panel.lua" then rest = rest:gsub("HideUIPanel and SettingsPanel", ""):gsub("pcall%(HideUIPanel, SettingsPanel%)", "") end
    check("no HideUIPanel in " .. f, rest:find("HideUIPanel", 1, true), nil)
    check("no SetParent in " .. f, rest:find("SetParent", 1, true), nil)
    check("no LFG or GroupFinder frame touched in " .. f, touchesBlizzardFinder(rest, f), nil)
    check("no loadstring in " .. f, code:find("loadstring", 1, true), nil)
end

section("Secret lint")
-- A cheap static check, because the mock cannot catch it: on the client even
-- `secret == nil`, `secret ~= nil`, `not secret`, `secret and/or x` and
-- `if secret then` raise, while Lua 5.1 has no __eq across types and lets
-- them pass here. Every line that tests one of the field names below in one
-- of those ways must, on the same line, either check issecret( / issecretvalue( / present( /
-- Present( first, or say why the value is plain with a "-- plain: ..."
-- comment. Keep the list in step with what C_LFGList's GetSearchResultInfo /
-- LeaderInfo / PlayerInfo / GetActiveEntryInfo can hand out in secret
-- (Finder.lua converts them once; nothing else may test them).
local SECRET_FIELDS = {
    "name", "comment", "leaderName", "voiceChat", "numMembers", "age", "level", "class", "classFilename",
    "areaName", "guid", "activityIDs", "activityID", "role", "isLeader", "playerName", "fullName",
    "requiredItemLevel", "itemLevel", "autoAccept", "isDelisted", "searchResultID", "id", "title",
    "value", "timestamp", "playstyle", "generalPlaystyle",
}
-- Every file the TOC loads except the strings.
local LINT_FILES = {}
for _, f in ipairs(tocFiles()) do
    if not f:match("^Locales/") then LINT_FILES[#LINT_FILES + 1] = f end
end
local function lintLine(line)
    if line:find("%-%- plain:") then return nil end
    local code = line:gsub("%-%-.*$", "")
    if code:find("issecret(", 1, true) or code:find("issecretvalue(", 1, true) or code:find("present(", 1, true) or code:find("Present(", 1, true) then return nil end
    for _, field in ipairs(SECRET_FIELDS) do
        local w = "%f[%w_]" .. field .. "%f[^%w_]"
        for _, pat in ipairs({ w .. "%s*[=~]=%s*nil", "nil%s*[=~]=%s*[%w_%.]*" .. w, w .. "%s+or%f[^%w_]",
            w .. "%s+and%f[^%w_]", "not%s+[%w_%.]*" .. w, "if%s+[%w_%.]*" .. w .. "%s+then" }) do
            if code:find(pat) then return field end
        end
    end
end
check("lint: == nil caught", lintLine("        if comment == nil then comment = \"\" end"), "comment")
check("lint: ~= nil caught", lintLine("    if info.leaderName ~= nil then x() end"), "leaderName")
check("lint: or caught", lintLine("    local n = info.name or \"?\""), "name")
check("lint: truthiness caught", lintLine("    if info.areaName then return 1 end"), "areaName")
check("lint: not caught", lintLine("    if not r.numMembers then return end"), "numMembers")
check("lint: guarded line passes", lintLine("    if not issecretvalue(comment) and comment == nil then comment = 1 end"), nil)
check("lint: plain note passes", lintLine("    if line.title then   -- plain: a flag"), nil)
check("lint: other names pass", lintLine("    if names == nil or titles then end"), nil)
for _, f in ipairs(LINT_FILES) do
    local n = 0
    for line in io.lines(ROOT .. "/" .. f) do
        n = n + 1
        local hit = lintLine(line)
        if hit then check(("secret lint %s:%d (%s)"):format(f, n, hit), line, "explicit issecret or -- plain:") end
    end
end


section("No accidental globals")
local allowed = { SLASH_FOREVERGROUPFINDER1 = true, SLASH_FOREVERGROUPFINDER2 = true, ForeverGroupFinderProfiles = true,
    ForeverGroupFinderChar = true, ForeverGroupFinder_OnAddonCompartmentClick = true,
    ForeverGroupFinder_OnAddonCompartmentEnter = true, ForeverGroupFinder_OnAddonCompartmentLeave = true }
for _, f in ipairs(tocFiles()) do
    local listing = io.popen("luac5.1 -l -p '" .. ROOT .. "/" .. f .. "' 2>/dev/null"):read("*a")
    for name in listing:gmatch("SETGLOBAL%s+%d+%s+[%-%d]*%s*; ([%w_]+)") do
        check(f .. " sets global " .. name, allowed[name] or false, true)
    end
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
