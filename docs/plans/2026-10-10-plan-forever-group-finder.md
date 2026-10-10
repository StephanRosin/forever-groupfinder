# Forever Group Finder 1.0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One-window group finder for WoW: Forever (activity list with level switch, groups + players with location, my listing with templates, filters, memory, leader help) in the look and menus of the Forever addons, replacing Blizzard's Vanilla-style finder.

**Architecture:** Port Forever Combat Meter's generic framework (locales, settings, profiles, share, media, border, corners, position, resize, options window, minimap button, tooling, mock with secret type + secret lint). On top, pure data modules (`Finder.lua` is the only `C_LFGList` caller; `Activities.lua`, `Results.lua`, `Listing.lua`, `Memory.lua`) feed a UI layer (`Window.lua`, `Rows.lua`, `Menu.lua`) and `Blizzard.lua` (redirect Blizzard's open paths via global-function hooks).

**Tech Stack:** Lua 5.1, WoW: Forever 1.60.1 (Interface 16001, 12.x engine, secret values), tests with a Lua 5.1 WoW mock (`tests/run`), bash tooling.

## Global Constraints

- Spec: `docs/specs/2026-10-10-forever-group-finder-design.md` (read it; its "Facts" section is binding). Research notes: `/tmp/claude-1000/-home-stephan/96fc229b-bef5-4488-9eb6-9c3ff28d825f/scratchpad/lfg-research.md` (copy into `.superpowers/sdd/2026-10-10-plan-forever-group-finder/research.md` at setup). Blizzard source of the finder: `~/Dokumente/wow-ui-source/1.60.1.70338/Blizzard_GroupFinder_VanillaStyle/` and `Blizzard_LFGUtil` (read for behaviour; Blizzard code may be studied, our addons are our own code).
- Framework source to port: `~/Dokumente/ForeverCombatMeter` (our own code): `Locale.lua`, `Locales/*.lua`, `Core.lua`, `Profiles.lua`, `Settings.lua`, `Share.lua`, `Media.lua`, `Border.lua`, `Corners.lua`, `Position.lua`, `Resize.lua`, `Options/*`, `Commands.lua` (shape), `Media/*.tga`, `install`, `tools/package`, `tools/release`, `tests/run`, `tests/run.lua` (harness + secret lint), `tests/wowmock.lua`, `README.md` shape, `docs/curseforge/` shape. Remove everything meter-specific (Meter, Threat, Windows, Detail, Report, Format, Blizzard meter CVar, meter settings).
- Names: folder/TOC `ForeverGroupFinder`, title "Forever Group Finder", `## Interface: 16001`, `## Version: 1.0.0`, SavedVariables `ForeverGroupFinderProfiles` (account), SavedVariablesPerCharacter `ForeverGroupFinderChar`, globals/frames prefixed `ForeverGroupFinder`, slash `/fgf` and `/forevergroupfinder`, share prefix `FGF1:`, compartment funcs `ForeverGroupFinder_OnAddonCompartmentClick/Enter/Leave`.
- Languages enUS, deDE, esES, frFR, same keys and placeholders in all four (tested); game language by default; language dropdown in the options nav (as in the combat meter).
- Only values that differ from the defaults are stored.
- `C_LFGList` is called **only** in `Finder.lua`. `Search`, `CreateListing`, `UpdateListing` only from a click/keypress call path (never from timers/events). One search in flight; min interval 3 s between searches (a request inside the interval is dropped, the UI shows the age).
- Secret values: `GetSearchResultInfo/LeaderInfo/PlayerInfo/GetActiveEntryInfo` fields may be secret → Finder converts each field with `issecretvalue(v) and nil or v` before anything else touches it; never `==`/`~= nil`/truthiness/arithmetic/`..`/table keys on a value that may be secret. Keep the combat meter's secret lint in `tests/run.lua` active for all source files.
- Never `hooksecurefunc` on frame methods; global-function hooks only. Register events through `ns.On` (pcall-guarded). Never call `HideUIPanel`/`SetParent` on Blizzard frames.
- Tests: `tests/run` (focused while working, full run before each commit). Commits end with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PSwcrtAz5yXQ5Kj9VjMsMo
  ```
- Repo `~/Dokumente/ForeverGroupFinder` (git user already configured), work on branch `finder-1.0`. No remote yet — do not push.

## File Structure

| File | Responsibility |
|---|---|
| `ForeverGroupFinder.toc` | load order, SavedVariables, compartment funcs, icon |
| `Locales/*.lua`, `Locale.lua` | strings, language choice (ported) |
| `Core.lua` | `ns.On`, `ns.Print`, `ns.AfterCombat` (ported) |
| `Profiles.lua`, `Settings.lua`, `Share.lua` | ported; DEFAULTS in Task 1 |
| `Media.lua`, `Border.lua`, `Corners.lua`, `Position.lua`, `Resize.lua`, `Media/*.tga` | ported look |
| `Finder.lua` | only `C_LFGList` caller: search throttle, secret-safe reads, events, listing calls |
| `Activities.lua` | categories, activities, level fit, level switch, text match |
| `Results.lua` | pure: results → group rows / player rows, filters, sort, markers |
| `Listing.lua` | my listing state, remaining time, templates, leader role arithmetic, comment path |
| `Memory.lua` | seen / hidden / ignore with expiry |
| `Window.lua`, `Rows.lua`, `Menu.lua` | the window, recycled rows + tooltip, context menu |
| `Blizzard.lua` | redirect Blizzard's open paths |
| `Options/*`, `Commands.lua` | options pages, `/fgf` |
| `install`, `tools/*`, `tests/*` | tooling |

---

### Task 0: In-game probe (controller with the user, before Task 2)

Not a subagent task. The controller writes a throwaway addon `FGFProbe` (scratchpad, never committed) with a small frame and buttons: "Search" (`C_LFGList.Search(2,0,0,nil,false,nil,nil)` from OnClick), "Load Blizzard UI" (`C_AddOns.LoadAddOn("Blizzard_GroupFinder_VanillaStyle")`), "Set comment" (`LFGListingComment.EditBox:SetText("FGF probe")` after load), "Post" (`C_LFGList.CreateListing{activityIDs={<first available dungeon>}, newPlayerFriendly=false, generalPlaystyle=0}` from OnClick), "Read entry" (print `GetActiveEntryInfo().comment` via issecretvalue guard), "Remove" (`C_LFGList.RemoveListing()`), "Dump players" (first 5 solo results: name, level, areaName, activity count). The user runs it out of combat and reports. Record in the ledger: search-from-addon-click OK?, CreateListing-from-click OK?, comment path OK?, areaName filled? Task 5 uses these answers.

### Task 1: Scaffold and ported framework

**Produces:** a loadable addon with an options window (General + Profiles pages, language dropdown), minimap button (left: toggle main window — a stub `ns.Window.Toggle()` that only prints for now; right: toggle lock), compartment globals, `/fgf` (no args: toggle window; `options`; `lock`; `unlock`; `reset`). `ns.L`, `ns.Locale`, `ns.On`, `ns.Print`, `ns.AfterCombat`, `ns.DB()`, `ns.AccountDB()`, `ns.ActiveProfile()`, profile functions, `ns.Settings` (Get/Set/SetMany/OnChange/Changed/TextStyle/ResetProfile/SetLocked/DEFAULTS/RANGES/TEXT_STYLES), `ns.Share`, `ns.Media`, `ns.Position`, `ns.Corners`, `ns.Border`, `ns.Resize`, `ns.Options` (window), `ns.MinimapButton`.

**Settings.DEFAULTS** (complete for 1.0; RANGES in brackets):
```
-- general
replaceBlizzard = true, minimapShow = true, minimapAngle = 215, compartment = true,
-- window
point = "CENTER", relPoint = "CENTER", x = 0, y = 40, width = 720 [560, 1100], height = 460 [320, 800],
scale = 100 [50, 150], locked = false, sideWidth = 190 [150, 280],
-- search & list
minInterval = 3 [3, 15], levelRangeOnly = true, category = 2, sortFriendsFirst = true,
filterMyRole = false, filterLevelFits = false, hideSeen = false, languages = {} (empty = all),
roleOverride = "AUTO" ("AUTO" | "TANK" | "HEALER" | "DAMAGER"),
markOpenSlot = true, showPlayers = true, rowHeight = 22 [16, 36], playerRowHeight = 34 [26, 50],
memoryMinutes = 30 [5, 240],
-- listing
expiryWarnMinutes = 5 [1, 15], templates = {} , whisperTemplates = { "Hi! Still looking for {role}? I'm a level {level} {class}." },
-- frame look (as the combat meter FOREVER style)
borderStyle = "NONE", borderSize = 1 [1, 8], borderColor = {0,0,0,1}, cornerRadius = 10 [0, 12],
shadowEnabled = true, shadowSize = 9 [1, 20], shadowAlpha = 65 [0, 100],
bgMode = "SOLID", bgColor = {0.047, 0.047, 0.055}, bgAlpha = 85 [0, 100], bgTexture = "Blizzard Dialog Background Gold",
headerLine = true,
-- text styles (Friz Quadrata like the quest log): header, activity, name, comment, small
headerFont = "Friz Quadrata", headerSize = 14 [8, 24], headerFlag = "SHADOW", headerColor = {1, 0.82, 0.29},
activityFont = "Friz Quadrata", activitySize = 12 [8, 20], activityFlag = "SHADOW", activityColor = {1, 0.82, 0.29},
nameFont = "Friz Quadrata", nameSize = 12 [8, 20], nameFlag = "SHADOW", nameColor = {1, 1, 1},
commentFont = "Friz Quadrata", commentSize = 11 [8, 18], commentFlag = "SHADOW", commentColor = {0.79, 0.76, 0.69},
smallFont = "Friz Quadrata", smallSize = 10 [7, 16], smallFlag = "SHADOW", smallColor = {0.55, 0.54, 0.5},
```
`templates` entries: `{ name = "", activityIDs = {}, roles = {tank=false, healer=true, dps=false}, comment = "" }` (comment is only offered for copying — the addon cannot write Blizzard's field). Tables (templates, languages, whisperTemplates) are stored whole when they differ from the default.

- [ ] Steps: copy/port the framework files, rename all identifiers, strip meter code, write the TOC, DEFAULTS, locale keys for everything above; tests: TOC lists only existing files, locales same keys/placeholders, settings defaults/ranges/only-non-defaults stored, profile switch/export/import round trip (`FGF1:`), slash parsing, compartment globals exist, secret lint green. `tests/run` green → commit "Scaffold: framework ported from Forever Combat Meter".

### Task 2: Finder (+ mock C_LFGList)

**Files:** create `Finder.lua`; extend `tests/wowmock.lua` with a fake `C_LFGList` (configurable categories/activities/results/members/member counts/active entry; secret mode that returns `secret` wrappers for the info getters; a "hardware event" flag the test sets around click calls — `Search`/`CreateListing`/`UpdateListing` called without it record a blocked action instead of acting, like the client); fake `C_LFGListRoles`, `C_LFGInfo.CanPlayerUsePremadeGroup`, `C_PartyInfo.InviteUnit`, `ChatFrameUtil.SendTell` (or `ChatFrame_SendTell` fallback).

**Produces:**
- `Finder.Search(opts)` → `true|false, reason` — `opts = {categoryID, activityIDs (may be empty), languages (set or nil)}`; refuses when a search is pending or the last one is younger than `S("minInterval")` (returns false, "throttled"/"pending"). Builds the languageFilter table only when `languages` is non-empty.
- `Finder.LastSearchAge()` → seconds or nil; `Finder.IsSearching()`.
- `Finder.Results()` → array of result tables `{id, activityIDs, leaderName, comment, numMembers, age, friends (numCharFriends+numBNetFriends), guild (numGuildMates), isDelisted, voiceMode, newPlayerFriendly, members = {{name, level, classFile, role (assignedRole), lfgRoles{tank,healer,dps}, area, isLeader}}, counts = {TANK, HEALER, DAMAGER, TANK_REMAINING, HEALER_REMAINING, DAMAGER_REMAINING}}`, every field secret-guarded (secret → nil); results without info (gone) skipped.
- `Finder.Result(id)` → one such table or nil (for row updates).
- `Finder.On(event, fn)` — events: `"RESULTS"`, `"RESULT_UPDATED"(id)`, `"FAILED"(reason)`, `"ACTIVE_ENTRY"`, `"AVAILABILITY"`, `"EXPIRED"`; wired to `LFG_LIST_SEARCH_RESULTS_RECEIVED`, `LFG_LIST_SEARCH_RESULT_UPDATED`, `LFG_LIST_SEARCH_FAILED`, `LFG_LIST_ACTIVE_ENTRY_UPDATE`, `LFG_LIST_AVAILABILITY_UPDATE`, `LFG_LIST_ENTRY_EXPIRED_TIMEOUT`, `LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS` via `ns.On`.
- `Finder.ActiveEntry()` → `{activityIDs, comment, duration, newPlayerFriendly, voiceMode}` or nil (secret-guarded).
- `Finder.CreateOrUpdate(entry)` → bool — `entry = {activityIDs, newPlayerFriendly, generalPlaystyle, voiceMode}`; Update when `C_LFGList.HasActiveEntryInfo()`; then `C_LFGListRoles.SetRoles(roles)` when `entry.roles`.
- `Finder.Remove()`; `Finder.Invite(name)`; `Finder.Whisper(name, text)` (opens chat with `/w name text`; text optional).
- `Finder.CanUse()` → bool, reason.

- [ ] Steps: tests first (throttle, pending, language filter shape, secret mode → nil fields and no error, results mapping incl. counts/members, update for one id, events fan out, create vs update, blocked-without-hardware-event recorded in mock), implement, `tests/run` green, commit "Finder: the only C_LFGList caller — throttled search, secret-safe results, listing calls".

### Task 3: Activities

**Produces:** `Activities.Categories()` → `{ {id, name} }` in the order 2, 114, 116, 118, 120 (only available ones); `Activities.List(categoryID, opts)` → array `{id, name, shortName, minLevel, maxLevel, maxPlayers, groupName, fit}` where `fit` ∈ `"FITS"|"LOW"|"HIGH"` against `UnitLevel("player")` (LOW: player level > maxLevel; HIGH: player level < minLevel); `opts = {levelRangeOnly=bool, text=string}`; with `levelRangeOnly` only FITS entries (same rule as Blizzard's `LFGUtil_GetFilteredActivities`: suggestion range; read it and mirror its behaviour, incl. CVar `disableSuggestedLevelActivityFilter` ignored by us — our own switch rules); sorted FITS first, then by minLevel, then name; text filter case-insensitive on name/shortName. `Activities.Info(id)` cached. `Activities.Name(id)`. Refresh cache on Finder `"AVAILABILITY"` and `PLAYER_LEVEL_UP`.

- [ ] Steps: tests (category order, fit classification at boundaries, switch on/off, sort, text filter, cache refresh), implement, green, commit "Activities: categories, level fit, level-range switch".

### Task 4: Results and Memory

**Produces:**
- `Memory.Key(result)` = `leaderName .. "|" .. table.concat(sorted activityIDs, ",")` (only from non-secret values; nil when leaderName nil); `Memory.MarkSeen(key)`, `Memory.Hide(key)`, `Memory.IsSeen(key)`, `Memory.IsHidden(key)`, `Memory.Ignore(name)`, `Memory.Unignore(name)`, `Memory.IsIgnored(name)`, `Memory.IgnoreList()`; seen/hidden expire after `S("memoryMinutes")` (stored with `time()`), ignore is permanent; stored account-wide in the profile DB under `memory = {seen={}, hidden={}, ignore={}}` (not part of export).
- `Results.Build(results, ctx)` → `{groups = {row...}, players = {row...}}` with `ctx = {myRole ("TANK"|"HEALER"|"DAMAGER"), myLevel, filters = {myRole, levelFits, hideSeen, text}, activityFit = function(id) → fit}`. Row: `{id, kind = "GROUP"|"PLAYER", activityIDs, leader, comment, age, members, counts, freeForMe (bool: counts[myRole.."_REMAINING"] > 0), fit (best fit of its activities), friend, guild, seen, area (player rows: the member's area), roles (player rows: lfgRoles), delisted}`. Players = results with `numMembers == 1` and no other members; groups otherwise. Ignored leaders and hidden keys are dropped; delisted kept but flagged. Filters: myRole → only freeForMe groups / players without effect (players are never filtered by role); levelFits → drop rows whose best fit is not FITS; hideSeen; text (comment, leader, activity names). Sort: friends/guild first (when `sortFriendsFirst`), then freeForMe, then fit (FITS, HIGH, LOW), then age ascending, tie-break id.
- `Results.MyRole()` → `roleOverride` unless "AUTO", else from `GetSpecializationRole(GetSpecialization())` when available, else `UnitGroupRolesAssigned("player")`, else "DAMAGER".

- [ ] Steps: tests (split, every filter, sort order incl. ties, memory expiry with a fake `time`, ignore drop, secret-nil fields don't break), implement, green, commit "Results and Memory: rows, filters, sorting, seen/hidden/ignore".

### Task 5: Listing

**Consumes:** probe results from the ledger (Task 0): Search/Create/Update/Remove work from an addon click; the addon must NEVER write the comment (SetText on Blizzard's comment EditBox is illegal; comments also need an authenticator).

**Produces:** `Listing.State()` → `{active=bool, activityIDs, comment, remaining (s) or nil, roles}`; `Listing.Post(activityIDs, roles)` (click path) → `Finder.CreateOrUpdate` (an existing comment is kept by UpdateListing); `Listing.Comment()` → current comment from the active entry (read-only, secret-guarded); `Listing.CanComment(categoryID)` → `C_LFGList.IsPlayerAuthenticatedForLFG(categoryID)` (via Finder); `Listing.OpenCommentEditor(text)` → `C_AddOns.LoadAddOn("Blizzard_GroupFinder_VanillaStyle")` then `LFGVanilla_ShowFrame(1)`; when `text` is non-empty and `CanComment` is true, prefill it with `pcall(LFGListingComment.EditBox.SetText, LFGListingComment.EditBox, text)` so the player can edit it in Blizzard's field before posting (the probe's "illegal when disabled by security settings" error was most likely the authenticator lock — untested for authenticated players); if that pcall fails, show the text in a small selectable edit box of OUR OWN (highlighted, "Ctrl+C, then Ctrl+V into Blizzard's comment field"). Never touch Blizzard's box when `CanComment` is false; `Listing.Remove()`; `Listing.Templates()`, `Listing.SaveTemplate(name, activityIDs, roles, comment)`, `Listing.DeleteTemplate(name)`, `Listing.ApplyTemplate(name)` → `{activityIDs, roles, comment}`; remaining time from `duration` of the active entry (seconds) counted down locally; `Listing.OnExpiryWarning(fn)` fires once when remaining < `expiryWarnMinutes`; `Listing.Missing(activityID)` → `{TANK=n, HEALER=n, DAMAGER=n}` from the party's `UnitGroupRolesAssigned` and the activity's `maxPlayers` (5 → 1/1/3; 10 → 2/3/5; 20 → 2/5/13; 40 → 4/10/26; others: DAMAGER = max − members), only when the player leads a group (`UnitIsGroupLeader("player")`). Whisper template expansion `{role}`, `{level}`, `{class}`, `{activity}`.

- [ ] Steps: tests (template CRUD + persistence shape, apply, countdown and single warning, missing roles per size and assigned roles, template expansion, post calls Finder in the right order, CanComment/OpenCommentEditor, the addon never calls SetText on Blizzard frames), implement, green, commit "Listing: post/update/remove, templates, expiry warning, leader role arithmetic".

### Task 6: Window, rows, menu

**Produces:** `ns.Window.Toggle()`, `Show()`, `Hide()`, `Refresh()`; the frame per spec variant B and mockup `layout-v2.html`:
- Header like the combat meter FOREVER style (title "Group Finder", refresh button showing "⟳ <age>" — click = `Finder.Search` with the current category/activities/languages; lock button; close button), corner resize arrows when unlocked (ns.Resize), position via ns.Position, ESC closes (UISpecialFrames).
- Left column (`sideWidth`): category selector (Dungeons, Raids, Quests & Zones, Battlegrounds, Custom), search box, scrollable activity list with checkboxes coloured by fit (FITS normal, LOW grey, HIGH red) showing "min–max", and at the bottom the checkbox "Only in my level range" (`levelRangeOnly`). Ticking/unticking an activity or switching category or the switch triggers a search (OnClick path) and updates "my listing" activities.
- Right top "My listing": activity chips (from the checked activities), current comment read-only + "Comment…" button (with the applied template's comment ready to copy) (opens Blizzard's listing tab; greyed with tooltip "Comments need an authenticator on your account" when `Listing.CanComment` is false), role toggles (solo), template dropdown (apply/save/delete), remaining time, buttons Post/Update and Remove; expiry warning text with "Extend" (re-post).
- Leader line (only when leading): "Missing: …".
- Filter chips: Room for my role, Level fits, Text (edit box), Hide seen, Language (dropdown multi-select).
- List: divider "Groups (n)", group rows (activity, member class squares with dashed free slots up to `maxPlayers` capped at 5 squares + "+n", comment, age, Guild/Friend tag, green left edge when freeForMe, dim when seen, delisted crossed-out), divider "Players (n)", player rows on two lines (class-coloured name, level, roles; location line with a pin icon; activity chips; comment; age). Rows recycled; `LFG_LIST_SEARCH_RESULT_UPDATED` updates the matching row in place (no re-sort until the next full result set).
- Hover tooltip: all members (name, level, class, role, area), comment, activities, age.
- Left click: whisper leader; right click menu (`Menu.lua`, Blizzard `MenuUtil.CreateContextMenu` if present, else our own simple menu): Whisper, Whisper template ▸ (expanded templates), Invite, Mark as seen, Hide, Ignore leader.
- Opening the window by click/key triggers a search (≥ min interval).

- [ ] Steps: tests with the mock (frame builds, activity list reflects switch, ticking triggers Finder.Search once and respects throttle, rows from Results, row update in place, tooltip lines, menu entries call Finder/Memory, leader line visibility, chips toggle settings, nothing protected used in combat), implement, green, commit "Window: activity column, my listing, filters, groups and players".

### Task 7: Blizzard redirection, options pages, commands

- `Blizzard.lua`: when `replaceBlizzard`, hook the globals Blizzard uses to open its finder — `LFGVanilla_ToggleFrame`, `LFGVanilla_ShowFrame`, `PVEFrame_ToggleFrame` if present (check the 70338 source for the micro button's call path and the TOGGLEGROUPFINDER binding) — with `hooksecurefunc` on the **global functions**; in the hook: if Blizzard's `LFGParentFrame` is shown, call `LFGParentFrame:SetAlpha(0)`-free approach: prefer closing via Blizzard's own global toggle only if that is untainted-safe; otherwise leave Blizzard's frame and simply show ours on top. Decide by reading the source; document the choice in a comment; test with the mock that our window opens and no frame method is hooked. Also `LFG_LIST_SHOW_SEARCH` → open ours.
- Options pages (combat meter style nav): General (replace Blizzard, minimap, compartment, language), Window (position X/Y, width, height, scale, side width, lock, reset), Appearance (border, background, header line, corners, shadow), Text (five text styles), List & Filters (row heights, mark open slot, show players, sort friends first, role override, memory minutes, ignore list editor), Templates (listing templates list with delete; whisper templates edit), Profiles (ported).
- `Commands.lua`: `/fgf` toggle, `options`, `lock`, `unlock`, `reset`, `search` (click path from chat), `ignore <name>`, `unignore <name>`.
- [ ] Steps: tests (hooks only on globals, pages build, every setting reachable, commands), implement, green, commit "Blizzard redirection, options pages, commands".

### Task 8: In-game check (controller with the user)

Install (`./install "<WoW>/_classic_beta_/Interface/AddOns"`), user `/reload`s and checks: opening via key/micro button/minimap/`/fgf`, activity list + level switch, search on interaction, groups/players with location, filters, memory, templates, posting (comment via Blizzard's tab if authenticated), leader line, options, profiles, combat (no errors, no blocked actions). Fix findings with tests.

### Task 9: Docs, CurseForge text, Vault

`README.md` (features, commands, install, tests, release), `docs/curseforge/description.md` + `logo.svg`/`logo.png` (Forever style), Vault page `10-Projekte/WoW-Addons/ForeverGroupFinder.md` (typ app, version, files table, pitfalls incl. the probe results), row in `WoW-Addons.md`, memory pointer `forever-group-finder.md` + MEMORY.md line. GitHub repo + CurseForge project id come from the user; release 1.0.0 only after the user's go.
