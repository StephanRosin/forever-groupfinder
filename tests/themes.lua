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
    check("wood: its border", S("borderStyle") .. "/" .. S("borderSize"), "FLAT/3")
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
    check("profile reset: its look over the defaults", S("borderStyle"), "FLAT")
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
    check("revision 3: sets rebuilt (plain comic outline)", Themes.REVISION, 3)
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
    check("options: copy row while themed", general[4].visible(), true)
    general[2].set("CLASSIC")
    check("options: no copy row on classic", general[4].visible(), false)
    check("options: no reset on classic", general[5].visible(), false)
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
            local ring, inset = S("borderSize"), art.back._points.TOPLEFT[3]
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
    Themes.Switch("TECH")
    ns.ThemeArt.Style(frame, 0)
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

    Settings.ResetProfile()
    ns.DB().themeSets = nil
    for k in pairs(ns.DB()) do ns.DB()[k] = nil end
    Settings.Changed(nil)
end
