local _, ns = ...

-- ---------------------------------------------------------------------------
-- Localization
-- ---------------------------------------------------------------------------
-- Missing keys fall back to the key itself, so a forgotten translation shows
-- the key instead of erroring. Keys are prefixed per module: FRAME_, LIST_,
-- DETAIL_, ACTION_, SEARCH_, FILTER_, HOOK_, SETTING_, HELP_, DEV_.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- ---------------------------------------------------------------------------
-- enUS (default)
-- ---------------------------------------------------------------------------
L["TITLE"] = "Classic Quest Log"
L["LOADED"] = "Loaded. Press L or type /cql."
L["ENABLED"] = "Enabled."
L["DISABLED"] = "Disabled."
L["UNKNOWN_COMMAND"] = "Unknown command: %s"

-- Frame
L["FRAME_COUNT"] = "Quests: %d/%d"

-- QuestList
L["LIST_PARTY_TOOLTIP"] = "Party members on this quest:"

-- Filter dropdown
L["FILTER_CURRENT_ZONE"] = "Current zone only"
L["FILTER_HIDE_GREY"] = "Hide grey quests"
L["FILTER_TRACKED_ONLY"] = "Tracked only"
L["FILTER_PARTY_ONLY"] = "Shared with party only"
L["FILTER_STATUS"] = "Status"
L["FILTER_IN_PROGRESS"] = "In progress"
L["FILTER_COMPLETE"] = COMPLETE or "Complete"
L["FILTER_FAILED"] = FAILED or "Failed"
L["FILTER_DIFFICULTY"] = "Difficulty"
L["FILTER_DIFF_RED"] = "Red"
L["FILTER_DIFF_ORANGE"] = "Orange"
L["FILTER_DIFF_YELLOW"] = "Yellow"
L["FILTER_DIFF_GREEN"] = "Green"
L["FILTER_TYPE"] = "Type"
L["FILTER_TYPE_NORMAL"] = "Normal"
L["FILTER_TYPE_ELITE"] = "Elite / Group"
L["FILTER_TYPE_DUNGEON"] = "Dungeon"
L["FILTER_TYPE_RAID"] = "Raid"
L["FILTER_TYPE_PVP"] = "PvP"
L["FILTER_TYPE_DAILY"] = "Daily"
L["FILTER_TYPE_WEEKLY"] = "Weekly"
L["FILTER_TYPE_STORY"] = "Story"
L["FILTER_NO_MATCH"] = "No quests match the current filters."

-- Slash command help
L["HELP_HEADER"] = "Classic Quest Log commands:"
L["HELP_CONFIG"] = "  /cql config - Open the settings panel"
L["HELP_TOGGLE"] = "  /cql toggle - Enable or disable the L takeover"
L["HELP_TEST"] = "  /cql test <verb> - Developer tools: dump, atlases, list, set, layout, select,"
    .. " combat, hooks, state, search, filters, spoken"

-- Settings
L["SETTING_ENABLED"] = "Replace the quest log (L key)"
L["SETTING_ENABLED_TT"] = "L and the quest log micro button open the Classic Quest Log."
L["SETTING_LAYOUT"] = "Layout"
L["SETTING_LAYOUT_TT"] = "Double pane: list on the left, parchment on the right. Single pane: list on top, parchment below."
L["SETTING_LAYOUT_DOUBLE"] = "Double pane"
L["SETTING_LAYOUT_SINGLE"] = "Single pane"
L["SETTING_SHOW_LEVEL"] = "Show quest levels"
L["SETTING_SHOW_LEVEL_TT"] = "Prefix each quest title with its level, like [12]."
L["SETTING_DIFFICULTY_COLOR"] = "Colour quests by difficulty"
L["SETTING_DIFFICULTY_COLOR_TT"] = "Colour quest titles red, orange, green or grey."
L["SETTING_SHOW_SEARCH"] = "Show search box"
L["SETTING_SHOW_SEARCH_TT"] = "Filter the quest list by title."
L["SETTING_HIDE_MAP_QUEST_PANEL"] = "Hide the quest panel in the World Map"
L["SETTING_HIDE_MAP_QUEST_PANEL_TT"] = "Collapsed once per character; the map's own toggle brings it back."
L["SETTING_TRACKER_OPENS_LOG"] = "Objective tracker clicks open this log"
L["SETTING_TRACKER_OPENS_LOG_TT"] = "Left-clicking a quest in the objective tracker opens this log."

-- Hooks
L["HOOK_TOGGLED_ON"] = "L now opens the Classic Quest Log."
L["HOOK_TOGGLED_OFF"] = "L now opens the Blizzard quest log."

-- Dev verbs
L["DEV_UNKNOWN_VERB"] = "test: unknown verb. Try dump, atlases, list, set, layout, select, combat, hooks, state,"
    .. " search, filters, spoken, details."
L["DEV_SET_USAGE"] = "set: usage /cql test set <key> <value>"
L["DEV_UNKNOWN_KEY"] = "set: unknown setting key: %s"
L["DEV_SET_APPLIED"] = "set: %s = %s"
L["DEV_ATLAS_SUMMARY"] = "atlases: %d probed, %d missing"
L["DEV_DETAILS_SUMMARY"] = "details: %d missing"
L["DEV_SELECT_USAGE"] = "select: usage /cql test select <questID>"
L["DEV_COMBAT_ON"] = "combat gate: ON (simulated)"
L["DEV_COMBAT_OFF"] = "combat gate: OFF"

-- ---------------------------------------------------------------------------
-- Other locales
-- ---------------------------------------------------------------------------
-- Override only the keys that differ from enUS.
local locale = GetLocale()
if locale == "deDE" then
    -- L["ENABLED"] = "Aktiviert."
elseif locale == "frFR" then
    -- L["ENABLED"] = "Activé."
end
