-- Themes (Themes.lua, ThemeArt.lua): a settings set per theme, Classic
-- kept, first use from Classic, reset, positions copied with undo, the
-- revision upgrade, the art round the frame. Called from run.lua.
return function(t)
    local ns, M, check, section = t.ns, t.M, t.check, t.section
    local Settings, Themes = ns.Settings, ns.Themes
    local S = Settings.Get

    section("Themes")
    Settings.ResetProfile()
    ns.DB().themeSets = nil
    -- An own Classic look.
    Settings.SetMany({ width = 800, x = -120, point = "TOP", relPoint = "TOP", borderStyle = "GOLD", cornerRadius = 8,
        rowHeight = 30, headerSize = 18 })
    check("starts classic", Themes.Current(), "CLASSIC")
    check("nothing stored yet", #Themes.Stored(), 0)

    -- A theme the first time: Classic's settings with the theme's look.
    check("switch to wood", Themes.Switch("WOOD"), true)
    check("wood: current", Themes.Current(), "WOOD")
    check("wood: stored as the setting", S("theme"), "WOOD")
    check("wood: keeps the place", S("x"), -120)
    check("wood: keeps the size", S("width"), 800)
    check("wood: keeps the list look", S("rowHeight"), 30)
    check("wood: the family's gold ring", S("borderStyle") .. "/" .. S("borderSize"), "GOLD/3")
    check("wood: its corners", S("cornerRadius"), 3)
    check("wood: its header font", S("headerFont"), "Cinzel")
    check("wood: the client's outline", S("headerFlag"), "OUTLINE")
    check("wood: list rows keep their font", S("commentFont"), "Friz Quadrata")
    local sets = ns.DB().themeSets
    check("wood: classic stored", sets.CLASSIC.width, 800)
    check("wood: classic stored with its look", sets.CLASSIC.cornerRadius, 8)
    check("wood: the live set is not stored twice", sets.WOOD, nil)

    -- Changes stay with their theme.
    Settings.Set("x", -50)
    check("switch to pixel", Themes.Switch("PIXEL"), true)
    check("pixel: from classic, not from wood", S("x"), -120)
    check("pixel: header larger", S("headerSize"), 22)
    check("pixel: two to copy from", #Themes.Stored(), 2)

    -- Positions from another theme, and back.
    local undo = Themes.CopyPlacement("WOOD")
    check("copy: done", type(undo), "table")
    check("copy: place taken", S("x"), -50)
    check("copy: look kept", S("headerFont"), "VT323")
    check("copy: undo", Themes.Restore(undo), true)
    check("copy: undone", S("x"), -120)
    check("copy from a theme never used", select(2, Themes.CopyPlacement("FROST")), "GONE")

    -- Back to Classic: every setting as it was.
    check("back to classic", Themes.Switch("CLASSIC"), true)
    check("classic: own border", S("borderStyle"), "GOLD")
    check("classic: own corners", S("cornerRadius"), 8)
    check("classic: own header", S("headerFont") .. "/" .. S("headerSize"), "Friz Quadrata/18")
    check("classic: no theme stored in the profile", ns.DB().theme, nil)
    check("classic: not kept twice", ns.DB().themeSets.CLASSIC, nil)
    check("wood again", Themes.Switch("WOOD"), true)
    check("wood again: its own change came back", S("x"), -50)

    -- Reset: the theme anew from Classic.
    check("reset", Themes.Reset(), true)
    check("reset: from classic", S("x"), -120)
    check("reset: still wood", Themes.Current(), "WOOD")
    check("unknown theme refused", select(2, Themes.Switch("NOPE")), "UNKNOWN")

    -- The profile reset and an import change the current theme only.
    Settings.Set("rowHeight", 20)
    Settings.ResetProfile()
    check("profile reset: theme kept", Themes.Current(), "WOOD")
    check("profile reset: its look over the defaults", S("cornerRadius"), 3)
    check("profile reset: defaults", S("rowHeight"), Settings.DEFAULTS.rowHeight)
    check("profile reset: classic kept", ns.DB().themeSets.CLASSIC.width, 800)
    local text = ns.Share.Export()
    check("export: no theme sets", text:find("themeSets", 1, true), nil)
    check("export: no theme", text:find("s5:theme", 1, true), nil)
    check("import", ns.Share.Import("FGF1:ts5:themes5:COMICs9:rowHeightn24;}"), true)
    check("import: theme not taken over", Themes.Current(), "WOOD")
    check("import: settings taken over", S("rowHeight"), 24)
    check("import: classic kept", ns.DB().themeSets.CLASSIC.width, 800)
    check("classic after all that", Themes.Switch("CLASSIC") and S("width") .. "/" .. S("borderStyle"), "800/GOLD")

    -- Non-Latin clients keep the header's font.
    M.locale = "koKR"
    Themes.Switch("TECH")
    check("koKR: header font kept", S("headerFont"), "Friz Quadrata")
    check("koKR: theme border", S("borderSize"), 1)
    M.locale = "enUS"
    Themes.Switch("CLASSIC")

    check("glass HD: lighter fill to show the glass", Themes.SPECS.GLASS_HD.look.bgAlpha .. "/"
        .. Themes.SPECS.GLASS.look.bgAlpha, "60/90")
    -- Frost's header: a 1 px drop shadow, no outline; every other theme outlined.
    for id, spec in pairs(Themes.SPECS) do
        if spec.look then
            check(id .. ": header flag", spec.look.headerFlag, LibForeverThemes.BaseTheme(id) == "FROST" and "SHADOW" or "OUTLINE")
        end
    end
    local frostHeader = UIParent:CreateFontString()
    ns.Media.ApplyText(frostHeader, { font = Themes.SPECS.FROST.font, size = 16, flag = Themes.SPECS.FROST.look.headerFlag,
        color = { 1, 1, 1 } })
    check("frost: header drawn without outline, shadowed", select(3, frostHeader:GetFont()) .. " "
        .. table.concat({ frostHeader:GetShadowOffset() }, ","), " 1,-1")
    local frost = Themes.Seed("FROST", {})
    check("frost: all in Julius Sans One", frost.headerFont .. "|" .. frost.nameFont .. "|" .. frost.activityFont
        .. "|" .. frost.smallFont, "Julius Sans One|Julius Sans One|Julius Sans One|Julius Sans One")
    check("wood: list fonts left alone", Themes.Seed("WOOD", {}).nameFont, nil)

    -- A theme stored under an older revision is made anew; Classic stays.
    Themes.Switch("WOOD")
    Settings.Set("x", 77)
    local db = ns.DB()
    db.themeSets.revision = 9
    db.themeSets.TECH = { theme = "TECH", x = 5 }
    Settings.Set("borderSize", 7)
    Themes.Upgrade()
    check("upgrade: theme in use made anew", S("borderSize"), 3)
    check("upgrade: from classic", S("x"), -120)
    check("upgrade: stale set dropped", db.themeSets.TECH, nil)
    check("upgrade: classic kept", db.themeSets.CLASSIC.width, 800)
    check("revision 10: sets rebuilt (Frost all in Julius Sans One)", db.themeSets.revision, 10)
    check("upgrade: library seed noted", db.themeSets.seedRevision, LibForeverThemes.SEED_REVISION)
    Settings.Set("borderSize", 5)
    Themes.Upgrade()
    check("upgrade: once only", S("borderSize"), 5)
    -- Sets stored by the release before MINOR 3 (revision 10, no seed
    -- revision) survive a login untouched.
    db.themeSets.seedRevision = nil
    db.themeSets.TECH = { theme = "TECH", x = 5 }
    Themes.Upgrade()
    check("upgrade: the current release's sets survive", db.themeSets.TECH and db.themeSets.TECH.x, 5)
    check("upgrade: theme in use kept", S("borderSize"), 5)
    db.themeSets.TECH = nil

    -- A first pick ships the author's look: the stored sets (place, size, lock,
    -- layout, filters, category and templates left out) equal the seeds.
    local function sameSet(a, b)
        for k, v in pairs(a) do if not Settings.SameValue(v, b[k]) then return k end end
        for k in pairs(b) do if a[k] == nil then return k end end
        return true
    end
    check("seed: the author's Parchment", sameSet(Themes.Seed("PARCHMENT", {}), { theme = "PARCHMENT",
        borderStyle = "FLAT", borderSize = 2, borderColor = { 0.29, 0.2, 0.12, 1 }, cornerRadius = 2,
        bgColor = { 0.13, 0.09, 0.05 }, bgAlpha = 0, shadowSize = 5, shadowAlpha = 45, headerFlag = "OUTLINE",
        headerFont = "IM Fell English SC", headerSize = 18, headerColor = { 1, 0.93, 0.78 } }), true)
    check("seed: the author's Pixel", sameSet(Themes.Seed("PIXEL", {}), { theme = "PIXEL",
        borderStyle = "FLAT", borderSize = 3, borderColor = { 1, 0.95, 0.91, 1 }, cornerRadius = 0,
        bgColor = { 0, 0, 0 }, bgAlpha = 0, shadowEnabled = false, headerFlag = "OUTLINE",
        headerFont = "VT323", headerSize = 21, headerColor = { 0.6, 1, 0.5 } }), true)
    -- A set stored before stays as it is through a login.
    db.themeSets.TECH = { theme = "TECH", borderSize = 4 }
    Themes.Upgrade()
    check("login: stored set untouched", db.themeSets.TECH and db.themeSets.TECH.borderSize, 4)
    db.themeSets.TECH = nil

    -- The registry for a central theme picker.
    local entry = ForeverThemes and ForeverThemes.ForeverGroupFinder
    check("registry entry", entry ~= nil and entry.title, "Forever Group Finder")
    check("registry: current", entry.Current(), "WOOD")
    check("registry: switch", entry.Switch("FROST"), true)
    check("registry: current follows", entry.Current(), "FROST")
    check("registry: unknown", select(2, entry.Switch("NOPE")), "UNKNOWN")

    -- The choice at the top of General.
    local general = ns.Options.PAGES[1].rows()
    check("options: General first", ns.Options.PAGES[1].id, "general")
    check("options: theme section first", general[1].label, "OPT_THEME")
    check("options: theme choice", general[2].key, "theme")
    general[2].set("RUNESTONE")
    check("options: choosing switches", Themes.Current(), "RUNESTONE")
    check("options: copy row while themed", general[10].visible(), true)
    check("options: colours under any theme", general[3].visible(), true)
    general[2].set("CLASSIC")
    check("options: no copy row on classic", general[10].visible(), false)
    check("options: no colours on classic", general[3].visible(), false)
    check("options: no reset on classic", general[11].visible(), false)
    general[2].set("COMIC")
    check("options: comic colour under the comic", general[3].visible() and general[3].get(), "GREY")
    general[2].set("CLASSIC")
    check("options: classic restored", S("width") .. "/" .. S("cornerRadius"), "800/8")

    -- Following the hub "Forever Themes": pickers locked, a line and a
    -- button to its window, no "Apply to all"; own theme / no hub: as before.
    local Lib = LibForeverThemes
    local follows, opened = true, false
    local function rowsShown()
        local out = {}
        for _, r in ipairs(general) do
            if not r.visible or r.visible() then
                local label = r.label or r.buttons[1].label
                if type(label) == "function" then label = label() end
                out[#out + 1] = label .. (r.enabled and (r.enabled() and "+" or "-") or "")
            end
        end
        return table.concat(out, " ", 1, 6)
    end
    Themes.Switch("WOOD")
    local others = Themes.HasOthers
    Themes.HasOthers = function() return true end
    check("no hub: where to get it", rowsShown(),
        "OPT_THEME OPT_THEME_CHOICE+ OPT_THEME_COLOR+ " .. Lib.Text("HUB_MISSING") .. " Download link OPT_THEME_HINT")
    M.popups = {}
    general[7].buttons[1].onClick()
    check("no hub: link in Blizzard's text popup", M.popups[1] and M.popups[1].which, "LIBFOREVERTHEMES_HUB_LINK")
    local box = { SetText = function(self, text) self.text = text end, HighlightText = function() end,
        SetFocus = function() end }
    StaticPopupDialogs.LIBFOREVERTHEMES_HUB_LINK.OnShow({ GetEditBox = function() return box end })
    check("no hub: the hub's CurseForge page", box.text, "https://www.curseforge.com/wow/addons/forever-themes")
    Lib.SetHub({ Follows = function(folder) return folder == "ForeverGroupFinder" and follows end,
        OpenOptions = function() opened = true end })
    check("hub, following: locked, line, button, no apply to all", rowsShown(),
        "OPT_THEME OPT_THEME_CHOICE- OPT_THEME_COLOR- Follows Forever Themes Open Forever Themes OPT_THEME_HINT")
    ns.Locale.Set("deDE")   -- the addon's own language, not the (English) client's
    check("german addon, english client: the line", rowsShown():find("Folgt Forever Themes", 1, true) ~= nil, true)
    ns.Locale.Set("AUTO")
    general[5].buttons[1].onClick()
    check("hub: the button opens its window", opened, true)
    -- A profile switch, reset or import replaced our theme: the hub puts its own back.
    local synced = 0
    Lib.SetHub({ Follows = function(folder) return folder == "ForeverGroupFinder" and follows end,
        OpenOptions = function() opened = true end, Sync = function() synced = synced + 1 end })
    Settings.ResetProfile()
    ns.Share.Import(ns.Share.Export())
    ns.SwitchProfile(ns.ActiveProfile())
    check("hub: synced after reset, import, switch", synced, 3)
    follows = false
    check("hub, own theme: as today", rowsShown(),
        "OPT_THEME OPT_THEME_CHOICE+ OPT_THEME_COLOR+ OPT_THEME_HINT OPT_THEME_ALL OPT_THEME_COPY_FROM")
    Lib.SetHub(nil)
    Themes.HasOthers = others
    Themes.Switch("CLASSIC")

    -- The art: the ring goes round the backdrop, all of it inside the edge
    -- Classic has (frame plus Classic's ring of 1), ornaments too.
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    Themes.Switch("WOOD")
    local box, radius = ns.ThemeArt.Style(frame, 3)
    local art = frame.themeArt
    check("art: the ring round the backdrop", box, art.back)
    check("art: frame's rounding", radius, 3)
    check("art: body below the header", frame.bg._points.TOPLEFT[4], -ns.Header.HEIGHT)
    check("art: four rivets", art.ornaments[4]:IsShown(), true)
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        if id ~= Themes.CLASSIC then
            Themes.Switch(id)
            Settings.Set("borderSize", Themes.SPECS[id].look.borderSize)
            ns.ThemeArt.Style(frame, 3)
            local ring = S("borderStyle") == "NONE" and 0 or S("borderSize")
            local inset = art.back._points.TOPLEFT[3]
            check(id .. ": outer edge where Classic's is", ring - inset, 1)
            local body = frame.bg._points.BOTTOMRIGHT[4]
            check(id .. ": band within the frames' inner padding", body >= 0 and body <= 8, true)
            for i, piece in ipairs(art.ornaments) do
                if piece:IsShown() then
                    local point = piece._points[ns.Corners.POINTS[i]]
                    local x = (i == 1 or i == 3) and point[3] or -point[3]
                    check(id .. ": ornament " .. i .. " inside the edge", x + ring >= 0, true)
                end
            end
        end
    end
    Themes.Switch("WOOD")
    Themes.Switch("PARCHMENT")
    ns.ThemeArt.Style(frame, 2)
    check("art: one seal", tostring(art.ornaments[3]:IsShown()) .. tostring(art.ornaments[1]:IsShown()), "truefalse")
    Themes.Switch("COMIC")
    ns.ThemeArt.Style(frame, 0)
    local h = ns.Header.Create(CreateFrame("Frame", nil, UIParent))
    local b = ns.Header.Button(h, "Gear", "", function() end)
    ns.Header.Layout(h)
    check("comic: header icon in ink", b.paintColor[1], 0.1)
    b.hover = true
    ns.Header.Paint(b)
    check("comic: hover visibly lighter", b.paintColor[1], 0.4)
    check("comic: note in ink", ns.Header.NoteStyle().color[1], 0.1)
    check("art: comic paper grey as everywhere", table.concat(art.back._vertex, ","), "0.7,0.7,0.7,1")
    -- The comic's colours: paper and the headers' accent, outside the sets.
    local entry = _G.ForeverThemes.ForeverGroupFinder
    local function paper() ns.ThemeArt.Style(frame, 0); return table.concat(art.back._vertex, ",") end
    local function accent() return table.concat(Settings.TextStyle("header").color, ",") end
    check("comic colours: list", table.concat(entry.Colors("COMIC"), ","), "GREY,DARKGREY,BLACK,WHITE,YELLOW,BLUE,RED,GREEN,PURPLE")
    check("comic colours: grey by default", entry.Color("COMIC"), "GREY")
    check("comic grey: headers as today", accent(), "1,0.85,0.1")
    check("comic blue: set", entry.SetColor("BLUE"), true)
    check("comic blue: paper", paper(), "0.45,0.6,0.86,1")
    check("comic blue: headers yellow", accent(), "1,0.9,0.1")
    check("comic yellow: set", Themes.SetColor("YELLOW"), true)
    check("comic yellow: headers blue", accent(), "0.15,0.45,0.95")
    check("comic colour: not in the set", S("headerColor")[1] .. "/" .. tostring(ns.DB().comicColor), "1/nil")
    check("comic colour: unknown refused", select(2, Themes.SetColor("NOPE")), "UNKNOWN")
    Themes.Switch("WOOD")
    check("comic colour: nothing under wood", accent(), table.concat(Themes.SPECS.WOOD.look.headerColor, ","))
    check("comic colour: chosen under wood", Themes.SetColor("RED", "COMIC"), true)
    Themes.Switch("COMIC")
    check("comic colour: survives the switch", entry.Color("COMIC") .. " " .. paper(), "RED 0.86,0.44,0.4,1")
    check("comic black: set", Themes.SetColor("BLACK"), true)
    check("comic black: paper", paper(), "0.16,0.16,0.16,1")
    check("comic black: headers yellow", accent(), "1,0.9,0.1")
    b.hover = false
    ns.Header.Paint(b)
    check("comic black: header icon light", b.paintColor[1], 0.85)
    b.hover = true
    ns.Header.Paint(b)
    check("comic black: hover brighter", b.paintColor[1], 1)
    b.hover = false
    check("comic black: note light", ns.Header.NoteStyle().color[1], 0.9)
    local toggle = { isActive = function() return false end }
    check("comic black: off icon", ns.Header.ButtonColor(toggle)[1], 0.55)
    toggle.isActive = function() return true end
    check("comic black: on icon in the accent", table.concat(ns.Header.ButtonColor(toggle), ","), "1,0.9,0.1")
    check("comic white: set", Themes.SetColor("WHITE"), true)
    check("comic white: paper", paper(), "1,1,1,1")
    check("comic white: headers blue", accent(), "0.15,0.45,0.95")
    ns.Header.Paint(b)
    check("comic white: header icon in ink", b.paintColor[1], 0.1)
    ns.AccountDB().themeColors.COMIC = "NOPE"
    check("comic colour: unknown stored reads grey", Themes.Color(), "GREY")
    check("comic grey back: set", Themes.SetColor("GREY"), true)
    check("comic grey back: paper", paper(), "0.7,0.7,0.7,1")
    check("comic grey back: headers", accent(), "1,0.85,0.1")
    check("comic grey back: nothing stored", ns.AccountDB().themeColors.COMIC, nil)
    -- Every theme's colours: the first is today's look; any other the grey
    -- texture tinted to target / mean, with its accent on the headers.
    local function rgb(t) return table.concat({ t[1], t[2], t[3] }, ",") end
    local function look() ns.ThemeArt.Style(frame, 0); return art.back._texture .. " " .. table.concat(art.back._vertex, ",") end
    local PATH = "Interface\\AddOns\\ForeverGroupFinder\\Libs\\LibForeverThemes\\Media\\Themes\\"
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        if id ~= "CLASSIC" and id ~= "COMIC" then
            Themes.Switch(id)
            local a, colours = Themes.SPECS[id].art, entry.Colors()
            check(id .. ": the first colour by default", entry.Color(), colours[1])
            local tint = a.tint or { 1, 1, 1, 1 }
            check(id .. ": default as today", look(), PATH .. a.back .. " " .. table.concat(tint, ","))
            -- An HD default wears its own accent where it has one.
            check(id .. ": default headers as today", accent(),
                rgb(LibForeverThemes.Accent(id, colours[1]) or Themes.SPECS[id].look.headerColor))
            for _, c in ipairs(colours) do
                check(id .. " " .. c .. ": named", ns.L["THEME_COLOR_" .. id .. "_" .. c] ~= "THEME_COLOR_" .. id .. "_" .. c, true)
            end
        end
    end
    Themes.Switch("CLASSIC")
    check("colours: none under classic", #entry.Colors() .. tostring(entry.Color()), "0nil")
    Themes.Switch("PIXEL")
    check("pixel plum: set", entry.SetColor("PLUM"), true)
    check("pixel plum: grey texture tinted", look(), PATH .. "PixelBackGrey " .. rgb({ 0.23 / 0.8, 0.08 / 0.8, 0.16 / 0.8 }) .. ",1")
    check("pixel plum: headers in its accent", accent(), "1,0.93,0.15")
    check("pixel handheld: listed last", entry.Colors()[9], "HANDHELD")
    -- An HD colour: its own finished backdrop, untinted, at the base's alpha.
    Themes.Switch("WOOD_HD")
    check("wood hd: offered", Themes.Current(), "WOOD_HD")
    check("wood hd: the base's look", S("borderStyle"), "GOLD")
    entry.SetColor("OAK")
    check("wood hd oak: its own texture, white", look(), PATH .. "WoodHDOak 1,1,1,1")
    Themes.Switch("COMIC_HD")
    entry.SetColor("NEWSPRINT")
    check("comic hd newsprint: dark ink", Themes.DarkInk(), nil)
    entry.SetColor("NOIR")
    check("comic hd noir: dark paper, light ink", Themes.DarkInk() ~= nil, true)
    Themes.SetColor("EBONY", "WOOD_HD")
    Themes.Switch("PIXEL")
    Themes.SetColor("HANDHELD")
    check("pixel handheld: grey texture tinted", look(), PATH .. "PixelBackGrey " .. rgb({ 0.059 / 0.8, 0.122 / 0.8, 0.059 / 0.8 }) .. ",1")
    check("pixel handheld: headers in its accent", accent(), "0.784,0.941,0.439")
    check("pixel grey: no accent keeps the headers", Themes.SetColor("GREY") and accent(), rgb(Themes.SPECS.PIXEL.look.headerColor))
    check("colour: another theme's id refused", select(2, Themes.SetColor("OAK")), "UNKNOWN")
    check("frost deep: set while on pixel", Themes.SetColor("DEEP", "FROST"), true)
    Themes.Switch("FROST")
    check("frost deep: tinted, alpha kept", look(), PATH .. "FrostBackGrey " .. rgb({ 0.1 / 0.796, 0.18 / 0.796, 0.32 / 0.796 }) .. ",0.85")
    check("colours: each theme its own", entry.Color() .. " " .. entry.Color("PIXEL"), "DEEP GREY")
    Themes.SetColor("ICE")
    Themes.SetColor("NAVY", "PIXEL")
    check("colours: defaults store nothing", next(ns.AccountDB().themeColors), nil)
    -- The comic colour of before moves in once.
    ns.AccountDB().comicColor = "RED"
    check("migration: comic colour moved", entry.Color("COMIC") .. " " .. tostring(ns.AccountDB().comicColor), "RED nil")
    ns.AccountDB().comicColor = "BLUE"
    check("migration: a colour already set wins", entry.Color("COMIC"), "RED")
    Themes.SetColor("GREY", "COMIC")
    -- The flat themes keep their backdrop in every colour.
    Themes.Switch("SWISS")
    ns.ThemeArt.Style(frame, 0)
    check("swiss: header font", S("headerFont") .. "/" .. S("headerSize"), "Inter Tight Bold/" .. Themes.ClassicSet().headerSize)
    check("swiss: grey hairline", rgb(S("borderColor")) .. "/" .. S("borderSize"), "0.165,0.165,0.165/1")
    check("swiss: white rule along the top over the ring", art.rule:IsShown() and art.rule._points.TOPLEFT[4] .. "/" .. art.rule:GetHeight(), "1/3")
    check("swiss: red title", accent(), "1,0.176,0.125")
    check("swiss: icons in the red accent", rgb(ns.Header.ButtonColor({})), "1,0.176,0.125")
    check("swiss: the note grey as without a theme", rgb(ns.Header.NoteStyle().color), rgb(ns.Header.NOTE))
    check("swiss blue: set", Themes.SetColor("BLUE"), true)
    check("swiss blue: backdrop kept", look(), PATH .. "SwissBack 1,1,1,1")
    check("swiss blue: title", accent(), "0.176,0.42,1")
    check("swiss blue: icons follow", rgb(ns.Header.ButtonColor({})), "0.176,0.42,1")
    Themes.SetColor("RED")
    Themes.Switch("CONSOLE")
    ns.ThemeArt.Style(frame, 0)
    check("console: header font", S("headerFont"), "IBM Plex Sans Condensed Bold")
    check("console: mint ring, no rule", rgb(Themes.RingColor()) .. tostring(art.rule:IsShown()), "0.306,0.929,0.69false")
    Themes.SetColor("AMBER")
    check("console amber: the ring follows the accent", rgb(Themes.RingColor()) .. "/" .. accent(), "1,0.69,0/1,0.69,0")
    check("console amber: backdrop kept", look(), PATH .. "ConsoleBack 1,1,1,1")
    Themes.SetColor("MINT")
    Themes.Switch("PITWALL")
    ns.ThemeArt.Style(frame, 0)
    check("pitwall: header font", S("headerFont"), "Titillium Web Bold Italic")
    check("pitwall: a carbon hairline", S("borderStyle") .. S("borderSize"), "FLAT1")
    check("pitwall: black title strip as high as the header", art.strip:IsShown() and table.concat(art.strip._texColor or art.strip._vertex, ",") .. " " .. art.strip:GetHeight(), "0,0,0,1 " .. ns.Header.HEIGHT)
    check("pitwall: red wedge", art.wedge:IsShown() and rgb(art.wedge._vertex), "0.882,0.024,0")
    -- The family's wedge: as high as the strip, as wide as high, the grip or
    -- title 8 past its right edge at the header's middle.
    local stripH = art.strip:GetHeight()
    check("pitwall: wedge as high as the strip, as wide as high", art.wedge:GetHeight() .. "x" .. art.wedge:GetWidth(),
        stripH .. "x" .. stripH)
    local inset = ns.Header.HEIGHT - stripH
    local start = inset + math.floor(0.98 * stripH - 0.36 * (ns.Header.HEIGHT / 2 - inset) + 0.5) + 8
    local ph = ns.Header.Create(CreateFrame("Frame", nil, UIParent), { movable = function() return false end })
    ns.Header.Layout(ph)
    check("pitwall: title 8 past the wedge", ph.title._points.LEFT[3], start)
    ph.movable = function() return true end
    ns.Header.Layout(ph)
    check("pitwall: grip 8 past the wedge, title after it as usual", ph.grip._points.LEFT[3] .. "/" .. ph.title._points.LEFT[3],
        start .. "/" .. (start + 18))
    local pb, lockOpen = ns.Header.Button(ph, "Gear", "", function() end), false
    local lock = ns.Header.Button(ph, "Lock", "", function() end, function() return lockOpen end)
    lock.activeColor = { 0.31, 0.76, 0.97 }
    ns.Header.Layout(ph)
    check("pitwall: header icon in the wedge's red", rgb(pb.paintColor), "0.882,0.024,0")
    check("pitwall: a toggle off the red darker", rgb(lock.paintColor), rgb({ 0.882 * 0.6, 0.024 * 0.6, 0 }))
    lockOpen = true
    ns.Header.Layout(ph)
    check("pitwall: unlocked lock in the red, not blue", rgb(lock.paintColor), "0.882,0.024,0")
    pb.hover = true
    ns.Header.Paint(pb)
    check("pitwall: hover half way to white", rgb(pb.paintColor), "0.941,0.512,0.5")
    pb.hover = false
    Themes.SetColor("TEAL")
    ns.ThemeArt.Style(frame, 0)
    ns.Header.Layout(ph)
    check("pitwall teal: the wedge's colour", rgb(art.wedge._vertex), "0,0.631,0.612")
    check("pitwall teal: title kept", accent(), rgb(Themes.SPECS.PITWALL.look.headerColor))
    check("pitwall teal: header icon follows the wedge", rgb(pb.paintColor), "0,0.631,0.612")
    -- Every icon accent readable on its backdrop (back, else the black
    -- header): at least 3:1, the contrast WCAG asks of icons.
    local function luminance(c)
        local function lin(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
    end
    for id, colours in pairs(LibForeverThemes.COLORS) do
        for _, c in ipairs(id ~= "COMIC" and colours or {}) do
            local a = c.accent or c.wedge
            if a then
                local ratio = (luminance(a) + 0.05) / (luminance(c.back or { 0, 0, 0 }) + 0.05)
                check(id .. " " .. c.id .. ": icon accent readable", ratio >= 3, true)
            end
        end
    end
    Themes.SetColor("RED")
    -- Swiss and Pitwall share one black with every Forever addon: the flat
    -- backdrop untinted, the background #0a0a0a, opaque.
    for _, id in ipairs({ "SWISS", "PITWALL" }) do
        Themes.Switch(id)
        check(id .. ": the shared black", look() .. " " .. S("bgMode") .. " " .. table.concat(S("bgColor"), ",")
            .. " " .. S("bgAlpha"), PATH .. "SwissBack 1,1,1,1 SOLID 0.039,0.039,0.039 100")
    end
    -- The ring is the same in every Forever addon, for every theme and
    -- colour: the theme's own; only Console's colours and Pixel's Handheld
    -- recolour it.
    local RINGS = { TECH = "0.25,0.88,0.94,0.9", PARCHMENT = "0.29,0.2,0.12,1", RUNESTONE = "0.1,0.1,0.12,1",
        GLASS = "0.07,0.06,0.05,1", COMIC = "0.07,0.07,0.07,1", FROST = "0.86,0.96,1,0.8", PIXEL = "1,0.95,0.91,1",
        SWISS = "0.165,0.165,0.165,1", PITWALL = "0.043,0.047,0.055,1" }
    local OWN_RING = { CONSOLE = { MINT = "0.306,0.929,0.69,1", AMBER = "1,0.69,0,1", PHOSPHOR = "0.224,1,0.078,1",
        VIOLET = "0.627,0.471,1,1" }, PIXEL = { HANDHELD = "0.784,0.941,0.439,1" } }
    for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
        if id ~= "CLASSIC" then
            Themes.Switch(id)
            local chosen, base = entry.Color(), LibForeverThemes.BaseTheme(id)   -- an HD theme: its base's ring
            for _, c in ipairs(entry.Colors()) do
                Themes.SetColor(c)
                if base == "WOOD" then
                    check("ring " .. id .. " " .. c, S("borderStyle"), "GOLD")
                else
                    check("ring " .. id .. " " .. c, S("borderStyle") .. " " .. table.concat(Themes.RingColor(), ","),
                        "FLAT " .. ((OWN_RING[id] or {})[c] or RINGS[base]))
                end
            end
            Themes.SetColor(chosen)
        end
    end
    Themes.Switch("TECH")
    ns.ThemeArt.Style(frame, 0)
    check("tech: no strip, wedge or rule", tostring(art.strip:IsShown()) .. tostring(art.wedge:IsShown()) .. tostring(art.rule:IsShown()), "falsefalsefalse")
    check("art: tech without corner pieces", art.ornaments[1]:IsShown() or art.ornaments[4]:IsShown(), false)
    Themes.Switch("COMIC")
    Themes.Switch("GLASS")
    ns.ThemeArt.Style(frame, 0)
    check("art: glass title on the dark body", frame.bg._points.TOPLEFT[4], -frame.bg._points.TOPLEFT[3])
    check("glass: the list keeps its font", S("commentFont") .. "/" .. S("nameFont"), "Friz Quadrata/Friz Quadrata")
    Themes.Switch("FROST")
    check("frost: the family's shade over the ice", S("bgAlpha"), 45)
    Themes.Switch("COMIC")
    Themes.Switch("CLASSIC")
    box, radius = ns.ThemeArt.Style(frame, 10)
    check("classic: ring round the frame", box, frame)
    check("classic: own radius", radius, 10)
    check("classic: no backdrop", art.back:IsShown(), false)
    check("classic: body everywhere", frame.bg._points.TOPLEFT, nil)
    b.hover = false
    ns.Header.Paint(b)
    check("classic: header icon as before", b.paintColor, ns.Header.IDLE)

    -- A font the client refuses at first use: the default meanwhile, then
    -- tried again.
    local fs = UIParent:CreateFontString()
    local setFont, refusals = fs.SetFont, 1
    fs.SetFont = function(self, path, ...)
        if refusals > 0 and path:find("Cinzel", 1, true) then refusals = refusals - 1; return false end
        return setFont(self, path, ...)
    end
    ns.Media.ApplyText(fs, { font = "Cinzel", size = 14, flag = "OUTLINE", color = { 1, 1, 1 } })
    check("refused: default font meanwhile", (fs:GetFont()), ns.Media.DEFAULT.font)
    M.RunTimers()
    check("tried again: taken", (fs:GetFont()), ns.Media.FontPath("Cinzel"))
    check("theme fonts listed", (function()
        for _, name in ipairs(ns.Media.Names("font")) do if name == "Marcellus" then return true end end
        return false
    end)(), true)

    -- "Apply to all Forever addons": only with another addon listed; puts it on
    -- this theme and colour, skips it when it lacks the theme.
    local allRow
    for _, row in ipairs(ns.Options.PAGES[1].rows()) do
        if row.buttons and row.buttons[1].label == "OPT_THEME_ALL" then allRow = row end
    end
    check("apply all: hidden alone", allRow.visible(), false)
    local pick = Themes.Colors("PIXEL")[2]
    local other, known = { theme = "CLASSIC" }, { CLASSIC = {}, PIXEL = { "NAVY", pick } }
    _G.ForeverThemes.FakeOther = {
        title = "Fake", Current = function() return other.theme end,
        Switch = function(id)
            if not known[id] then return nil, "UNKNOWN" end
            other.theme = id
            return true
        end,
        Colors = function(theme) return known[theme] end,
        SetColor = function(id) other.color = id; return true end,
    }
    check("apply all: shown with another", allRow.visible(), true)
    Themes.Switch("PIXEL")
    Themes.SetColor(pick)
    M.chat = {}
    allRow.buttons[1].onClick()
    check("apply all: theme and colour", other.theme .. " " .. tostring(other.color), "PIXEL " .. pick)
    check("apply all: says how many", (M.chat[1] or ""):find("1 other", 1, true) ~= nil, true)
    Themes.Switch("WOOD")
    check("apply all: unknown theme skipped", Themes.ApplyToAll() .. " " .. other.theme, "0 PIXEL")
    _G.ForeverThemes.FakeOther = nil
    Themes.SetColor(Themes.Colors("PIXEL")[1], "PIXEL")
    Themes.Switch("CLASSIC")

    Settings.ResetProfile()
    ns.DB().themeSets = nil
    for k in pairs(ns.DB()) do ns.DB()[k] = nil end
    Settings.Changed(nil)
end
