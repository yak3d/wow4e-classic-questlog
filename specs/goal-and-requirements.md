---
id: goal
type: goal-and-requirements
status: draft
title: Classic Quest Log — goal and requirements
---

## Goal

Bring back the classic WoW quest log on **WoW Forever** (the Camelot client). Zone headers sit on the
left and the selected quest's details on the right, with Abandon / Share / Track underneath. It opens
with **L**, and Blizzard's quest panel inside the World Map stays collapsed until the player asks
for it.

## Problem

Forever folds the quest log into the World Map's side panel. Players who want the classic standalone
log, with a scannable zone list and details next to it, have to open the map to read a quest.

## Audience

WoW Forever players who prefer the classic quest log, and players of the
[Spoken Quests](https://github.com/taliyu/Spoken) addon, who expect its Play buttons in whichever log
they use.

## Capabilities

- **Standalone quest log window**, a docked Blizzard UI panel that pushes other left panels and closes
  with Esc. Toggled by L, the quest micro button, `/cql` or `/classicquestlog`.
- **Two layouts** (setting): double pane, the default, with the list left and details right; or
  single pane, with the list on top and details below.
- **Zone-grouped quest list** with collapsible headers that remember their state per character, an
  optional level prefix, optional difficulty colouring, Complete / Failed / Camelot type tags, a
  watched checkmark, and a party-member count with a tooltip of names.
- **Search box** (can be hidden) that filters by title.
- **Filter dropdown**, saved per character: current zone, hide grey, tracked only, party only, and
  status / difficulty / quest type submenus.
- **Quest details as the World Map shows them**, with the rewards pinned to the bottom while the
  text scrolls, and respect for the Quest Text Contrast accessibility option.
- **Actions:** Abandon (Blizzard's confirm), Share (when grouped), Track / Untrack, Show Map (opens the
  quest's zone and pings it), shift-click to link a quest in chat, and alt- or ctrl-click to toggle
  watch.
- **Blizzard takeover**: L opens this log (switchable), the map's quest panel is collapsed once per
  character, and objective-tracker clicks open this log on that quest (switchable).
- **Spoken Quests integration** when that addon is installed: Play / Contribute buttons on the rows
  and Play / Report buttons on the detail pane.
- **Settings** under Settings → AddOns → Classic Quest Log, all applied live without `/reload`.
- **Developer smoke tests** through `/cql test <verb>`.

## Principles

- **Never taint Blizzard's secure UI.** Combat must keep working with the addon loaded; see
  `blizzard-takeover`.
- **Use the client's own look.** Stock templates, atlases, fonts, colours, sounds and global
  strings. The addon ships no textures.
- **The player's choices win.** Once the player reopens the map's quest panel, that choice sticks.
  Every takeover behaviour can be turned off.

## Non-goals

- Clients other than WoW Forever. The `_classic_beta_` install target is only a development
  convenience.
- An Addon Compartment entry, a separate keybinding (L is taken over instead), and window scale or
  font size settings.
- Side or top tabs, a quest POI map inside the log, and an expand/collapse-all button.
- Translations beyond enUS. Blizzard's global strings already localise most labels.
- Copying code from EraUI (All Rights Reserved). Its screenshot is a layout reference only.
