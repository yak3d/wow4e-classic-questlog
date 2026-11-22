---
id: architecture
type: architecture-design
status: draft
title: Classic Quest Log — architecture
parent: goal
---

## Drivers

- Runs inside the WoW Forever client (build 1.60.1, `WOW_PROJECT_CAMELOT`) as one Lua 5.1 addon,
  `ClassicQuestLog/`. It has no build step, and Blizzard's UI code is the only platform. The Blizzard
  source of record is Gethe/wow-ui-source, branch `forever`.
- The quest log has to coexist with Blizzard's secure UI without tainting it (`blizzard-takeover`).
- It reuses Blizzard's frames and widgets instead of rebuilding them, because Camelot fixes its art
  offsets inside the stock templates.

## Topology

One feature per file, one file per module. Each file starts with `local addonName, ns = ...` and
declares `ns.<Module>`. Private state lives in file-level locals, and every module registers its
own events on its own `CreateFrame("Frame")`.

| Module | Files | Owns |
|---|---|---|
| Locale | `Locale.lua` | `ns.L` strings (enUS). Keys are prefixed per module: `FRAME_`, `LIST_`, `FILTER_`, `SETTING_`, `HOOK_`, `HELP_`, `DEV_` … |
| Core | `Core.lua` | Boot only: SavedVariables defaults and migration (`ClassicQuestLogDB`, `ClassicQuestLogCharDB`), `ns.Settings.Init()`, the slash router. No feature logic. |
| Dev | `Dev.lua` | The `/cql test <verb>` registry: smoke tests and state dumps. |
| Frame | `Frame.lua`, `Frame.xml` | The window: `UIPanelWindows`/`UISpecialFrames` registration, the two layouts, Show/Hide/Toggle/OpenToQuest, the quest count, and wiring the other modules to their child frames in `OnLoad`. |
| Quest list | `QuestList.lua`, `Search.lua`, `Filters.lua`, `Templates.xml` | See `quest-list`. |
| Detail | `Detail.lua` (+ `Detail` subtree in `Frame.xml`) | See `detail-pane`. |
| Actions | `Actions.lua` | Abandon/Share/Track and Show Map buttons, their enable rules and combat gate, and modified row clicks. Delegates to Blizzard's `QuestMapQuestOptions_*` functions. |
| Spoken | `SpokenButtons.lua` | See `spoken-integration`. |
| API | `API.lua` | See `public-api`. |
| Hooks | `Hooks.lua` | See `blizzard-takeover`. |
| Settings | `Settings.lua` | The Settings → AddOns panel. Every DB key is registered with a live-apply callback, which `ns.Settings.ApplyLive` also gives to the Dev `set` verb. |

**Load order** (the TOC): strings → boot → dev → public API → module Lua → XML → hooks → settings. Mixins are
globals defined in Lua before the XML that names them with `mixin=`. The frame's `OnLoad` runs
before `ADDON_LOADED`, so modules tolerate a missing `ns.db`. Core then re-applies the layout and
the search setting once the DB exists.

**Call edges:** Frame initialises QuestList, Detail, Search, Filters and Actions. QuestList calls
Search and Filters while building, then Detail, Actions and Frame (the count) on refresh. Detail and
QuestList rows call Spoken and fire the API's events. Hooks and Core call Frame. Settings calls Hooks, Frame, QuestList and
Search. Modules call each other only through public `ns.<Module>` functions.

## Data

- `ClassicQuestLogDB` (account): `enabled`, `layout`, `showLevel`, `difficultyColor`, `showSearch`,
  `hideMapQuestPanel`, `trackerOpensLog`. The defaults live in `Core.lua` (`ns.defaults`).
- `ClassicQuestLogCharDB` (character, no UI): `mapPanelCollapsed`, `collapsedHeaders[title]`,
  `filters`.
- Defaults are deep-filled into saved tables without overwriting saved values. Each DB has a
  `version` field for future migrations.

## Decisions

- **A Blizzard UI panel, not a free window.** It docks left, pushes other left panels
  (`pushable = 0`, as the classic `QuestLogFrame` did) and closes with Esc through `UISpecialFrames`
  even in combat. Whether the window should be draggable is open.
- **Combat fallbacks.** Out of combat, show and hide go through `ShowUIPanel`/`HideUIPanel`. In
  combat they use plain `:Show()` at a fixed anchor and `:Hide()`. A layout change made in combat is
  deferred to `PLAYER_REGEN_ENABLED`. Show Map and the action buttons are disabled in combat.
- **Events only while shown.** QuestList, Detail and Actions register their refresh events on
  OnShow and drop them on OnHide. Bursts of `QUEST_LOG_UPDATE` are coalesced into one refresh with
  `C_Timer.After(0)`.
- **Client look.** Chrome comes from stock templates (`ButtonFrameBaseTemplate`, `InsetFrameTemplate`,
  `SearchBoxTemplate`, `WowStyle1FilterDropdownTemplate`, `MinimalScrollBar`) and from atlases set by
  name. Fonts are stock font objects and colours are named globals. Labels use Blizzard global
  strings first. The one exception is `L.FRAME_COUNT`, because `QUEST_LOG_COUNT_TEMPLATE`'s arguments
  differ between flavours. Sounds are `SOUNDKIT` constants.

## Invariants

- `Core.lua` holds no feature logic.
- No Blizzard method on any frame or mixin is overwritten. The one allowed global replacement is
  `ToggleQuestLog` (see `blizzard-takeover`).
- Every `ShowUIPanel`/`HideUIPanel` call has an `InCombatLockdown()` fallback.
- No textures ship with the addon.
- The list is filled before the detail pane or any optional integration runs, so a failure there
  can never blank the list.

## Tooling

- `just install` symlinks `ClassicQuestLog/` into the client's flavor folders. After that, `/reload`
  picks up edits.
- `just lint` runs luacheck with `.luacheckrc`. Every new global the addon reads or writes is listed
  there.
- CI (`.github/workflows/addon.yml`) lints every push and pull request. On `v*` tags it packages with
  the BigWigs packager, attaches the zip to a GitHub release and uploads it to Wago (project
  `## X-Wago-ID` in the TOC, key in the `WAGO_API_TOKEN` secret; skipped without it). A tag
  containing `alpha` or `beta` becomes a prerelease. The zip is built and checked once without
  uploading, then rebuilt to publish, because the packager only uploads a zip it built in the
  same run. `.pkgmeta` ignores every top-level path except the addon folder. A CI step
  fails if the zip holds anything besides the addon's tracked files, so a new top-level path
  (`specs/` included) needs an ignore entry.

## Known limitations

- There are no automated tests beyond luacheck. Behaviour is checked by hand in game with the
  `/cql test` verbs and visual checks.
- Actions caps tracking at `MAX_QUEST_WATCHES`. When the client defines no such constant, it falls
  back to a hardcoded 25.
