-- Tests for Forever Group Finder. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
-- Events the client knows: registering any other name throws, as in the game.
M.validEvents = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true }
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
    minInterval = 3, levelRangeOnly = true, category = 2, sortFriendsFirst = true,
    filterMyRole = false, filterLevelFits = false, hideSeen = false,
    roleOverride = "AUTO", markOpenSlot = true, showPlayers = true, rowHeight = 22, playerRowHeight = 34,
    memoryMinutes = 30,
    expiryWarnMinutes = 5,
    borderStyle = "NONE", borderSize = 1, cornerRadius = 10,
    shadowEnabled = true, shadowSize = 9, shadowAlpha = 65,
    bgMode = "SOLID", bgAlpha = 85, bgTexture = "Blizzard Dialog Background Gold", headerLine = true,
    headerFont = "Friz Quadrata", headerSize = 14, headerFlag = "SHADOW",
    activityFont = "Friz Quadrata", activitySize = 12, activityFlag = "SHADOW",
    nameFont = "Friz Quadrata", nameSize = 12, nameFlag = "SHADOW",
    commentFont = "Friz Quadrata", commentSize = 11, commentFlag = "SHADOW",
    smallFont = "Friz Quadrata", smallSize = 10, smallFlag = "SHADOW",
}
local expectedCount = 0
for key, want in pairs(EXPECTED) do
    expectedCount = expectedCount + 1
    check("default " .. key, D[key], want)
end
local COLORS = {
    borderColor = { 0, 0, 0, 1 }, bgColor = { 0.047, 0.047, 0.055 }, headerColor = { 1, 0.82, 0.29 },
    activityColor = { 1, 0.82, 0.29 }, nameColor = { 1, 1, 1 }, commentColor = { 0.79, 0.76, 0.69 },
    smallColor = { 0.55, 0.54, 0.5 },
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
    minInterval = { 3, 15 }, rowHeight = { 16, 36 }, playerRowHeight = { 26, 50 }, memoryMinutes = { 5, 240 },
    expiryWarnMinutes = { 1, 15 }, borderSize = { 1, 8 }, cornerRadius = { 0, 12 }, shadowSize = { 1, 20 },
    x = { -4000, 4000 }, y = { -4000, 4000 },
    shadowAlpha = { 0, 100 }, bgAlpha = { 0, 100 }, headerSize = { 8, 24 }, activitySize = { 8, 20 },
    nameSize = { 8, 20 }, commentSize = { 8, 18 }, smallSize = { 7, 16 },
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
check("text styles", table.concat(Settings.TEXT_STYLES, ","), "header,activity,name,comment,small")
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
Settings.Set("minInterval", 2)
check("search interval never below 3 s", S("minInterval"), 3)
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
Settings.Set("roleOverride", "TANK")
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
check("enum back", S("roleOverride"), "TANK")
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
check("bad enum values skipped", ns.Share.Import("FGF1:ts12:roleOverrides4:BOSSs11:borderStyles3:BAD"
    .. "s6:bgModes5:SOLIDs10:headerFlags6:Italic}"), true)
check("bad role not stored", ns.DB().roleOverride, nil)
check("bad borderStyle not stored", ns.DB().borderStyle, nil)
check("bad flag not stored", ns.DB().headerFlag, nil)
check("good enum kept", ns.Share.Import("FGF1:ts12:roleOverrides6:HEALERs8:nameFlags7:OUTLINE}"), true)
check("role imported", S("roleOverride"), "HEALER")
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
check("pages", table.concat(pageIds, ","), "general,profiles")
for _, page in ipairs(ns.Options.PAGES) do
    local ok, err = pcall(ns.Options.ShowPage, page.id)
    check("page " .. page.id .. " builds", ok, true)
    if not ok then print(err) end
end
check("nav buttons", M.byName["ForeverGroupFinderNavgeneral"] ~= nil and M.byName["ForeverGroupFinderNavprofiles"] ~= nil, true)
ns.Options.ShowPage("general")
check("replace row", rowFor("Open this finder instead", "box") ~= nil, true)
check("minimap row", rowFor("Minimap button", "box") ~= nil, true)
check("compartment row", rowFor("addon list", "box") ~= nil, true)
check("language dropdown in the nav", ns.Options.languageRow ~= nil or rowFor("Language", "button") ~= nil, true)
ns.Options.ShowPage("profiles")
check("profile row", rowFor("Active profile", "button") ~= nil, true)
ns.Options.Toggle()
check("closed", ns.Options.IsShown(), false)
check("interface options page", M.registered[1], "Forever Group Finder")

section("Minimap button, compartment and slash command")
local mb = M.byName["ForeverGroupFinderMinimapButton"]
check("minimap button", mb ~= nil, true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click locks", S("locked"), true)
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click unlocks", S("locked"), false)
M.chat = {}
mb:GetScript("OnClick")(mb, "LeftButton")
check("left-click toggles the window (the stub says so)", M.chat[1] ~= nil and M.chat[1]:find("not built yet", 1, true) ~= nil, true)
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
M.chat = {}
ForeverGroupFinder_OnAddonCompartmentClick(nil, "LeftButton")
check("compartment left-click toggles the window", M.chat[1] ~= nil, true)
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
M.chat = {}
SlashCmdList["FOREVERGROUPFINDER"]("")
check("/fgf toggles the window", M.chat[1] ~= nil and M.chat[1]:find("not built yet", 1, true) ~= nil, true)
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
M.chat = {}
SlashCmdList["FOREVERGROUPFINDER"]("what")
check("usage", M.chat[1] ~= nil and M.chat[1]:find("/fgf", 1, true) ~= nil, true)

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

section("Source rules")
for _, f in ipairs(tocFiles()) do
    local code = read(f):gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    check("only Finder.lua calls C_LFGList (" .. f .. ")", f == "Finder.lua" or code:find("C_LFGList", 1, true) == nil, true)
    check("no CVar write in " .. f, code:find("SetCVar", 1, true), nil)
    check("no combat log event in " .. f, code:find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), nil)
    check("no hooksecurefunc call in " .. f, code:find("hooksecurefunc%("), nil)
    -- The one allowed call closes the Settings panel before our options open.
    local rest = code
    if f == "Options/Panel.lua" then rest = rest:gsub("HideUIPanel and SettingsPanel", ""):gsub("pcall%(HideUIPanel, SettingsPanel%)", "") end
    check("no HideUIPanel in " .. f, rest:find("HideUIPanel", 1, true), nil)
    check("no SetParent in " .. f, rest:find("SetParent", 1, true), nil)
    check("no LFG or GroupFinder frame touched in " .. f, rest:find("LFGParentFrame", 1, true)
        or rest:find("GroupFinder[%w_]*Frame") or rest:find("LFGListing", 1, true), nil)
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
