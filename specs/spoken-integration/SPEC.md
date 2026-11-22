---
id: spoken-integration
type: module-design
status: draft
title: Spoken Quests integration
parent: architecture
---

## Responsibility

When [Spoken Quests](https://github.com/taliyu/Spoken) is installed, this module shows the same
buttons Spoken adds to the built-in quest log. Each row gets a Play button before its title (Stop
while reading), or Contribute "+" where no voice pack covers the quest yet, or a greyed-out Play.
The detail pane's header strip gets round Play / Report buttons. File: `SpokenButtons.lua`, plus the
row button children in `Templates.xml`.

## Decisions

- **Optional, with no setting of our own.** The TOC lists `Spoken_Quests, Spoken` as `OptionalDeps`.
  Spoken's own gates decide whether the buttons show: its Quests part and its "Play buttons in the
  quest log" toggle (`QuestOverlayUI:ShowsQuestLogButtons`).
- **Wire Spoken's helpers, never copy them.** Art, play/stop/queue behaviour, contribute flow and
  tooltips all come from Spoken (`Spoken:DressBoxButton`, `Spoken:CreateRoundButton`,
  `VoiceOver.QuestOverlayUI`, `VoiceOver.Contribute`). Spoken exposes its internals through the
  global `VoiceOver` table on purpose, because its sound packs call in through it.
- **One button per pooled row**, rebound to the row's quest on every `Init`. This follows Spoken's
  own tracker adapter, so it never fights the built-in log's per-quest buttons over a frame parent.
- Sound data is keyed by the client's quest title, without our level prefix.

## Invariants

- Every lookup goes through `_G` at call time, so load order never matters. Without Spoken nothing
  runs, the buttons stay hidden and rows keep their plain layout.
- Every call into Spoken is wrapped in `pcall`. A failing integration must never blank the list or
  the detail pane.

## Boundary

- Called by `quest-list` rows (`DressRow`) and by `detail-pane` (`Init`, `UpdateDetail`). It calls
  nothing else in the addon.
- `/cql test spoken` reports what the integration sees.

## Known limitations

- The integration depends on Spoken's internal `VoiceOver` table rather than a stable API, so a
  change in Spoken can silently break the buttons. The `pcall` guards keep that from breaking the
  log itself.
