---
id: public-api
type: module-design
status: draft
title: Public API for other addons
parent: architecture
---

## Responsibility

Lets other addons draw on the Classic Quest Log window without reaching into `ns`. The first user is
Forever Quest Tint, which tints the detail pane's parchment and marks quest titles for quests that
are new to WoW Forever. File: `API.lua`.

## Decisions

- **Getters plus events, owned here.** The global `ClassicQuestLogAPI` (`version = 1`) returns the
  window, the detail pane, its parchment (`Bg`) and header strip, the displayed quest ID, and walks
  the list's quest rows with `ForEachQuestRow(fn)`. Changes are announced through `EventRegistry`,
  which `Actions.lua` already uses for the map ping, so no listener has to poll:
  `ClassicQuestLog.DetailShown (questID|nil)`, `.DetailLayout ()`, `.RowInit (row, questID,
  titleFontString)` and `.WindowHidden ()`.
- **The addon holds no integration code.** Whatever uses the API lives in the other addon. This
  mirrors how Forever Quest Tint supports Dialogue UI and ClassicUI Forever (it hooks their frames
  from its own side), and keeps Forever Quest Tint's vanilla-quest list single-sourced.
- **Events instead of `hooksecurefunc` on our functions**, because `ns` is private and because the
  rewards panel slides while text scrolls, which would otherwise force a polling `OnUpdate`.
- **`DetailShown` fires last.** It runs after the text, the rewards panel and Spoken's strip are laid
  out, so geometry is final. `DetailLayout` fires only when the rewards panel's height really
  changes. `RowInit` fires last in the row's `Init`, after Spoken re-anchors the title, and the
  title is plain text again, so a listener decorates it from scratch.
- **Parchment compatibility.** `Bg` uses the same Quest Text Contrast atlas family as
  `QuestMapFrame.DetailsFrame.Bg`, and its parent holds `RewardsFrameContainer`, so code written for
  the map's pane (Forever Quest Tint's `ApplyOverlay`) fits it.

## Invariants

- `ns.API.Fire` wraps the trigger in `pcall` and sends errors to the error handler. A listener's
  failure never stops the pane or the list from filling.
- Every getter answers from live frames and returns nil before they exist. `GetDisplayedQuestID`
  returns nil while the window is closed, since `Detail.questID` stays set after a hide.
- `version` is bumped on a breaking change to a getter or to an event's arguments. Adding a getter or
  an event does not bump it.
- The file loads before `QuestList.lua`, so the global exists before the frame's XML `OnLoad` fires
  the first event.

## Boundary

- Called by `detail-pane` (`DetailShown`, `DetailLayout`), `quest-list` (`RowInit`,
  `ForEachQuestRow`) and `architecture`'s Frame (`WindowHidden`). It calls only `ns.QuestList`.
- Consumers are other addons. Nothing inside this addon listens to its own events.

## Known limitations

- The API is only exercised by hand in the game together with Forever Quest Tint; there is no
  automated test.
