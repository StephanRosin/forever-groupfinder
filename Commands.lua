local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

function ns.ToggleLock()
    Settings.SetLocked(not Settings.Get("locked"))
    ns.Print(Settings.Get("locked") and L.MSG_LOCKED or L.MSG_UNLOCKED)
end

-- Back to the default place and size of the window (nothing else).
local WINDOW_KEYS = { "point", "relPoint", "x", "y", "width", "height", "scale" }

function ns.ResetWindowPlace()
    local values = {}
    for _, key in ipairs(WINDOW_KEYS) do values[key] = Settings.DEFAULTS[key] end
    Settings.SetMany(values)
    ns.Print(L.MSG_RESET)
end

local COMMANDS = {
    [""] = function() ns.Window.Toggle() end,
    options = function() ns.Options.Open() end,
    lock = function() Settings.SetLocked(true); ns.Print(L.MSG_LOCKED) end,
    unlock = function() Settings.SetLocked(false); ns.Print(L.MSG_UNLOCKED) end,
    reset = ns.ResetWindowPlace,
}

-- The words of a command line, the command lower-cased.
function ns.ParseCommand(msg)
    local words = {}
    for word in (msg or ""):gmatch("%S+") do words[#words + 1] = word end
    return (words[1] or ""):lower(), { unpack(words, 2) }
end

SLASH_FOREVERGROUPFINDER1 = "/fgf"
SLASH_FOREVERGROUPFINDER2 = "/forevergroupfinder"
SlashCmdList["FOREVERGROUPFINDER"] = function(msg)
    local command, args = ns.ParseCommand(msg)
    local run = COMMANDS[command]
    if not run then
        ns.Print(L.MSG_USAGE)
        return
    end
    run(args)
end
