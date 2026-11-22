# Classic Quest Log — Build Plan (tutor-ready)

The classic WoW quest log: zone headers on the left, parchment details on the
right, and Abandon / Share / Track along the bottom. It is rebuilt for
**WoW Forever** (client build 1.60.1.70334, codename **Camelot**,
`WOW_PROJECT_CAMELOT = 18`) using Forever's own bronze-era UI art. Pressing L
opens it. Blizzard's quest panel inside the World Map stays hidden until the
player asks for it.

The build is split into **eight tutor sessions** (Stage 0–7). Say
**"Use @tutor on PLAN.md, Stage N"** to start one.

Layout reference: `questlog.png` (screenshot 1). Theming references: the
Forever Character frame and the Recent Allies / Social frame (screenshots 2
and 3), plus `../wow-your-chronicle/YourChronicle/UI/` for working examples of
the newer assets.

Blizzard source for this exact build: Gethe/wow-ui-source, branch `forever`,
commit `2ced784` ("1.60.1 (70334)"). Every file:line reference below points
into that tree.

---

## Decisions — settled (interview rounds 1 and 2)

| # | Topic | Decision |
|---|-------|----------|
| 1 | Pane layout | A **setting**: `double` (default: list on the left, parchment on the right) or `single` (tall 1.x style: list on top, detail below). The window has no "Double pane" checkbox. |
| 2 | L key | L **always opens ours** (global `ToggleQuestLog` is replaced). |
| 3 | Map quest panel | **Collapsed once per character, then left alone.** On first login with the addon, set CVar `questLogOpen = 0`. The map's own side-panel toggle brings the panel back, and that choice persists. |
| 4 | Window type | A **Blizzard UI panel**: `UIPanelWindows` entry, docks left, pushes other panels, Esc closes it, not draggable. |
| 5 | Name | "Classic Quest Log". Folder `ClassicQuestLog`, DB `ClassicQuestLogDB` (+ `ClassicQuestLogCharDB`), slash `/cql` and `/classicquestlog`. |
| 6 | Detail pane | **Reuse Blizzard's QuestInfo**: `QuestInfo_Display(QUEST_TEMPLATE_LOG, …)` into our own ScrollChild. |
| 7 | List style | **Camelot Skills look**: a `common-button-list-collapseExpand` bar with a plus/minus icon on the right. |
| 8 | Buttons | **Red three-slice** (`128-RedButton` atlas family). |
| 9 | Show Map | Opens the World Map on the quest's zone and **pings** it. Blizzard's panel stays collapsed. |
| 10 | Tracker clicks | A left-click on a quest in the objective tracker opens **our** log on that quest. This can be turned off in settings. |
| 11 | v1 extras | Level prefix (setting), difficulty colour (setting), search box (setting), party-member count. |
| 12 | TOC file | `ClassicQuestLog.toc`, a plain name with no suffix. |
| 13 | Plan format | This file. |

---

## Ground rules for every session

- The tutor teaches; **you type**. Take one step at a time and verify it before
  moving to the next.
- **Every step ends with a named test** (L / S / G, see below).
- **Every step lands in one module.** Cross-module calls go only through public
  functions that already exist.
- Everything hangs off `ns`. Strings go in `Locale.lua`, files go in the TOC in
  load order.
- **Never copy EraUI code.** EraUI's `Classic/QuestLog.lua` (the source of
  screenshot 1) is *All Rights Reserved*. Use the screenshot for layout and
  nothing else.
- **No hand-built NineSlice layouts or backdrops.** Camelot fixes its art offsets
  inside the global `NineSliceLayouts` at load time. Inheriting stock
  templates (`ButtonFrameTemplate`, `InsetFrameTemplate`, …) gets those fixes
  for free; a hand-rolled layout does not.
- **No shipped textures.** Every texture is a client atlas or a client file
  path from the asset table below.
- **Taint discipline** (details in §Blizzard integration):
  - Never overwrite a Blizzard *method* on a frame or mixin. The one allowed
    global replacement is `ToggleQuestLog`.
  - Everything else is a `hooksecurefunc` post-hook.
  - Every `ShowUIPanel` / `HideUIPanel` call has an `InCombatLockdown()`
    fallback.
- The code in this repo uses normal, plain naming and comments.

### The three test layers

- **L** — `make lint` (luacheck). The tutor runs it at every gate.
- **S** — slash smoke test through `/cql test <verb>` (from `Dev.lua`). The verbs:
  - dump state;
  - probe atlases;
  - print the built quest list;
  - flip settings;
  - simulate the combat gate.
- **G** — in-game visual check after `/reload`. You confirm these.

---

## Module architecture

**One feature = one file = one module.**
- Each file starts with `local addonName, ns = ...`, declares `ns.<Module>`,
  and keeps private state in file-level locals.
- **Each module owns its events** on its own `CreateFrame("Frame")`.
- **`Core.lua` is boot only.** It does DB init, migration, `ns.Settings.Init()`,
  and the slash router. Feature logic never goes there.
- **Locale keys are prefixed per module**: `FRAME_`, `LIST_`, `DETAIL_`,
  `ACTION_`, `SEARCH_`, `HOOK_`, `SETTING_`, `HELP_`, `DEV_`.
- **Mixins load before the XML that names them.** A non-virtual frame's
  `mixin=` attribute is resolved when its XML loads.

| File | Module | Job | Built in |
|------|--------|-----|----------|
| `ClassicQuestLog.toc` | — | load order + metadata | Stage 0 |
| `Locale.lua` | `ns.L` | strings | exists |
| `Core.lua` | boot | DB init, char DB, slash router | exists, trimmed Stage 0 |
| `Dev.lua` | `ns.Dev` | `/cql test` verb registry | Stage 0 |
| `QuestList.lua` | `ns.QuestList` | list builder, header/row mixins, ScrollBox | Stage 2 |
| `Detail.lua` | `ns.Detail` | parchment pane, QuestInfo bridge | Stage 3 |
| `Actions.lua` | `ns.Actions` | Abandon/Share/Track/Close, Show Map, row clicks | Stage 4 |
| `Search.lua` | `ns.Search` | search box filter | Stage 6 |
| `Filters.lua` | `ns.Filters` | filter dropdown: zone, grey, tracked, party, status, difficulty, type; saved per character in `ClassicQuestLogCharDB.filters` | Stage 6 |
| `Frame.lua` | `ns.Frame` | window mixin, layouts, show/hide, UIPanel registration | Stage 1 |
| `Templates.xml` | — | virtual header/row templates | Stage 2 |
| `Frame.xml` | — | `ClassicQuestLogFrame` tree | Stage 1 |
| `Hooks.lua` | `ns.Hooks` | L takeover, micro button, map panel, tracker routing | Stage 5 |
| `Settings.lua` | `ns.Settings` | Settings → AddOns panel | rebuilt Stage 6 |
| `API.lua` | `ns.API`, `ClassicQuestLogAPI` | public getters and `ClassicQuestLog.*` events for other addons (see `specs/public-api`) | after Stage 7 |

---

## TOC — `ClassicQuestLog/ClassicQuestLog.toc`

This replaces `ClassicQuestLog_Camelot.toc`. Delete the old file in the same
step.

```
## Interface: 16001
## Title: Classic Quest Log
## Notes: The classic quest log for WoW Forever: zone list, parchment details, Abandon/Share/Track. Opens with L.
## Author: Yak
## Version: @project-version@
## IconTexture: Interface\QuestFrame\UI-QuestLog-BookIcon
## Category: Quests
## AllowLoadGameType: camelot
## SavedVariables: ClassicQuestLogDB
## SavedVariablesPerCharacter: ClassicQuestLogCharDB
## LoadSavedVariablesFirst: 1
## X-License: GPL-3.0-only
## X-Website: https://github.com/yak3d/wow4e-classic-questlog
# ## X-Curse-Project-ID: <set once the CurseForge project exists>

# Load order: strings -> boot -> dev tools -> module Lua (mixins) -> XML -> hooks -> settings
Locale.lua
Core.lua
Dev.lua
QuestList.lua
Detail.lua
Actions.lua
Search.lua
Frame.lua
Templates.xml
Frame.xml
Hooks.lua
Settings.lua
```

| Key | Value | Why |
|-----|-------|-----|
| `Interface` | `16001` | Matches your other Forever addons. **Verify in Stage 0** with `/dump select(4, GetBuildInfo())`. |
| `Title` | `Classic Quest Log` | Display name from decision 5. |
| `Notes` | one line | Shown in the AddOns list tooltip. |
| `Author` | `Yak` | Same capitalisation as ScrollingQuestText. |
| `Version` | `@project-version@` | The BigWigs packager substitutes the git tag. |
| `IconTexture` | `Interface\QuestFrame\UI-QuestLog-BookIcon` | Same book as the portrait. Precedent: `Blizzard_WorldMap.lua:30`. |
| `Category` | `Quests` | Groups the addon in the AddOns list. |
| `AllowLoadGameType` | `camelot` | We rely on Forever-specific behaviour: the `QuestUtilsOverrides` level prefix and the Camelot Skills art. **Verify in Stage 0** that the addon still shows in the list. If it does not, drop this line. |
| `SavedVariables` | `ClassicQuestLogDB` | Account-wide settings. |
| `SavedVariablesPerCharacter` | `ClassicQuestLogCharDB` | Per-character `mapPanelCollapsed` flag (decision 3). |
| `LoadSavedVariablesFirst` | `1` | The DB exists before any file runs. Matches ScrollingQuestText. |
| `X-License` | `GPL-3.0-only` | The repo LICENSE is GPLv3. |
| `X-Website` | repo URL | |
| `X-Curse-Project-ID` | commented out | A wrong ID breaks packager uploads. Fill it in when the project exists. |

**Keys left out on purpose:**
- `AddonCompartmentFunc*` (not in v1).
- `Dependencies` / `OptionalDeps` (we need only Blizzard code that is always
  loaded).
- `LoadOnDemand`.
- `IconAtlas` (`IconTexture` is set).
- `Group`, `DefaultState`.

---

## Frame tree — names, templates, sizes

### Top level

`ClassicQuestLogFrame` — a `Frame` with:
- `parent="UIParent"`, `toplevel="true"`, `hidden="true"`, `enableMouse="true"`;
- `inherits="ButtonFrameTemplate"`, `mixin="ClassicQuestLogFrameMixin"`.

It needs a global name for `UIPanelWindows`, `UISpecialFrames` and the
micro-button hook.

| Child (parentKey) | Global name | Template / type | Notes |
|---|---|---|---|
| `PortraitContainer.portrait` | (template) | from `PortraitFrameBaseTemplate` | `self:SetPortraitToAsset([[Interface\QuestFrame\UI-QuestLog-BookIcon]])` |
| `TitleContainer.TitleText` | (template) | from template | `self:SetTitle(QUEST_LOG)` |
| `CloseButton` | (template) | `UIPanelCloseButtonDefaultAnchors` | Red X: `RedButton-Exit` atlases. Camelot anchors it at TOPRIGHT (-2,1). |
| `CountFrame` | `$parentCountFrame` | `Frame` + BACKGROUND texture atlas `common-dropdown-textholder` | Child `Text` uses `GameFontNormalSmall` and shows `L.FRAME_COUNT` = "Quests: %d/%d". The count turns `RED_FONT_COLOR` at the cap. |
| `SearchBox` | `$parentSearchBox` | `EditBox inherits="SearchBoxNineSliceTemplate"` | Forever search bar (`common-searchbar-a`). Hidden when `showSearch` is off. |
| `ShowMapButton` | `$parentShowMapButton` | `Button` | Texture `Interface\QuestFrame\UI-QuestMap_Button`: texcoords (0.125,0.875,0,0.5) up, (…,0.5,1) down. `Text` = `SHOW_MAP` in `GameFontNormal`. Highlight is `Interface\BUTTONS\ButtonHilight-Square` ADD. Same build as Blizzard's popup (`QuestMapFrame.xml:340`). |
| `Inset` | `$parentInset` | from `ButtonFrameTemplate` (`InsetFrameTemplate`) | **The list pane.** Re-anchored per layout. |
| `Inset.QuestList` | — | `Frame` | holds the list |
| `Inset.QuestList.ScrollBox` | `ClassicQuestLogListScrollBox` | `WowScrollBoxList` | |
| `Inset.QuestList.ScrollBar` | `ClassicQuestLogListScrollBar` | `EventFrame inherits="MinimalScrollBar"` | Camelot anchoring: TOPLEFT→ScrollBox TOPRIGHT (5,-2), BOTTOMLEFT→ScrollBox BOTTOMRIGHT (5,4). |
| `Inset.QuestList.EmptyText` | — | FontString `GameFontDisable` | `QUEST_LOG_NO_QUESTS` |
| `Detail` | `ClassicQuestLogDetailFrame` | `Frame inherits="QuestFramePanelTemplate"` | Gives `Bg`, `Material*` and `SealMaterialBG`. In OnLoad, re-anchor `Bg` and `SealMaterialBG` to fill the frame, because the template anchors them at (7,-62). |
| `Detail.ScrollFrame` | `ClassicQuestLogDetailScrollFrame` | `EventScrollFrame inherits="ScrollFrameTemplate"` | Uses the MinimalScrollBar by default. KeyValues `scrollBarX=6`, `scrollBarTopY=-4`, `scrollBarBottomY=5`, as in Blizzard's popup. |
| `Detail.ScrollFrame.ScrollChild` | — | `Frame` 10 narrower than the pane | The `parentFrame` passed to `QuestInfo_Display`. |
| `Detail.Empty` | — | Texture atlas `QuestLog-empty-quest-background` + FontString `GameFontDisable` | Shown when no quest is selected. |
| `AbandonButton` | `$parentAbandonButton` | `Button inherits="SharedButtonSmallTemplate"` | `ABANDON_QUEST_ABBREV`, BOTTOMLEFT (4,4) |
| `ShareButton` | `$parentShareButton` | same | `SHARE_QUEST_ABBREV`, LEFT→Abandon RIGHT (2,0) |
| `TrackButton` | `$parentTrackButton` | same | `TRACK_QUEST_ABBREV` / `UNTRACK_QUEST_ABBREV`, LEFT→Share RIGHT (2,0) |
| `BottomCloseButton` | `$parentBottomCloseButton` | same | `CLOSE`, BOTTOMRIGHT (-6,4) |

**Bottom buttons:** 100×22 each.
- `SharedButtonSmallTemplate` (`Shared/Button/ThreeSliceButtonTemplate.xml:87`)
  is in SharedXML, so it is always loaded. It inherits
  `BigRedThreeSliceButtonTemplate`, which uses the `128-RedButton-Left/Right`
  and `_128-RedButton-Center` atlases.
- The Camelot-only `SmallRedThreeSliceButtonTemplate` (99×27,
  `Camelot/PaperDollFrame.xml:3`) is the fallback if 22 px looks squashed in the
  G test.

**Detail frame structure is a hard requirement.** `QuestInfo_Display` does
`parentFrame:GetParent():GetParent()` (`Mainline/QuestInfo.lua:32`) to reach the
detail frame, then reads `.questID` and `.SealMaterialBG`. So the chain must be
**Detail → ScrollFrame → ScrollChild**, and `Detail.questID` must be set before
each display.

### Layouts (`ns.Frame.LAYOUTS`; numbers are starting points, tuned in G tests)

Both layouts:
- The attic (`y 0..-60`) holds the title bar, portrait, `CountFrame`,
  `SearchBox` and `ShowMapButton`.
- The bottom bar (`y 0..26`) holds the four buttons.

| | `double` (default) | `single` |
|---|---|---|
| Frame | 682 × 496 | 384 × 600 |
| `CountFrame` | TOPLEFT (64,-32), 110×20 | same |
| `SearchBox` | LEFT→CountFrame RIGHT (10,0), 170×20 | LEFT→CountFrame RIGHT (10,0), 120×20 |
| `ShowMapButton` | TOPRIGHT (-10,-28) | same |
| `Inset` (list) | TOPLEFT (4,-60) → BOTTOMLEFT (4,26), width 322 | TOPLEFT (4,-60) → TOPRIGHT (-6,-60), height 170 |
| `Detail` | TOPLEFT→Inset TOPRIGHT (4,0) → BOTTOMRIGHT (-6,26): 346×410 | TOPLEFT→Inset BOTTOMLEFT (0,-4) → BOTTOMRIGHT (-6,26): 374×340 |
| `Detail.ScrollFrame` | TOPLEFT (8,-34) → BOTTOMRIGHT (-30,6): the top band is the Spoken Play / Report strip | same |

`ns.Frame.ApplyLayout(name)`:
1. Resize the frame, then re-anchor the panes and the attic.
2. If the frame is shown, call `UpdateUIPanelPositions(ClassicQuestLogFrame)`.
3. In combat, store `pendingLayout` and apply it on `PLAYER_REGEN_ENABLED`.

### UI panel registration (`Frame.lua`, at file scope after XML loads → in `OnLoad`)

```lua
UIPanelWindows["ClassicQuestLogFrame"] = { area = "left", pushable = 0, whileDead = 1 }
tinsert(UISpecialFrames, "ClassicQuestLogFrame")
```

- `pushable = 0` and `whileDead = 1` are the classic `QuestLogFrame` values. The
  frame pushes other left panels but is not pushed itself.
- `UISpecialFrames` makes Esc work even in combat, because that path uses
  plain `:Hide()`.

Show and hide go through one pair of functions:

```lua
function ns.Frame.Show()
    if InCombatLockdown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        frame:Show()
    else
        ShowUIPanel(frame)
    end
end
```

`Hide` mirrors it with `HideUIPanel` and `:Hide()`. `Toggle` checks `IsShown()`.

- OnShow plays `SOUNDKIT.IG_QUEST_LOG_OPEN` and refreshes.
- OnHide plays `SOUNDKIT.IG_QUEST_LOG_CLOSE`.
- Both call `QuestLogMicroButton:UpdateMicroButton()`.

### Virtual templates (`Templates.xml`)

**`ClassicQuestLogHeaderTemplate`**
- `Button`, `mixin="ClassicQuestLogHeaderMixin"`, height 26.
- It copies the visuals of Camelot `SkillsHeaderTemplate`
  (`Camelot/SkillsFrame.xml:3`) instead of inheriting it, because that mixin
  is tied to the Skills data.
- BACKGROUND: texture atlas `common-button-list-collapseExpand`, set to fill
  the row (**not** `useAtlasSize`, because the row width varies by layout).
- HIGHLIGHT: the same atlas, `alphaMode="ADD"`, `alpha="0.3"`.
- BORDER: `StateIcon`, RIGHT (-8,-1). Atlas `common-button-list-plus` when
  collapsed, `common-button-list-minus` when expanded, with
  `TextureKitConstants.UseAtlasSize`.
- OVERLAY: `Name` FontString `GameFontNormalLeft`, LEFT (10,0), RIGHT→StateIcon
  LEFT (-4,0).

**`ClassicQuestLogQuestRowTemplate`**
- `Button`, `mixin="ClassicQuestLogQuestRowMixin"`, height 20.
- Hover and selection copy the Professions recipe row
  (`Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml:189-201`).
  Both textures use `useAtlasSize` for height. LEFT/RIGHT anchors (y -1)
  stretch them to the row width:
  - `SelectedOverlay` = `Professions_Recipe_Active` on OVERLAY sublevel 2,
    hidden unless the row is selected.
  - `HighlightOverlay` = `Professions_Recipe_Hover` on HIGHLIGHT, alpha 0.5,
    hidden while the row is selected.
  - On hover the `Title` turns `HIGHLIGHT_FONT_COLOR`, and goes back to its
    difficulty colour on leave.
- `Check`: atlas `questlog-icon-checkmark-yellow`, 14×14, LEFT (6,0). Shown
  when the quest is watched.
- `GroupMates`: `GameFontNormalSmall`, LEFT (22,0), text "[2]". Shown when
  party members share the quest, with a tooltip listing their names.
- `Title`: `GameFontNormalLeft`, LEFT→GroupMates RIGHT (2,0), RIGHT→Tag LEFT
  (-4,0), single line, word wrap off.
- `Tag`: `GameFontNormalSmall`, justifyH RIGHT, RIGHT (-6,0). Shows "(Complete)",
  "(Failed)", or the Camelot tag text such as "(Elite)" or "(Dungeon)".

---

## Asset reference

Stage 0 probes every **atlas** in this table with `C_Texture.GetAtlasInfo`
(`/cql test atlases`). Anything missing gets its fallback before Stage 1.

| Asset | Kind | Used for | Source / precedent | Fallback |
|---|---|---|---|---|
| `ButtonFrameTemplate` (`Mainline/SharedUIPanelTemplates.xml:711`) | template | window chrome: bronze metal border, portrait ring, rock bg | Forever CharacterFrame look | `PortraitFrameTemplate` + own Inset |
| `UI-Frame-PortraitMetal-CornerTopLeft`, `UI-Frame-Metal-Corner*`, `_UI-Frame-Metal-Edge*`, `!UI-Frame-Metal-Edge*` | atlas (via template) | border | NineSlice `PortraitFrameTemplate` layout | — (never set directly) |
| `RedButton-Exit` / `-exit-pressed` / `-Exit-Disabled` / `-Highlight` | atlas (via template) | red X | `UIPanelCloseButtonDefaultAnchors` | — |
| `Interface\QuestFrame\UI-QuestLog-BookIcon` | file | portrait, TOC icon | `Blizzard_WorldMap.lua:30` | — |
| `InsetFrameTemplate` | template (via `Inset`) | dark list pane | `UI-Frame-Inner*` pieces | add `UI-Character-Info-General-BG` under it if the list reads too light |
| `common-button-list-collapseExpand` | atlas | zone header bar | `Camelot/SkillsFrame.xml:7` | `Options_ListExpand_Left/Middle/Right` |
| `common-button-list-plus` / `-minus` | atlas | header state icon | `Camelot/SkillsFrame.lua:304-306` | `Options_ListExpand_Right_Expanded` |
| `Professions_Recipe_Active` / `Professions_Recipe_Hover` | atlas | row selected + hover | `Blizzard_ProfessionsRecipeList.xml:189-201` | `Interface\QuestFrame\UI-QuestLogTitleHighlight` file |
| `questlog-icon-checkmark-yellow` | atlas | watched check | `QuestLogTrackCheckboxTemplate` | `checkmark-minimal` |
| `common-dropdown-textholder` | atlas | quest count box | `Blizzard_Menu` dropdowns | `InsetFrameTemplate3` |
| `SearchBoxNineSliceTemplate` (`common-searchbar-a`, `common-searchbar-icon-a`, `common-search-clearbutton`) | template | search box | Recent Allies (screenshot 3) | `SearchBoxTemplate` |
| `Interface\QuestFrame\UI-QuestMap_Button` | file | Show Map icon | `QuestMapFrame.xml:347` | — |
| `MinimalScrollBar` (`minimal-scrollbar-track-*`, `minimal-scrollbar-small-thumb-*`, `minimal-scrollbar-arrow-top/bottom*`) | template | both scrollbars (chevrons) | `Shared/Scroll/MinimalScrollBar.xml:15` | — |
| `WowScrollBoxList` | template | list scroll box | `Shared/Scroll/ScrollTemplates.xml:4` | — |
| `QuestFramePanelTemplate` → `QuestBG-Parchment` (or `QuestTextContrast.GetDefaultBackgroundAtlas()`) | template + atlas | parchment | `Mainline/QuestFrameTemplates.xml:3` | — |
| `QuestLog-empty-quest-background` | atlas | empty detail state | Mainline QuestMapFrame | plain parchment + text |
| `SharedButtonSmallTemplate` → `128-RedButton-Left/Right`, `_128-RedButton-Center` | template + atlas | bottom buttons | `Shared/Button/ThreeSliceButtonTemplate.xml:87` | `SmallRedThreeSliceButtonTemplate`, then `UIPanelButtonTemplate` |

---

## Theming guidelines

1. **Inherit, don't redraw.** Chrome comes from stock templates with stock
   `layoutType`s. If something looks wrong, change the template or the anchor.
   Never paint over the border.
2. **Atlases by name, through `SetAtlas`.** Use
   `TextureKitConstants.UseAtlasSize` only where Blizzard's own template does
   (icons). Stretch bars and backgrounds with two-point anchors.
3. **Every atlas is in the asset table and probed in Stage 0.** A new atlas
   joins the table and the probe list in the same step.
4. **Fonts are stock font objects only:**
   - gold labels and headers: `GameFontNormal` / `GameFontNormalLeft`;
   - values and white text: `GameFontHighlight`;
   - small tags: `GameFontNormalSmall`;
   - disabled or empty text: `GameFontDisable`.
   - Parchment text is QuestInfo's job: `QuestTitleFont` / `QuestFont`, coloured
     by `GetMaterialTextColors`. Never recolour it.
5. **Colours come from named globals or C_UIColor**, never hex literals.
   - Named globals: `NORMAL_FONT_COLOR`, `HIGHLIGHT_FONT_COLOR`,
     `RED_FONT_COLOR`, `DISABLED_FONT_COLOR`, `WHITE_FONT_COLOR`.
   - Difficulty: `GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID))`.
     Its colour table's `font` is a ready font object, if you prefer that to
     `SetTextColor`.
6. **Respect the accessibility contrast option.** Call
   `QuestFrame_SetMaterial(detail, "Parchment")` before every
   `QuestInfo_Display`. That swaps `Bg` to
   `QuestTextContrast.GetDefaultBackgroundAtlas()` and handles light text.
   Re-run on `CVAR_UPDATE` for `QuestTextContrast`.
7. **Spacing scale: 2 / 4 / 6 / 10.**
   - 4 px gutters between panes and around the bottom buttons (matches the
     `ButtonFrameTemplate` inset offsets).
   - ScrollBox padding 6, element spacing 2.
   - 10 px text inset inside headers (matches SkillsHeader).
8. **Whole-pixel sizes and offsets only.** Fractional anchors blur the
   three-slice and NineSlice edges.
9. **Blizzard global strings first.** Use `QUEST_LOG`,
   `ABANDON_QUEST_ABBREV`, `SHARE_QUEST_ABBREV`, `TRACK_QUEST_ABBREV`,
   `UNTRACK_QUEST_ABBREV`, `SHOW_MAP`, `CLOSE`, `COMPLETE`, `FAILED`,
   `QUEST_LOG_NO_QUESTS`, `SEARCH` and `PARENS_TEMPLATE`. They localise for
   free.
   - **Exception:** the count uses our own `L.FRAME_COUNT`, because
     `QUEST_LOG_COUNT_TEMPLATE`'s arguments differ between flavours (Vanilla
     passes 2, Cata passes 3).
10. **Sounds are `SOUNDKIT` constants only:**
    - `IG_QUEST_LOG_OPEN` / `IG_QUEST_LOG_CLOSE`;
    - `IG_QUEST_LIST_SELECT` on row click;
    - `IG_MAINMENU_OPTION_CHECKBOX_ON` / `OFF` on track;
    - `IG_QUEST_LOG_ABANDON_QUEST` comes from Blizzard's popup.

---

## Settings (`Settings.lua`, Settings → AddOns → Classic Quest Log)

The account-wide DB is `ClassicQuestLogDB`. Every setting is registered with
`Settings.RegisterAddOnSetting(category, "ClassicQuestLog_<Key>", key, ns.db, type, name, default)`
and applied live through `SetOnValueChangedCallback`.

| Label | DB key | Type | Default | Control | Live apply |
|---|---|---|---|---|---|
| Replace the quest log (L key) | `enabled` | Boolean | `true` | Checkbox | `ns.Hooks.SetEnabled(v)`: swaps `ToggleQuestLog` between ours and the saved original |
| Layout | `layout` | String | `"double"` | Dropdown (`CreateControlTextContainer`: Double pane / Single pane) | `ns.Frame.ApplyLayout(v)` (deferred in combat) |
| Show quest levels | `showLevel` | Boolean | `true` | Checkbox | `ns.QuestList.Refresh()` |
| Colour quests by difficulty | `difficultyColor` | Boolean | `true` | Checkbox | `ns.QuestList.Refresh()` |
| Show search box | `showSearch` | Boolean | `true` | Checkbox | `ns.Search.SetShown(v)`: hiding it clears the filter |
| Hide the quest panel in the World Map | `hideMapQuestPanel` | Boolean | `true` | Checkbox | on: `SetCVar("questLogOpen","0")` and set the char flag; off: `SetCVar("questLogOpen","1")` and clear the char flag |
| Objective tracker clicks open this log | `trackerOpensLog` | Boolean | `true` | Checkbox | the hooks read the flag on every click |

Not exposed as settings:
- **Party count** is always on.
- **The per-character DB** `ClassicQuestLogCharDB = { version = 1, mapPanelCollapsed = false }`
  is internal and has no UI.

The template's `exampleValue` slider is removed in Stage 0.

---

## Blizzard integration (`Hooks.lua`)

### L key / micro button

Blizzard's path: `TOGGLEQUESTLOG` → `ToggleQuestLog()` (`Blizzard_WorldMap.lua:1417`).
The micro button's `QuestLogMicroButtonMixin:OnClick` also calls the global.

On `PLAYER_LOGIN`:
1. Save `originalToggleQuestLog = ToggleQuestLog`.
2. If `enabled`, set `ToggleQuestLog = ns.Frame.Toggle`.

Do **not** touch:
- `OpenQuestLog` — `QuestMapFrame_OpenToQuestDetails` needs it;
- `WorldMapFrame` methods;
- `QuestMapFrame` methods.

Micro button:
- `hooksecurefunc(QuestLogMicroButton, "UpdateMicroButton", fn)`, where
  `fn` calls `self:SetPushed()` when `ClassicQuestLogFrame:IsShown()`. The
  original logic is at `Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua:1142`;
  it only checks `WorldMapFrame`.

### Map quest panel — collapse once per character

The map's side-panel toggle (`QuestLogOwnerMixin:HandleUserActionToggleSidePanel`,
`QuestLogOwnerMixin.lua:64`) writes CVar `questLogOpen`. The map reads it on
open through `ShouldShowQuestLogPanel()` (`:190`).

On `PLAYER_LOGIN`, if `db.hideMapQuestPanel and not chardb.mapPanelCollapsed`:
1. `SetCVar("questLogOpen", "0")`.
2. Set `chardb.mapPanelCollapsed = true`.

After that we never touch it again, so the player's toggle is persistent.
Tracker-driven `OpenQuestLog()` calls do **not** write the CVar (`:94`), so
they cannot undo this.

### Objective tracker → our log

**Do not** replace `QuestMapFrame_OpenToQuestDetails`. The tracker's
right-click `OBJECTIVES_SHOW_QUEST_MAP` menu item uses it too
(`Blizzard_QuestObjectiveTracker.lua:103`), and so do the quest timer and
other callers.

Instead:
1. Register `GLOBAL_MOUSE_DOWN`, active only while `trackerOpensLog` is on.
   The handler snapshots `mapWasShown = WorldMapFrame:IsShown()`. This fires
   before click handlers.
2. Add `hooksecurefunc(QuestObjectiveTracker, "OnBlockHeaderClick", fn)`, and
   the same on `CampaignQuestObjectiveTracker` (it exists in this build:
   `Blizzard_CampaignQuestObjectiveTracker.xml:3`). The left-click branch is
   `Blizzard_QuestObjectiveTracker.lua:51-71`.
   - Guard: `mouseButton ~= "RightButton"`, `mapWasShown` was false,
     `WorldMapFrame:IsShown()` is now true, and not `InCombatLockdown()`.
   - The map-state check covers the other branches too. A chat link, a
     `QUESTWATCHTOGGLE` click or an auto-complete pop-up never opens the map,
     so those clicks fail the guard on their own.
   - If all hold, call `HideUIPanel(WorldMapFrame)`, then
     `ns.Frame.OpenToQuest(block.id)`.
   - In combat, Blizzard's behaviour is left as is.
3. Add `hooksecurefunc(QuestUtil, "OpenQuestDetails", fn)`
   (`Mainline/QuestUtils.lua:352`). This is the `OBJECTIVES_VIEW_IN_QUESTLOG`
   menu item, and it calls `QuestLogPopupDetailFrame:ShowQuest`, which toggles.
   - Only when the popup is now shown and we are out of combat: call
     `HideUIPanel(QuestLogPopupDetailFrame)`, then `ns.Frame.OpenToQuest(questID)`.

### Show Map (`Actions.lua`)

```lua
local mapID = GetQuestUiMapID(questID, true)
if not mapID or mapID == 0 then mapID = C_Map.GetBestMapForUnit("player") end
OpenWorldMap(mapID)
EventRegistry:TriggerEvent("MapCanvas.PingQuestID", questID)
```

- The button is disabled in combat (`PLAYER_REGEN_DISABLED`/`ENABLED`).
- `WorldMapFrame` is a left-area panel with `allowOtherPanels`. Opening it may
  close our window; this is expected and classic did the same.

### Combat summary

| Action | Out of combat | In combat |
|---|---|---|
| L / micro / `/cql` | `ShowUIPanel` / `HideUIPanel` | `:Show()` / `:Hide()` at a fixed anchor |
| Esc | panel manager | `UISpecialFrames` |
| Layout change | immediate | deferred to `PLAYER_REGEN_ENABLED` |
| Show Map | enabled | disabled |
| Tracker routing | ours | Blizzard default |

---

## Data: building the list (`ns.QuestList.Build()`)

`Build()` is a pure function: no frames, so `/cql test list` can print its
result.

```
for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    info = C_QuestLog.GetInfo(i)
    header  -> start a header node { isHeader, title, questLogIndex, isCollapsed }
    quest   -> visible if: not info.isTask and not info.isHidden
                           and (not info.isBounty or C_QuestLog.IsComplete(info.questID))
               add a row node unless the current header is collapsed (and no search is active)
drop headers with no visible quests (collapsed ones count their hidden rows)
```

- Collapsing does **not** remove children from `GetInfo`, so filter them out
  yourself.
- Collapse state is the addon's own: `ClassicQuestLogCharDB.collapsedHeaders[title]`.
  The game's header flag is not used, because Blizzard's map code resets it
  (`QuestMapFrame_ResetFilters`, on every `PLAYER_ENTERING_WORLD`), which
  emptied the list on a fresh login. A collapsed header stays in the list
  (it still has visible quests) so it can be expanded; opening a quest from
  outside the list expands its zone.
- While a search is active, every header is treated as expanded and only
  matching rows are kept.

**Row decorations:**
- **Level prefix** (`showLevel`):
  `QuestUtilsOverrides.GetQuestTitlePrefix(info)` gives "[12] " or "[12+] " for
  elite (`Blizzard_FrameXMLUtil/Mainline/QuestUtilsOverrides.lua:3`). Guard the global.
- **Difficulty colour** (`difficultyColor`): our own call to `GetDifficultyColor(…)`.
  Blizzard's override returns nil whenever the CVar `showQuestDifficultyColor`
  is off, so we compute it ourselves.
- **Tag priority:**
  1. `C_QuestLog.IsFailed` → `PARENS_TEMPLATE:format(FAILED)`;
  2. `C_QuestLog.IsComplete` → `PARENS_TEMPLATE:format(COMPLETE)`;
  3. otherwise `QuestUtilsOverrides.GetQuestTagText(questID)`.
- **Party count:** `QuestUtils_GetNumPartyMembersOnQuest(questID)`
  (`Mainline/QuestUtils.lua:1061`). The tooltip names each `party<i>` for
  which `C_QuestLog.IsUnitOnQuest` is true.
- **Count box:** `select(2, C_QuestLog.GetNumQuestLogEntries())` /
  `C_QuestLog.GetMaxNumQuestsCanAccept()`.

**ScrollBox setup:**
- `view = CreateScrollBoxListLinearView(6, 6, 6, 6, 2)`.
- `view:SetElementFactory` picks the header or row template by
  `node.isHeader`.
- `ScrollUtil.InitScrollBoxListWithScrollBar(ScrollBox, ScrollBar, view)`.
- `ScrollBox:SetDataProvider(CreateDataProvider(nodes), ScrollBoxConstants.RetainScrollPosition)`.

**Selection:** `C_QuestLog.SetSelectedQuest(questID)`, then
`ns.Detail.Show(questID)`.
- On open, keep `C_QuestLog.GetSelectedQuest()` if it is still in the visible
  list. Otherwise select the first visible quest.

### Events (registered only while the window is shown)

| Module | Events |
|---|---|
| QuestList | `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `GROUP_ROSTER_UPDATE`, `UNIT_QUEST_LOG_CHANGED`, `QUEST_REMOVED` |
| Detail | `QUEST_LOG_UPDATE` (selected quest only), `QUEST_FINISHED` (QuestInfo widgets were borrowed by the NPC QuestFrame: redisplay), `CVAR_UPDATE` (`QuestTextContrast`) |
| Actions | `PLAYER_REGEN_DISABLED`/`ENABLED`, `QUEST_WATCH_LIST_CHANGED`, `GROUP_ROSTER_UPDATE` |
| Frame | `PLAYER_REGEN_ENABLED` (only while `pendingLayout` is set) |
| Hooks | `PLAYER_LOGIN` (always), `GLOBAL_MOUSE_DOWN` (while `trackerOpensLog` is on) |

Coalesce bursts of `QUEST_LOG_UPDATE` with one `C_Timer.After(0, …)` refresh
flag per module.

---

## Dev verbs (`Dev.lua`, `/cql test <verb>`)

| Verb | Prints / does |
|---|---|
| `dump` | `ClassicQuestLogDB`, `ClassicQuestLogCharDB`, current layout, `questLogOpen` CVar |
| `atlases` | every atlas from the asset table; lists the missing ones (expect zero) |
| `list` | `Build()` output: headers with collapsed state, rows with prefix/tag/colour, totals |
| `set <key> <value>` | flips a DB key and runs its live-apply callback (used before Stage 6 exists) |
| `layout double\|single` | shortcut for `set layout` |
| `select <questID>` | selects a quest and opens the window on it |
| `combat on\|off` | drives our own combat gate (`ns.Actions.SetCombatState`) without real lockdown |
| `hooks` | whether `ToggleQuestLog` is ours, micro hook and tracker hooks installed, `mapWasShown` |
| `search <text>` | applies a filter and prints the match count |

---

## Stage 0 — Groundwork

*Goal: the addon loads on Forever under its real name, and every asset we
plan to use is confirmed to exist.*

Files: `ClassicQuestLog.toc` (renamed), `Core.lua`, `Locale.lua`, new
`Dev.lua`, `Makefile`, `README.md`, `.luacheckrc`.

1. **TOC.** Rename `ClassicQuestLog_Camelot.toc` → `ClassicQuestLog.toc` and
   fill in every key from the table above.
   *Test: G — `/dump select(4, GetBuildInfo())` prints `16001`. The AddOns list
   shows "Classic Quest Log" with the book icon under "Quests". If it is
   missing, remove `AllowLoadGameType` and retest. L clean.*
2. **Core trim + char DB.**
   - Replace `exampleValue` with the seven settings defaults.
   - Init `ClassicQuestLogCharDB`.
   - Add `SLASH_CLASSICQUESTLOG2 = "/cql"`.
   - Make the template's `toggle` verb flip `enabled` through
     `ns.Hooks.SetEnabled`. Stub it until Stage 5.
   *Test: S — `/cql test dump` shows all seven keys plus
   `mapPanelCollapsed = false`.*
3. **`Dev.lua`.** Add the verb registry, `dump` and `atlases`.
   *Test: S — `/cql test atlases` reports 0 missing. Any miss gets its fallback
   swapped into this plan before Stage 1.*
4. **Tooling.**
   - Fix the Makefile default `WOW_DIR`: it lacks `pfx/`. The real path is
     `$(HOME)/Faugus/battlenet/pfx/drive_c/Program Files (x86)/World of Warcraft`.
   - Replace the `ADDON_TITLE` / `ADDON_NOTES` placeholders in the README.
   - Add the new globals to `.luacheckrc`.
   *Test: L clean. `make install` creates the symlink under `_classic_beta_`.*

**Gate:** L + S.

## Stage 1 — Window shell

*Goal: an empty but correctly themed panel docks left, pushes, and closes with
Esc.*

Files: new `Frame.lua`, `Frame.xml`.

1. `ClassicQuestLogFrame` with `ButtonFrameTemplate`, portrait, title and red
   X. Add the `UIPanelWindows` / `UISpecialFrames` registration, and
   `ns.Frame.Show/Hide/Toggle` with combat fallbacks and sounds. Wire `/cql`
   with no args to `Toggle`.
   *Test: G — `/cql` opens it docked left. Open the Character frame (C) and it
   sits beside ours. Esc closes it. L clean.*
2. Attic: `CountFrame` (static text for now), the `SearchBox` shell and
   `ShowMapButton` (visual only).
   *Test: G — compare against screenshots 1 and 3. The search bar has Forever
   art; the map icon presses down on click.*
3. Panes: the re-anchored `Inset`, a `Detail` placeholder with parchment,
   `LAYOUTS` and `ApplyLayout`.
   *Test: S — `/cql test layout single`, then `double`. G — both shapes match
   the table and the panel re-docks without a gap.*
4. Bottom bar: four red three-slice buttons, initially disabled.
   *Test: G — the disabled state reads as grey text on red art, and nothing
   overlaps at 22 px. If it looks squashed, switch to
   `SmallRedThreeSliceButtonTemplate`.*

**Gate:** L; G both layouts.

## Stage 2 — Quest list

Files: new `QuestList.lua`, `Templates.xml`.

1. `ns.QuestList.Build()` as a pure function, plus the `list` verb.
   *Test: S — `/cql test list` matches your quest log: headers, quest count,
   no hidden or task quests.*
2. Header and row templates, and the ScrollBox wired to `Build()`.
   *Test: G — Skills-style header bars with a minus on the right, rows below,
   and a chevron scrollbar.*
3. Collapse and expand through `ExpandQuestHeader` / `CollapseQuestHeader`.
   *Test: S + G — collapse a zone, and `/cql test list` shows it collapsed.
   Open the map's own panel: the same zone is collapsed there too.*
4. Row decorations: level prefix, difficulty colour, tags, watch check, party
   count with tooltip.
   *Test: S — `/cql test set showLevel false` makes the prefixes vanish;
   `difficultyColor false` turns rows gold. G — a finished quest shows
   "(Complete)", and a tracked quest has the yellow check.*
5. Selection, the live count, empty state, and event refresh while shown.
   *Test: G — accept a quest: the count ticks up and the row appears. Abandon
   it from the map: the row goes and the selection moves to a valid quest.*

**Gate:** L + S; G = live updates during play.

## Stage 3 — Detail pane

Files: new `Detail.lua` (+ `Detail` children in `Frame.xml`).

1. The Detail → ScrollFrame → ScrollChild structure, `QuestFrame_SetMaterial`
   + `QuestInfo_Display(QUEST_TEMPLATE_LOG, scrollChild, nil, "Parchment")`
   with `detail.questID` set first.
   *Test: G — click a quest: title, objectives, Description and rewards render
   on parchment. Reward tooltips work and shift-click links an item.*
2. Empty state (`QuestLog-empty-quest-background`) for an empty log or no
   selection.
   *Test: G — abandon everything on a test character (or use the
   `select 0` verb) and the empty art shows.*
3. Shared-widget recovery: redisplay on OnShow and `QUEST_FINISHED`, and
   handle the contrast CVar.
   *Test: G — with the log open, talk to a quest NPC, close the dialog, and
   the log's detail is intact. Change Accessibility → Quest Text Contrast and
   the parchment swaps.*
4. Single-layout fit.
   *Test: G — in `single`, long quest text scrolls and rewards are not
   clipped.*

**Gate:** L; G both layouts.

## Stage 4 — Actions

Files: new `Actions.lua`.

1. Abandon / Share / Track / Close through `QuestMapQuestOptions_AbandonQuest`
   / `_ShareQuest` / `_TrackQuest` (`QuestMapFrame.lua:1432-1473`).
   - Enable rules: `C_QuestLog.CanAbandonQuest`; `C_QuestLog.IsPushableQuest`
     and in a group; `GetNumQuestWatches` against the cap.
   - Track text flips to `UNTRACK_QUEST_ABBREV`.
   *Test: G — abandon shows Blizzard's confirm (with the items variant when
   relevant). Share is disabled when solo. Track toggles the tracker and the
   row check.*
2. Show Map + ping, and the combat gate.
   *Test: G — the map opens on the quest's zone with a ping, and Blizzard's
   panel stays collapsed. S — `/cql test combat on` greys it out; `off`
   restores it.*
3. Modified row clicks: Shift links into an open chat box through
   `ChatFrameUtil.TryInsertQuestLinkForQuestID`; otherwise `QUESTWATCHTOGGLE`
   toggles the watch.
   *Test: G — both behaviours work.*

**Gate:** L + S; G = every button.

## Stage 5 — Blizzard takeover

Files: new `Hooks.lua`.

1. `ToggleQuestLog` replacement + micro-button pushed state +
   `SetEnabled(false)` restoring the original.
   *Test: S — `/cql test hooks` reports "ours". G — L opens our log and the
   micro button looks pushed. `/cql toggle`, then L opens Blizzard's map
   log again.*
2. Map panel collapse-once.
   *Test: S — on a fresh character, the dump shows `mapPanelCollapsed = true`
   and `questLogOpen = 0`. G — M opens the map without the side panel. Click
   the map's toggle and the panel returns; `/reload` and it still returns.*
3. Tracker routing (`GLOBAL_MOUSE_DOWN` snapshot + `OnBlockHeaderClick` and
   `QuestUtil.OpenQuestDetails` post-hooks).
   *Test: G —*
   - *a left-click on a tracked quest opens ours on that quest, with no map
     flash;*
   - *with the map already open, Blizzard's behaviour is unchanged;*
   - *the right-click "Show quest map" item (`OBJECTIVES_SHOW_QUEST_MAP`) still opens the map;*
   - *the "View in quest log" item (`OBJECTIVES_VIEW_IN_QUESTLOG`) opens ours.*
4. Combat sweep with `/console taintLog 1`.
   *Test: G — on a training dummy, L opens and closes ours and Show Map is
   disabled. A layout change is applied after combat. No
   `ADDON_ACTION_BLOCKED`, and `Logs/taint.log` has no lines naming
   ClassicQuestLog.*

**Gate:** L + S; G = the combat sweep is clean.

## Stage 6 — Settings, search, slash

Files: `Settings.lua` rebuilt, new `Search.lua`, `Core.lua` router.

1. Every setting from the table, each with its live-apply callback.
   *Test: S + G — flip each setting and the window reacts with no `/reload`.
   Defaults restores all seven.*
2. Search box: case-insensitive match on the title, collapse ignored while
   filtering, and the filter cleared when the box is hidden.
   *Test: S — `/cql test search wolf` prints a count. G — typing filters live,
   and the clear (x) restores the list and collapse state.*
3. Slash: `/cql` toggles; `/cql config`, `/cql help`, and the `/classicquestlog`
   alias.
   *Test: S — each verb works, and an unknown verb prints the help.*

**Gate:** L + S + G.

## Stage 7 — Release

1. Final README (usage, settings, screenshots), `.pkgmeta` review, final
   luacheck globals, and a tag dry run.
   *Test: L clean. Install the packaged zip by hand into a clean `AddOns`
   folder, and the addon loads with the correct title, icon and version.*

---

## Testability summary

- 28 steps. Every stage gate has an **L** check.
- 12 steps carry an **S** check the tutor can run from the repo side.
- The rest are **G** checks by design, because they test appearance or
  Blizzard interaction.
- The risky integration points are each fenced:
  - combat: the `combat` verb plus the Stage 5.4 taint sweep;
  - tracker routing: four explicit G cases;
  - the CVar: dump verified.

## Not in v1 (do not build)

- Addon Compartment entry.
- Its own keybinding (L is taken over instead).
- Window scale / font size settings.
- Dragging or moving the window.
- An "Expand/Collapse all" button.
- Side tabs or top tabs.
- An in-log quest POI map.
- Translations beyond enUS. Blizzard global strings cover most labels.

## Session commands

| To start | Say |
|---|---|
| Stage 0 | `Use @tutor on PLAN.md, Stage 0` |
| Any later stage | `Use @tutor on PLAN.md, Stage N` |
| One step again | `Re-do step M of Stage N` |
