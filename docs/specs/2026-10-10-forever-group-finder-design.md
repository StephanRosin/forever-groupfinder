# Forever Group Finder — Design

Date: 2026-10-10 · Status: approved in conversation (layout variant B with the level switch and player locations;
feature list and architecture "passt so"). Mockups: `.superpowers/brainstorm/*/content/layout-v2.html` (git-ignored).

## Goal

A public WoW: Forever addon that replaces Blizzard's group finder (`Blizzard_GroupFinder_VanillaStyle`: separate
"post" and "browse" tabs, slow manual refresh, clumsy activity selection) with **one window** in the look and menu
structure of the other Forever addons (Forever Quest Log, Forever Combat Meter).

## Facts the design rests on (research + in-game probe, 10.10.2026)

- Forever ships the Vanilla-style finder (LoD, `LFGParentFrame` with `LFGListingFrame`, `LFGBrowseFrame`,
  `LFGWhoListFrame`). No applications: players and groups list themselves; actions are whisper and invite.
- `C_LFGList.Search` works from a click (also `/run`), but is **blocked from a timer** (in-game probe: `C_Timer` call
  → "Interface action failed because of an AddOn"; pcall still returns true). Same `HasRestrictions` flag on
  `CreateListing`, `UpdateListing`, `SetEntryTitle`, `ReportGroupAsAdvertisement` → treat all as click-only.
- `RemoveListing`, `GetSearchResults`/`GetFilteredSearchResults`, `GetSearchResultInfo`, `GetSearchResultPlayerInfo`,
  `GetSearchResultLeaderInfo`, `GetSearchResultMemberCounts`, `GetActiveEntryInfo` are free to call; the info getters
  return **secret values during chat-messaging lockdown** (instances/encounters).
- Data: per result `activityIDs`, `leaderName`, `comment`, `numMembers`, `age`, `numCharFriends`, `numBNetFriends`,
  `numGuildMates`, `isDelisted`, `voiceMode`, `newPlayerFriendly`, `partyGUID`; per member `name`, `level`, `areaName`,
  `classFilename`, `assignedRole`, `lfgRoles{tank,healer,dps}`, `isLeader`; `GetSearchResultMemberCounts` gives
  `TANK/HEALER/DAMAGER` and `<ROLE>_REMAINING`.
- Activities: `GetAvailableCategories`, `GetAvailableActivityGroups`, `GetAvailableActivities`,
  `GetActivityInfoTable` (fullName, shortName, minLevelSuggestion, maxLevelSuggestion, maxNumPlayers, …). Categories:
  2 Dungeons, 114 Raids, 116 Quests & Zones, 118 Battlegrounds, 120 Custom. Blizzard's level filter:
  `LFGUtil_GetFilteredActivities` + CVar `disableSuggestedLevelActivityFilter`.
- The listing comment is read by the engine from Blizzard's own EditBox (`StoreSecureReference("LFGListingComment",
  editBox)`); whether an addon can fill it (and whether `CreateListing` from our button works) is **unverified** →
  first implementation task is an in-game probe.
- Forever pitfalls (known from the other Forever addons): never `hooksecurefunc` frame methods (Forever makes them nil for
  Blizzard's code); hooking global functions is fine. Secret values: no `==`/`~= nil`, truthiness, arithmetic,
  concatenation or table keys on them — `issecretvalue` first.

## User-facing behaviour

1. **Opening**: Blizzard's group-finder key binding and micro button (via global function hooks, e.g.
   `LFGVanilla_ToggleFrame`/`LFGVanilla_ShowFrame`), `/fgf` (`/forevergroupfinder`), minimap button (left: window,
   right: lock), addon compartment. Blizzard's UI is not loaded by us; if something else opens it, we leave it alone.
   A setting "Replace Blizzard's group finder" (default on) turns the redirection off.
2. **Activity list (left column)**: search box; categories (Dungeons default, Raids, Quests & Zones, Battlegrounds,
   Custom) as a selector; activities sorted by level fit and coloured (fits: normal, too low: grey, too high: red);
   multi-select checkboxes; at the bottom the switch **"Only in my level range"** (default on; off shows all
   activities, same rule as Blizzard). The checked activities are used for **both** the search and my listing.
3. **Searching**: every user action searches when the last search is ≥ 3 s old: opening by click/key, ticking an
   activity, changing category or filter, the refresh button. One search in flight at a time. The refresh button shows
   the age of the list ("4 s ago"). `LFG_LIST_SEARCH_RESULT_UPDATED` updates single rows live (full, delisted,
   changed) without re-sorting jumps; `LFG_LIST_SEARCH_FAILED` shows a short message.
4. **Result list (right)**: **groups first, players below** (two dividers with counts).
   - Group row: activity name, member class squares + dashed free slots, comment, age, "Guild"/"Friend" tag.
   - Player row (two lines): class-coloured name, level, wanted roles; **current location** prominently
     (`areaName`); all activities the player listed for as chips; comment; age.
   - Hover: tooltip with every member (name, level, class, role, location), comment, activities.
   - Left click: whisper the leader/player. Right click menu: Whisper, Whisper template ▸, Invite, Mark as seen,
     Hide, Ignore leader.
   - Markers: green edge = free slot for my role; seen rows dimmed; level range coloured; friends and guild sorted
     first.
5. **Filter chips**: "Room for my role" (role from spec, overridable), "Level fits", text search (comment, name,
   activity), "Hide seen", language (search `languageFilter`).
6. **My listing (top of the right side)**: comment, my roles (solo), remaining time; warning shortly before expiry
   with "Extend"; post/update/remove buttons. **Templates**: saved sets of activities + comment + roles; picking one
   fills the listing, "Post" sends it (posting needs the click).
7. **Leader help**: when I lead a group: "Missing: 1 healer, 1 DPS" (from the party's assigned roles and the activity's
   size, 1/1/3 for 5-man), player section shows fitting solo players first, one-click invite.
8. **Memory**: seen/hidden entries keyed by leader name + activity, expiring after a configurable time (default 30
   min); ignore list by name (account-wide, editable on an options page).
9. **Options window** like the other Forever addons: General (replace Blizzard, minimap, compartment, language),
   Window/Layout (position X/Y, size, scale, lock, corner arrows), Appearance (border, background, header, corners),
   Text (fonts), List & Filters (sorting, markers, memory time, role override), Templates (listing and whisper
   templates), Profiles (account-wide profiles, export/import). EN, DE, ES, FR; default = game language.

## Architecture

GitHub `StephanRosin/forever-groupfinder` (public), TOC
`## Interface: 16001`, SavedVariables `ForeverGroupFinderProfiles` (account) and `ForeverGroupFinderChar`.

- **Framework** ported from Forever Combat Meter (same files and conventions): `Locale.lua` + `Locales/*`, `Core.lua`,
  `Settings.lua`, `Profiles.lua`, `Share.lua`, `Media.lua`, `Border.lua`, `Corners.lua`, `Position.lua`,
  `Resize.lua`, `Options/*`, `MinimapButton`, `Commands.lua`, tools (`install`, `tools/package`, `tools/release`),
  `tests/run` with the Lua 5.1 mock incl. the secret type and the secret lint.
- **`Finder.lua`** — the only code that calls `C_LFGList`: `Finder.Search(categoryID, activityIDs, languages)`
  (min interval 3 s, one in flight, click-path only), result reading with per-field secret guards (secret → nil),
  event fan-out (`RESULTS`, `RESULT_UPDATED(id)`, `FAILED(reason)`, `ACTIVE_ENTRY`, `AVAILABILITY`), listing calls
  (create/update/remove), expiry events.
- **`Activities.lua`** — categories, groups, activities with level ranges; level-fit classification; the level
  switch; search text match.
- **`Results.lua`** — pure: raw results → group rows and player rows; filters, sort (friends/guild, my-role fit, level
  fit, age), markers.
- **`Listing.lua`** — my listing state, remaining time, templates, leader role arithmetic.
- **`Memory.lua`** — seen/hidden/ignore with expiry.
- **`Window.lua`, `Rows.lua`, `Menu.lua`** — the frame (header like the quest log, left activity column, right listing
  + chips + list with recycled rows), tooltip, context menu.
- **`Blizzard.lua`** — redirection of Blizzard's open paths via global function hooks; never frame-method hooks.

## Testing

`tests/run` (Lua 5.1) against a mock with a fake `C_LFGList` (categories, activities, results, members, secret mode,
blocked-from-timer behaviour), covering Finder throttling, secret-safe reading, Activities filtering, Results
sorting/filtering/markers, Listing templates and role arithmetic, Memory expiry, settings/profiles/locales (same
keys in all four languages), plus the secret lint over the source.

## First task: in-game probe

Before building the window: a throwaway probe addon (not committed) checks in game (a) whether a button click in an
addon frame can call `Search` and `CreateListing`/`UpdateListing`, (b) whether setting the comment into Blizzard's
`LFGListingComment` EditBox (after `GroupFinderVanillaStyle_LoadUI`) reaches the posted listing, or which other path
works, (c) that `areaName` is filled for listed players. Results go into the plan; if (b) fails, posting with a comment
opens Blizzard's comment field briefly.

## Out of scope (1.0)

Auto-search by timer (blocked), applications (not in Forever), Raider.IO-style scores, cross-realm lists, LDB feed.

## Release

1.0.0 on CurseForge after in-game approval.
