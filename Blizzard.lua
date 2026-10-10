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
  - LFG_LIST_SHOW_SEARCH: LFGBrowseMixin:ShowSearchForActivities ->
    LFGVanilla_ShowFrame(2), then LFGBrowse_DoSearch() (its own
    C_LFGList.Search). Tab 2 is passed by nothing else.
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
  - What does run insecurely: LFGVanilla_ToggleFrame's UpdateMicroButtons()
    (UpdateMicroButton on every micro button) and the EventRegistry broadcast
    "UIParentPanelManager.HideUIPanel" (gamepad listeners). Neither is
    protected; the in-game check is /console taintLog 1, open by key, micro
    button and eye, then open spellbook and talents in combat.
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
goes through Blizzard.PassThrough, which the hooks leave alone (and which
drops a close still waiting for the end of combat).
Side effects worth knowing: with Blizzard's Who list open, the finder key
opens ours and closes the Who list (Blizzard's toggle switches to tab 1).
While the finder is unavailable (CanPlayerUsePremadeGroup false) Blizzard's
toggle only ever closes, so the key never opens ours; /fgf still does.

Show-search ("find a group" links): one request, one search. Blizzard's
browse frame answers the event itself, in this same click, with ShowFrame(2)
and its own search for the event's activities (no addon taint: its handler
runs before or after ours, never through us). So neither our handler nor the
ShowFrame(2) hook searches: they set the category and activities, open our
window and adopt Blizzard's search (Finder.ExpectSearch); its results come
in as ours. Without Blizzard's finder loaded our handler opens the window
without a search (never search from an event). ]]

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
-- Tab 2 is Blizzard's show-search, which searches itself right after.
local function afterShow(tab)
    if busy or not ours(tab) then return end
    opened = { at = GetTime(), wasShown = ns.Window.IsShown() }
    if tab == 2 then
        if ns.Window.IsShown() then ns.Window.AdoptSearch() else ns.Window.Show("adopt") end
    elseif not ns.Window.IsShown() then
        ns.Window.Show()
    end
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
    ns.CancelAfterCombat("closeBlizzardFinder")
    busy = true
    local ok, err = pcall(fn, ...)
    busy = false
    return ok, err
end

-- Blizzard's browse frame answers LFG_LIST_SHOW_SEARCH too (searching):
-- its finder is loaded (then we have hooked it).
function Blizzard.Answers()
    return hooked.LFGVanilla_ShowFrame == true
end

-- The event's activities, those of the first one's category (as Blizzard's
-- SetSelectedSearchActivities picks them).
local function sameCategory(ids)
    local first, list = nil, {}
    for _, id in ipairs(ids) do
        local info = type(id) == "number" and ns.Finder.ActivityInfo(id)
        local category = info and info.categoryID
        if type(category) == "number" then
            first = first or category
            if category == first then list[#list + 1] = id end
        end
    end
    return first, list
end

-- A "find a group" link or quest button: our window, on those activities.
-- The one search is Blizzard's (see the top); we never search from here.
local function showSearch(_, ids, allLevels)
    if not S("replaceBlizzard") then return end
    if type(ids) == "table" then
        local category, list = sameCategory(ids)
        if category then
            if category ~= S("category") then ns.Settings.Set("category", category) end
            ns.Window.SetCheckedList(list)
        end
    end
    if allLevels == true then ns.Settings.Set("levelRangeOnly", false) end
    local search = Blizzard.Answers() and "adopt" or false
    if not ns.Window.IsShown() then
        ns.Window.Show(search)
    else
        ns.Window.Refresh()
        if search then ns.Window.AdoptSearch() end
    end
end

Blizzard.Hook()
ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_GroupFinder_VanillaStyle" then Blizzard.Hook() end
end)
ns.On("PLAYER_LOGIN", Blizzard.Hook)
ns.On("LFG_LIST_SHOW_SEARCH", showSearch)
