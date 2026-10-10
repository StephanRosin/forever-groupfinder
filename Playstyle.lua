local ADDON, ns = ...
local L = ns.L

-- Playstyles of a listing (Enum.LFGEntryGeneralPlaystyle): 1 Learning,
-- 2 FunRelaxed, 3 FunSerious, 4 Expert (0 none). Names come from
-- Blizzard's GROUP_FINDER_GENERAL_PLAYSTYLE1..4 when the client has them
-- (as its GetGeneralPlaystyleString), else from our locales; the rows use
-- short labels. My choice is remembered per character. A category whose
-- info says showPlaystyleDropdown requires one before posting (as
-- Blizzard's listing does).
local Playstyle = {}
ns.Playstyle = Playstyle

Playstyle.VALUES = { 1, 2, 3, 4 }
local VALID = { [1] = true, [2] = true, [3] = true, [4] = true }

function Playstyle.Valid(v) return VALID[v] == true end

-- The full name (the client's words when present).
function Playstyle.Name(v)
    if not VALID[v] then return nil end
    local global = _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. v]
    if type(global) == "string" and global ~= "" then return global end
    return L["PLAYSTYLE_" .. v]
end

-- A short label for a row's tag.
function Playstyle.Short(v)
    if not VALID[v] then return nil end
    return L["PLAYSTYLE_SHORT_" .. v]
end

-- "Choose a playstyle" (the client's text when present).
function Playstyle.RequiredText()
    local global = GROUP_FINDER_PLAYSTYLE_REQUIRED
    if type(global) == "string" and global ~= "" then return global end
    return L.PLAYSTYLE_REQUIRED
end

local function store()
    ForeverGroupFinderChar = ForeverGroupFinderChar or {}
    return ForeverGroupFinderChar
end

-- My chosen playstyle, or nil.
function Playstyle.Selected()
    local v = store().playstyle
    return VALID[v] and v or nil
end

function Playstyle.Set(v)
    store().playstyle = VALID[v] and v or nil
end

-- A listing always needs a playstyle: Forever's (modern) Vanilla-style listing
-- always has the playstyle dropdown and refuses to post without a choice
-- (Blizzard_LFGVanilla_Listing.xml PlayStyleDropdown, Listing.lua ~484). The
-- category flag showPlaystyleDropdown is false there, so it is not consulted.
function Playstyle.Required()
    return true
end
