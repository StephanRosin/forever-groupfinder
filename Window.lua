local _, ns = ...
local L = ns.L

-- The finder's main window. Built by the next tasks; until then Toggle only
-- says so, so the minimap button, the compartment and /fgf already have
-- something to call.
local Window = {}
ns.Window = Window

function Window.Toggle()
    ns.Print(L.MSG_WINDOW_SOON)
end
