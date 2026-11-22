---
id: quest-list
type: module-design
status: draft
title: Quest list, search and filters
parent: architecture
depends-on: [detail-pane, spoken-integration]
---

## Responsibility

Turns the client's quest log into the zone-grouped list the window shows, and owns the list's
ScrollBox, header and row templates, selection, search and filters. Files: `QuestList.lua`,
`Search.lua`, `Filters.lua` and `Templates.xml`.

## Building the list

`ns.QuestList.Build()` creates no frames. It returns a flat array of header and row nodes, which
`/cql test list` prints.

- **Visible quest:** not `isTask`, not `isHidden`, and not a bounty unless the bounty is complete.
- **Collapse state belongs to the addon.** It is saved per character in
  `ClassicQuestLogCharDB.collapsedHeaders[zoneTitle]`. The game's header flag is not used, because
  Blizzard's map code resets it on every loading screen (`QuestMapFrame_ResetFilters` on
  `PLAYER_ENTERING_WORLD`), which once emptied the list on a fresh login.
- A header is kept only while it has visible quests. A collapsed header still counts its hidden
  rows, so it stays in the list and can be expanded. Opening a quest from outside the list expands
  that quest's zone.
- **Search:** a case-insensitive plain substring match on the title. While a search is active, every
  header counts as expanded and rows show no level prefix or difficulty colour. Hiding the search
  box clears the filter.
- **Filters** (`ns.Filters.Passes`) apply on top of search. A quest must pass every active rule.
  The status, difficulty and type submenus save the entries the player *unticked*, so an empty set
  shows everything. Grey (trivial) quests are handled only by the "Hide grey" toggle. The type
  submenu lists only the types present in the log, and a quest with several types stays visible
  while any of them is ticked.

## Row decorations

- **Level prefix** (`showLevel`): `QuestUtilsOverrides.GetQuestTitlePrefix` when it answers,
  otherwise our own `[12] ` / `[12+] `, where `+` means a suggested group of 5 or more. The
  override only answers when client CVars ask for it.
- **Difficulty colour** (`difficultyColor`): computed with `GetDifficultyColor` because Blizzard's
  override returns nil whenever `showQuestDifficultyColor` is off.
- **Tag priority:** Failed, then Complete, then `QuestUtilsOverrides.GetQuestTagText`.
- **Watched** uses `QuestUtils_IsQuestWatched`, because this build has no
  `C_QuestLog.IsQuestWatched`.
- The **party count** and its tooltip of names come from `QuestUtils_GetNumPartyMembersOnQuest` and
  `C_QuestLog.IsUnitOnQuest`. The count is always on.

## Selection and refresh

- Selection is the client's own (`C_QuestLog.SetSelectedQuest`/`GetSelectedQuest`). When the window
  opens, the selected quest is kept if it is still visible. Otherwise the first visible quest is
  selected.
- A refresh rebuilds the list, keeps the scroll position, updates the empty text ("no quests" or
  "no filter match"), the quest count and the action buttons, and only then touches the detail pane.
- The module listens to `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `GROUP_ROSTER_UPDATE`,
  `UNIT_QUEST_LOG_CHANGED`, `QUEST_REMOVED` and `ZONE_CHANGED_NEW_AREA` only while the window is
  shown.

## Boundary

- Reads the client quest log APIs and `ns.db`/`ns.chardb`. Never writes the game's header collapse
  state.
- Hands row clicks to `ns.Actions.RowClicked`, details to `ns.Detail.Show` and the count to
  `ns.Frame.SetQuestCount`.
- Each row's Spoken buttons are dressed by `spoken-integration` from the row's `Init`.
- The row's `Init` ends by firing `RowInit` through `public-api`, and `ForEachQuestRow` serves its
  `ns.QuestList.ForEachQuestRow` backs the API's getter of the same name.

## Known limitations

- The current-zone filter is approximate. It compares the zone header's title with
  `GetRealZoneText()`, so subzones and quests filed under another header can be misclassified.
