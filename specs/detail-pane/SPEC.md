---
id: detail-pane
type: module-design
status: draft
title: Quest detail pane
parent: architecture
depends-on: [spoken-integration]
---

## Responsibility

Shows the selected quest's details the way the World Map's quest details show them, and is where
the Abandon / Share / Track buttons sit. Files: `Detail.lua` and the `Detail` subtree in
`Frame.xml`. The buttons' behaviour belongs to Actions (see `architecture`).

## Decisions

- **Copy the World Map's look**, because Forever players already know the map's quest details
  (confirmed). The map's border, filigree, header strip and pinned rewards panel are rebuilt from
  their atlases. The text is drawn with `QUEST_TEMPLATE_MAP_DETAILS` into our ScrollChild, and the
  rewards with `QUEST_TEMPLATE_MAP_REWARDS` into a panel pinned to the bottom. This replaces the
  parchment `QUEST_TEMPLATE_LOG` display that `PLAN.md` describes.
- **Fallback.** When the client lacks the map templates or helpers, the rewards stay inline and the
  pane falls back to `QUEST_TEMPLATE_LOG`.
- **Width.** The pane is 40 px wider than the map's 308. The map's details template is copied with a
  wider `contentWidth`, minus room for a scrollbar that sits inside the pane. The background art is
  scaled to the width and cropped at the pane's height.
- **Rewards panel behaviour mirrors the map.** While text remains to scroll, the panel shrinks
  (never below 124 px) and grows back as the text reaches its end. A spacer at the end of the text
  matches the panel's height, so the last lines can scroll clear of it.
- **Contrast option.** The background atlas is read from `QuestTextContrast` before every display,
  and a `QuestTextContrast` `CVAR_UPDATE` triggers a redisplay.

## Invariants

- `QuestInfo_Display` reaches the detail frame through `parentFrame:GetParent():GetParent()`. The
  chain must stay **Detail → ScrollFrame → ScrollChild**, and `Detail.questID` must be set before
  every display.
- The QuestInfo widgets and `MapQuestInfoRewardsFrame` are shared with Blizzard's NPC `QuestFrame`
  and the World Map. The pane redisplays when they are released (`QUEST_FINISHED`, World Map
  `OnHide`) and on every show.
- With no quest selected or an empty log, the pane shows the empty-state art and text.

## Boundary

- Receives quest IDs from `quest-list`. It never selects quests.
- Calls `spoken-integration` after each display to update the strip of Spoken buttons on the header.
- Listens to `QUEST_LOG_UPDATE`, `QUEST_FINISHED` and `CVAR_UPDATE` only while the window is shown.
