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

    -- Frost's header: a 1 px drop shadow, no outline; every other theme outlined.
    for id, spec in pairs(Themes.SPECS) do
        if spec.look then
            check(id .. ": header flag", spec.look.headerFlag, id == "FROST" and "SHADOW" or "OUTLINE")
        end
    end
    local frostHeader = UIParent:CreateFontString()
    ns.Media.ApplyText(frostHeader, { font = "Cormorant SC", size = 16, flag = Themes.SPECS.FROST.look.headerFlag,
        color = { 1, 1, 1 } })
    check("frost: header drawn without outline, shadowed", select(3, frostHeader:GetFont()) .. " "
        .. table.concat({ frostHeader:GetShadowOffset() }, ","), " 1,-1")

    -- A theme stored under an older revision is made anew; Classic stays.
    Themes.Switch("WOOD")
    Settings.Set("x", 77)
    local db = ns.DB()
    db.themeSets.revision = Themes.REVISION - 1
    db.themeSets.TECH = { theme = "TECH", x = 5 }
    Settings.Set("borderSize", 7)
    Themes.Upgrade()
    check("upgrade: theme in use made anew", S("borderSize"), 3)
    check("upgrade: from classic", S("x"), -120)
    check("upgrade: stale set dropped", db.themeSets.TECH, nil)
    check("upgrade: classic kept", db.themeSets.CLASSIC.width, 800)
    check("upgrade: revision noted", db.themeSets.revision, Themes.REVISION)
    check("revision 6: sets rebuilt (Frost's header shadowed)", Themes.REVISION, 6)
    Settings.Set("borderSize", 5)
    Themes.Upgrade()
    check("upgrade: once only", S("borderSize"), 5)

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
    check("options: copy row while themed", general[6].visible(), true)
    check("options: colours under any theme", general[3].visible(), true)
    general[2].set("CLASSIC")
    check("options: no copy row on classic", general[6].visible(), false)
    check("options: no colours on classic", general[3].visible(), false)
    check("options: no reset on classic", general[7].visible(), false)
    general[2].set("COMIC")
    check("options: comic colour under the comic", general[3].visible() and general[3].get(), "GREY")
    general[2].set("CLASSIC")
    check("options: classic restored", S("width") .. "/" .. S("cornerRadius"), "800/8")

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
    for _, id in ipairs(Themes.IDS) do
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
    local PATH = "Interface\\AddOns\\ForeverGroupFinder\\Media\\Themes\\"
    for _, id in ipairs(Themes.IDS) do
        if id ~= "CLASSIC" and id ~= "COMIC" then
            Themes.Switch(id)
            local a, colours = Themes.SPECS[id].art, entry.Colors()
            check(id .. ": the first colour by default", entry.Color(), colours[1])
            local tint = a.tint or { 1, 1, 1, 1 }
            check(id .. ": default as today", look(), PATH .. a.back .. " " .. table.concat(tint, ","))
            check(id .. ": default headers as today", accent(), rgb(Themes.SPECS[id].look.headerColor))
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
    Themes.SetColor("HANDHELD")
    check("pixel handheld: grey texture tinted", look(), PATH .. "PixelBackGrey " .. rgb({ 0.06 / 0.8, 0.12 / 0.8, 0.06 / 0.8 }) .. ",1")
    check("pixel handheld: headers in its accent", accent(), "0.784,0.941,0.439")
    check("pixel grey: no accent keeps the headers", Themes.SetColor("GREY") and accent(), rgb(Themes.SPECS.PIXEL.look.headerColor))
    check("colour: another theme's id refused", select(2, Themes.SetColor("OAK")), "UNKNOWN")
    check("frost deep: set while on pixel", Themes.SetColor("DEEP", "FROST"), true)
    Themes.Switch("FROST")
    check("frost deep: tinted, alpha kept", look(), PATH .. "FrostBackGrey " .. rgb({ 0.1 / 0.796, 0.18 / 0.796, 0.32 / 0.796 }) .. ",1")
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
    check("swiss: grey hairline", rgb(S("borderColor")) .. "/" .. S("borderSize"), "0.16,0.16,0.16/1")
    check("swiss: white rule along the top over the ring", art.rule:IsShown() and art.rule._points.TOPLEFT[4] .. "/" .. art.rule:GetHeight(), "1/3")
    check("swiss: red title", accent(), "1,0.18,0.13")
    check("swiss: icons grey, not red", ns.Header.ButtonColor({})[1], 0.55)
    check("swiss blue: set", Themes.SetColor("BLUE"), true)
    check("swiss blue: backdrop kept", look(), PATH .. "SwissBack 1,1,1,1")
    check("swiss blue: title", accent(), "0.18,0.42,1")
    Themes.SetColor("RED")
    Themes.Switch("CONSOLE")
    ns.ThemeArt.Style(frame, 0)
    check("console: header font", S("headerFont"), "IBM Plex Sans Condensed")
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
    check("pitwall: red wedge", art.wedge:IsShown() and rgb(art.wedge._vertex), "0.88,0.02,0")
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
    Themes.SetColor("TEAL")
    ns.ThemeArt.Style(frame, 0)
    check("pitwall teal: the wedge's colour", rgb(art.wedge._vertex), "0,0.63,0.61")
    check("pitwall teal: title kept", accent(), rgb(Themes.SPECS.PITWALL.look.headerColor))
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
        SWISS = "0.16,0.16,0.16,1", PITWALL = "0.043,0.047,0.055,1" }
    local OWN_RING = { CONSOLE = { MINT = "0.306,0.929,0.69,1", AMBER = "1,0.69,0,1", PHOSPHOR = "0.224,1,0.078,1",
        VIOLET = "0.627,0.471,1,1" }, PIXEL = { HANDHELD = "0.784,0.941,0.439,1" } }
    for _, id in ipairs(Themes.IDS) do
        if id ~= "CLASSIC" then
            Themes.Switch(id)
            local chosen = entry.Color()
            for _, c in ipairs(entry.Colors()) do
                Themes.SetColor(c)
                if id == "WOOD" then
                    check("ring " .. id .. " " .. c, S("borderStyle"), "GOLD")
                else
                    check("ring " .. id .. " " .. c, S("borderStyle") .. " " .. table.concat(Themes.RingColor(), ","),
                        "FLAT " .. ((OWN_RING[id] or {})[c] or RINGS[id]))
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
    check("frost: body opaque over the cracks", S("bgAlpha"), 100)
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
