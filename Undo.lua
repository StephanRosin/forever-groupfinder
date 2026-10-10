local ADDON, ns = ...
local L, Controls, Memory = ns.L, ns.Controls, ns.Memory

-- Hiding a group or ignoring a leader from the window (row menu, details)
-- goes through here: it is done at once, and a slim bar at the foot of the
-- list offers "Undo" for a few seconds ("Grimnar ignored — Undo"). The bar
-- goes away with the window's clock (Window.Tick); nothing here searches.
-- The way back after that: the "Ignored (n)" / "Hidden (n)" chips in the
-- filter bar open the lists in the options; /fgf unignore <name>.
local Undo = {}
ns.Undo = Undo

Undo.SECONDS = 8
local BAR_H = 22

local bar
local pending   -- { kind = "IGNORE" | "HIDE", value = name | key, until = GetTime() + SECONDS }

function Undo.Pending() return pending end
function Undo.Frame() return bar end

local function show()
    if not bar then return end
    if not pending then
        bar:Hide()
        return
    end
    bar.text:SetText(pending.kind == "IGNORE" and L.UNDO_IGNORED:format(pending.value) or L.UNDO_HIDDEN)
    bar.button:SetLabel(L.UNDO)
    bar.button:SetWidth(math.max(56, math.floor(bar.button.label:GetStringWidth() + 18)))
    bar:Show()
end

local function offer(kind, value)
    pending = { kind = kind, value = value, untilTime = GetTime() + Undo.SECONDS }
    show()
end

-- Hide a group (a row of Window.Built()).
function Undo.Hide(row)
    if type(row.key) ~= "string" then return end
    Memory.Hide(row.key)
    ns.Window.Rebuild()
    offer("HIDE", row.key)
end

-- Ignore a leader by name.
function Undo.Ignore(name)
    if type(name) ~= "string" or name == "" then return end
    Memory.SetIgnored(name, true)   -- the open window rebuilds
    offer("IGNORE", name)
end

-- The bar's button.
function Undo.Run()
    local p = pending
    if not p then return end
    pending = nil
    if p.kind == "IGNORE" then Memory.SetIgnored(p.value, false) else Memory.Unhide(p.value) end
    ns.Window.Rebuild()
    show()
end

-- The window's clock: the offer ends after a few seconds.
function Undo.Tick()
    if pending and GetTime() >= pending.untilTime then
        pending = nil
        show()
    end
end

function Undo.Clear()
    pending = nil
    show()
end

-- Over the foot of the list (anchored to it, so every layout has it).
function Undo.Create(list)
    bar = CreateFrame("Frame", nil, list)
    bar:SetHeight(BAR_H)
    bar:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    bar:SetFrameLevel(list:GetFrameLevel() + 20)
    bar:EnableMouse(true)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.1, 0.08, 0.03, 0.95)
    bar.edges = Controls.Outline(bar, Controls.EDGE)
    bar.button = Controls.Button(bar, { text = "", height = 16, onClick = function() Undo.Run() end,
        tip = function() return L.TIP_UNDO end })
    bar.button:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.text = Controls.Text(bar, "comment")
    bar.text:SetPoint("LEFT", bar, "LEFT", 8, 0)
    bar.text:SetPoint("RIGHT", bar.button, "LEFT", -6, 0)
    bar:Hide()
    return bar
end
