---
id: blizzard-takeover
type: module-design
status: draft
title: "Blizzard takeover: L key, map panel, tracker routing"
parent: architecture
---

## Responsibility

Makes the game's own entry points open this log instead of the World Map's quest panel, without
tainting secure code. File: `Hooks.lua`, installed on `PLAYER_LOGIN`. The map-panel setting's live
apply lives in `Settings.lua`.

## Taint discipline

- **The one global replacement is `ToggleQuestLog`**, which the L binding (`TOGGLEQUESTLOG`) and the
  quest micro button both call. `SetEnabled` swaps it with the saved original, so `/cql toggle` and
  the `enabled` setting restore Blizzard's behaviour live.
- Everything else is a `hooksecurefunc` post-hook. Never replaced: `OpenQuestLog` (needed by
  `QuestMapFrame_OpenToQuestDetails`), `QuestMapFrame_OpenToQuestDetails` (the tracker's
  "Show quest map" item and other callers use it), and any `WorldMapFrame` or `QuestMapFrame`
  method.
- Out of combat only. In combat, routing does nothing and Blizzard's behaviour stands.

## Behaviours

- **Micro button:** a post-hook on `QuestLogMicroButton:UpdateMicroButton` shows the pushed state
  while our window is open, because the original only checks `WorldMapFrame`.
- **Map quest panel, collapsed once per character.** On the first login with `hideMapQuestPanel`
  on, the addon sets CVar `questLogOpen = 0` and marks `chardb.mapPanelCollapsed`, then never
  touches the CVar again. The map's own side-panel toggle persists the player's later choice, and
  tracker-driven `OpenQuestLog()` calls don't write the CVar. Turning the setting off sets the CVar
  to 1 and clears the flag.
- **Tracker routing** (`trackerOpensLog`):
  - A `GLOBAL_MOUSE_DOWN` handler records whether the map was shown before any click handler runs.
  - Post-hooks on `QuestObjectiveTracker` and `CampaignQuestObjectiveTracker`
    `OnBlockHeaderClick` act only when the click was not a right-click, the map was closed before
    the click and is open now, and we are out of combat. They then hide the map and open our log on
    the block's quest. Chat links, watch toggles and auto-complete pop-ups never open the map, so
    they fail this guard.
  - A post-hook on `QuestUtil.OpenQuestDetails` (the "View in quest log" menu item) closes
    Blizzard's popup when it opened and opens our log instead.
  - If the map was already open, Blizzard's behaviour is unchanged.

## Boundary

- Calls only `ns.Frame.Toggle` and `ns.Frame.OpenToQuest`, and reads `ns.db`/`ns.chardb`.
- Any new takeover must follow the taint discipline above and be switchable from settings.
