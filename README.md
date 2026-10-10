# Forever Group Finder

A group finder for **WoW: Forever** (Interface 16001), in the look of the other
Forever addons. One window replaces Blizzard's group finder: search and list
groups and players, filter them, post your own listing and invite or whisper with
a click.

English, Deutsch, Español, Français.

## Install

Download the zip from CurseForge and unpack it into
`<WoW>/_classic_beta_/Interface/AddOns/`, or install from this repository:

```sh
./install "<WoW>/_classic_beta_/Interface/AddOns"
```

Then `/reload` or restart the game.

## Use

`/fgf` opens the window. Further commands:

| Command | Does |
| --- | --- |
| `/fgf options` | opens the options |
| `/fgf search` | runs a search (opens the window first if it is closed) |
| `/fgf lock` / `unlock` | locks or unlocks the window |
| `/fgf reset` | puts the window back to its default place and size |
| `/fgf ignore <name>` / `unignore <name>` | ignores a player or takes it back |

## Features

- **Layouts**: "List and details" (default) and "Sidebar".
- **Activities** by category with a fit colour for your level and an
  "Only in my level range" switch.
- **Groups** sectioned per dungeon (collapsible), role icons Tank, Healer, DPS
  including free slots, leader, levels and size.
- **Players** with a role icon and level, name, location, abbreviated dungeon
  tags, comment and playstyle; sort by role, level or newest.
- **Filters**: room for my roles (default on), level fits, hide seen, language,
  playstyle, text.
- **My listing**: status, roles (limited to your class's roles), playstyle,
  purpose and comment, one Post/Update/Remove button, expiry warning and extend.
- **Details**: members, free slots, whisper and whisper templates, seen, hide,
  ignore with undo.
- **Leader help**: missing roles, fitting players, one-click invite.
- **Options** in the Forever style: list look (font and icon sizes), button
  sizes, profiles shared across characters, export and import as text.

### Limits set by the game

- Searches run on clicks. The client blocks addons from searching on a timer, so
  the list never refreshes by itself; it pulses when it is outdated.
- Editing the comment of your own listing requires an account authenticator
  (a Blizzard rule).

## Development

| Path | Purpose |
| --- | --- |
| `tests/run` | the test suite, Lua 5.1 against a client mock (`tests/wowmock.lua`) |
| `./install <AddOns folder>` | copies the addon's files into an AddOns folder |
| `tools/package` | builds `dist/ForeverGroupFinder-<version>.zip` |
| `tools/release <release\|beta\|alpha> "<changelog>"` | runs the tests, packages and uploads to CurseForge (token from `$CURSEFORGE_TOKEN` or `~/.config/curseforge-token`) |

Bump `## Version` in the TOC before a release.

## License note

Forever Group Finder is written from scratch.
