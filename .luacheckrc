-- luacheck configuration for ClassicQuestLog (World of Warcraft addon).
-- Run with `just lint` or `luacheck ClassicQuestLog`.

std = "lua51"
max_line_length = 140
codes = true

-- Do not warn about an unused "self" argument in methods.
self = false

ignore = {
    "211/_.*", -- unused locals whose names start with an underscore
    "212/_.*", -- unused arguments whose names start with an underscore
    "542",     -- empty if branch (collapsed-header skip, locale stubs)
}

exclude_files = {
    ".release/",
}

-- Globals this addon creates or mutates.
-- The SLASH_ names are SLASH_ + the upper-cased addon name + an index.
globals = {
    "ClassicQuestLogDB",
    "ClassicQuestLogCharDB",
    "ClassicQuestLogAPI",
    "SLASH_CLASSICQUESTLOG1",
    "SLASH_CLASSICQUESTLOG2",
    "SlashCmdList",
    "UISpecialFrames",
    "UIPanelWindows",
    "ToggleQuestLog", -- the one allowed global replacement
    "ClassicQuestLogFrame",
    "ClassicQuestLogFrameMixin",
    "ClassicQuestLogHeaderMixin",
    "ClassicQuestLogQuestRowMixin",
}

-- WoW API surface this addon reads. Extend as the addon grows.
read_globals = {
    -- Lua extensions shipped with WoW
    "bit", "format", "strsplit", "strjoin", "strtrim", "tinsert", "tremove", "wipe", "tContains",
    "date", "time", "debugstack", "geterrorhandler", "hooksecurefunc", "securecall",

    -- Frames and UI
    "CreateFrame", "UIParent", "GameTooltip", "DEFAULT_CHAT_FRAME",
    "StaticPopup_Show", "StaticPopupDialogs", "Mixin", "CreateFromMixins",
    "Settings", "MinimalSliderWithSteppersMixin", "Enum", "SOUNDKIT",
    "ShowUIPanel", "HideUIPanel", "UpdateUIPanelPositions", "UIPanelCloseButtonDefaultAnchors",

    -- ScrollBox plumbing
    "CreateScrollBoxListLinearView", "CreateDataProvider", "ScrollUtil",
    "ScrollBoxConstants", "TextureKitConstants",

    -- Quest API and Camelot overrides
    "C_QuestLog", "C_PlayerInfo", "C_Texture", "C_Map",
    "GetQuestUiMapID", "OpenWorldMap", "ExpandQuestHeader", "CollapseQuestHeader",
    "GetDifficultyColor", "QuestUtilsOverrides", "QuestUtils_GetNumPartyMembersOnQuest",
    "QuestUtils_IsQuestWatched", "Constants",
    "GetNumQuestWatches", "GetNumSubgroupMembers",
    "QuestMapQuestOptions_TrackQuest", "QuestMapQuestOptions_AbandonQuest", "QuestMapQuestOptions_ShareQuest",
    "IsShiftKeyDown", "IsAltKeyDown", "IsControlKeyDown",
    "QuestInfo_Display", "QUEST_TEMPLATE_LOG", "QuestTextContrast",
    "QUEST_TEMPLATE_MAP_DETAILS", "QUEST_TEMPLATE_MAP_REWARDS", "MapQuestInfoRewardsFrame",
    "QuestInfo_AdjustSpacerHeight", "QuestInfo_GetNumRewardRows",
    "ChatFrameUtil", "EventRegistry",

    -- Blizzard frames and mixins we hook or read
    "QuestLogMicroButton", "WorldMapFrame", "QuestLogPopupDetailFrame",
    "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "QuestUtil",

    -- Blizzard global strings
    "QUEST_LOG", "ABANDON_QUEST_ABBREV", "SHARE_QUEST_ABBREV", "TRACK_QUEST_ABBREV",
    "UNTRACK_QUEST_ABBREV", "SHOW_MAP", "CLOSE", "COMPLETE", "FAILED", "CHECK_ALL", "UNCHECK_ALL",
    "MenuResponse", "GetRealZoneText",
    "QUEST_LOG_NO_QUESTS", "SEARCH", "PARENS_TEMPLATE",

    -- Named colour objects
    "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR",
    "DISABLED_FONT_COLOR", "WHITE_FONT_COLOR",

    -- API functions and namespaces
    "GetLocale", "GetTime", "GetBuildInfo", "GetRealmName", "InCombatLockdown", "IsInInstance",
    "UnitName", "UnitClass", "UnitGUID", "PlaySound", "PlaySoundFile", "GetCVar", "SetCVar",
    "C_AddOns", "C_ChatInfo", "C_CVar", "C_Item", "C_Spell", "C_Timer", "C_UnitAuras",
    "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC", "WOW_PROJECT_CAMELOT",
}
