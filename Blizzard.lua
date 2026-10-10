local ADDON, ns = ...

--[[ Blizzard's finder -> ours ("replaceBlizzard").

How Blizzard opens its finder in 1.60.1.70338 (Camelot, Vanilla style):
  - key binding TOGGLEGROUPFINDER (Blizzard_GroupFinder_VanillaStyle/Bindings.xml):
    LFGVanilla_ToggleFrame(1)
  - micro menu button: LFDMicroButtonMixin:OnClick -> ToggleGroupFinderFrame()
    (Blizzard_Game/Shared/Game.lua) -> LFGVanilla_ToggleFrame() for the
    Vanilla style; PVEFrame_ToggleFrame is the non-Vanilla branch only and is
    not on this client's path, so it is not hooked
  - LFG eye on the minimap and the queue status button: LFGVanilla_ToggleFrame()
    or LFGVanilla_ShowFrame(1)
  - LFG_LIST_SHOW_SEARCH: LFGBrowseMixin -> LFGVanilla_ShowFrame(2)
  - LFGVanilla_ToggleFrame calls LFGVanilla_ShowFrame when it opens.
  Tab 3 (the Who list: TOGGLEWHOTAB, /who via ShowWhoPanel) is not ours and is
  left to Blizzard.

Decision. We post-hook the two GLOBAL functions LFGVanilla_ToggleFrame and
LFGVanilla_ShowFrame with hooksecurefunc (never a frame method: on this client
a hook on a frame method makes it nil for Blizzard's own code). The hook runs
right after Blizzard's code, still inside the key press or click, so our
window's search on opening counts as a click. Then, out of combat, we close
Blizzard's frame again through Blizzard's own global LFGVanilla_ToggleFrame()
(shown + no tab = its "close" branch). Why that is safe enough:
  - HideUIPanel there hands the work to FramePositionDelegate, a forbidden
    frame, via SetAttribute; the panel layout is then done in secure code, so
    our taint does not spread into the UI panel bookkeeping. This is the path
    Blizzard keeps for addons that open or close panels out of combat.
  - Both happen in one frame: Blizzard's window is never drawn (only its open
    and close sounds play).
  - We never call HideUIPanel / SetParent / Hide / SetAlpha on a Blizzard frame
    ourselves and never hook a frame method. The only Blizzard frame we touch
    is a read: LFGParentFrame:IsShown().
In combat the panel manager refuses insecure callers (CheckProtectedFunctions-
Allowed prints "Interface action failed"), so there we do not try: Blizzard's
window stays open next to ours and is closed when combat ends.
Rejected: SetOverrideBinding (covers the key only, not the micro button or the
eye, and is not allowed in combat); SetAlpha(0) / EnableMouse(false) on
LFGParentFrame (it would still take the left panel slot and push other
windows); not loading Blizzard's finder (Blizzard loads it itself).
Our own opening of Blizzard's listing tab (the comment editor, Listing.lua)
goes through Blizzard.PassThrough, which the hooks leave alone. ]]

local Blizzard = {}
ns.Blizzard = Blizzard

local S = ns.Settings.Get

-- The globals we hook. Only names of global functions, never frame methods.
Blizzard.HOOKED = { "LFGVanilla_ToggleFrame", "LFGVanilla_ShowFrame" }

local hooked = {}
local busy = false           -- our own call into Blizzard's finder
local opened = nil           -- { at = GetTime(), wasShown = } from the ShowFrame hook

-- The tabs we answer: none given, the listing tab, the browse tab.
local function ours(tab)
    return S("replaceBlizzard") and (tab == nil or tab == 1 or tab == 2)
end

-- The one read of a Blizzard frame.
local function blizzardShown()
    return type(LFGParentFrame) == "table" and LFGParentFrame:IsShown() == true
end

local function closeBlizzard()
    if not S("replaceBlizzard") or not blizzardShown() then return end
    if InCombatLockdown() then
        ns.AfterCombat("closeBlizzardFinder", closeBlizzard)
        return
    end
    if type(LFGVanilla_ToggleFrame) ~= "function" then return end
    busy = true
    pcall(LFGVanilla_ToggleFrame)   -- shown and no tab: Blizzard's own close
    busy = false
end

-- LFGVanilla_ShowFrame: ours opens (it searches: we are inside the click).
local function afterShow(tab)
    if busy or not ours(tab) then return end
    opened = { at = GetTime(), wasShown = ns.Window.IsShown() }
    if not ns.Window.IsShown() then ns.Window.Show() end
    closeBlizzard()
end

-- LFGVanilla_ToggleFrame: ours toggles. When Blizzard's toggle opened its
-- window, the ShowFrame hook above has already run (this same frame) and
-- knows whether ours was open before. When it did not open (it closed its
-- window, left open in combat or by the comment editor, or the finder is
-- unavailable), the press was a "close": ours closes too.
local function afterToggle(tab)
    if busy or not ours(tab) then return end
    local stamp = opened
    opened = nil
    if not (stamp and stamp.at == GetTime()) or stamp.wasShown then
        ns.Window.Hide()
    elseif not ns.Window.IsShown() then
        ns.Window.Show()
    end
    closeBlizzard()
end

local AFTER = { LFGVanilla_ToggleFrame = afterToggle, LFGVanilla_ShowFrame = afterShow }

-- Blizzard's finder is load-on-demand: hook whatever exists, again when it loads.
function Blizzard.Hook()
    for _, name in ipairs(Blizzard.HOOKED) do
        if not hooked[name] and type(_G[name]) == "function" then
            hooked[name] = true
            hooksecurefunc(name, function(tab) AFTER[name](tab) end)
        end
    end
end

function Blizzard.IsHooked(name) return hooked[name] == true end

-- Runs fn with the hooks standing aside (we open Blizzard's tab ourselves).
function Blizzard.PassThrough(fn, ...)
    busy = true
    local ok, err = pcall(fn, ...)
    busy = false
    return ok, err
end

-- A "find a group" link or quest button: our window, on those activities.
local function showSearch(_, ids, allLevels)
    if not S("replaceBlizzard") then return end
    if type(ids) == "table" and type(ids[1]) == "number" then
        local info = ns.Finder.ActivityInfo(ids[1])
        local category = info and info.categoryID
        if type(category) == "number" and category ~= S("category") then ns.Settings.Set("category", category) end
        ns.Window.SetCheckedList(ids)
    end
    if allLevels == true then ns.Settings.Set("levelRangeOnly", false) end
    if ns.Window.IsShown() then
        ns.Window.Refresh()
        ns.Window.Search()
    else
        ns.Window.Show()
    end
end

Blizzard.Hook()
ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_GroupFinder_VanillaStyle" then Blizzard.Hook() end
end)
ns.On("PLAYER_LOGIN", Blizzard.Hook)
ns.On("LFG_LIST_SHOW_SEARCH", showSearch)
