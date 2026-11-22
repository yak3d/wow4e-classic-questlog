local _, ns = ...

-- ---------------------------------------------------------------------------
-- Dev: the /cql test <verb> registry (Stage 0).
-- Every verb is a smoke test a plan stage gate runs from the chat box.
-- ---------------------------------------------------------------------------

ns.Dev = {}

local verbs = {}

function ns.Dev.RegisterVerb(name, fn)
    verbs[name:lower()] = fn
end

function ns.Dev.Handle(input)
    local verb, rest = input:match("^(%S*)%s*(.*)")
    local fn = verb ~= "" and verbs[verb:lower()]
    if not fn then
        ns.Print(ns.L["DEV_UNKNOWN_VERB"])
        return
    end
    fn(rest)
end

-- The atlas list mirrors the plan's asset reference table. Anything reported
-- MISSING gets its fallback swapped into the plan before Stage 1 uses it.
local ATLAS_PROBES = {
    "UI-Frame-PortraitMetal-CornerTopLeft",
    "RedButton-Exit",
    "RedButton-exit-pressed",
    "RedButton-Exit-Disabled",
    "RedButton-Highlight",
    "common-button-list-collapseExpand",
    "common-button-list-plus",
    "common-button-list-minus",
    "Professions_Recipe_Active",
    "Professions_Recipe_Hover",
    "questlog-icon-checkmark-yellow",
    "common-dropdown-textholder",
    "common-searchbar-a",
    "common-searchbar-icon-a",
    "common-search-clearbutton",
    "QuestLog-empty-quest-background",
    "minimal-scrollbar-track",
    "minimal-scrollbar-small-thumb",
    "128-RedButton-Left",
    "128-RedButton-Right",
    "_128-RedButton-Center",
}

ns.Dev.RegisterVerb("dump", function()
    ns.Print("ClassicQuestLogDB:")
    for key, value in pairs(ns.db) do
        ns.Print(("  %s = %s"):format(key, tostring(value)))
    end
    ns.Print("ClassicQuestLogCharDB:")
    for key, value in pairs(ns.chardb) do
        ns.Print(("  %s = %s"):format(key, tostring(value)))
    end
    ns.Print(("layout: %s"):format(ns.Frame.GetLayoutName()))
    ns.Print(("questLogOpen: %s"):format(GetCVar("questLogOpen")))
end)

ns.Dev.RegisterVerb("atlases", function()
    local missing = 0
    for _, atlasName in ipairs(ATLAS_PROBES) do
        local info = C_Texture.GetAtlasInfo(atlasName)
        if not info then
            missing = missing + 1
        end
        ns.Print(("  %-52s %s"):format(atlasName, info and "OK" or "MISSING"))
    end
    ns.Print(ns.L["DEV_ATLAS_SUMMARY"]:format(#ATLAS_PROBES, missing))
end)

ns.Dev.RegisterVerb("list", function()
    local nodes = ns.QuestList.Build()
    local headers = 0
    local rows = 0
    for _, node in ipairs(nodes) do
        if node.isHeader then
            headers = headers + 1
            ns.Print(("[%d] %s %s"):format(node.questLogIndex, node.title,
                node.isCollapsed and "(collapsed)" or ""))
        else
            rows = rows + 1
            local tag = node.tagText and (" " .. node.tagText) or ""
            local color = node.difficultyColor and " (colored)" or ""
            local party = node.numPartyMembers > 0 and (" [%d party]"):format(node.numPartyMembers) or ""
            ns.Print(("  [%d] %s%s%s%s"):format(node.questLogIndex, node.title, tag, color, party))
        end
    end
    local current, max = ns.QuestList.GetQuestCount()
    ns.Print(("list: %d headers, %d rows, quests %d/%d"):format(headers, rows, current, max))
end)

local function ParseValue(text)
    if text == "true" then
        return true
    elseif text == "false" then
        return false
    elseif text == "nil" then
        return nil
    end
    return tonumber(text) or text
end

ns.Dev.RegisterVerb("set", function(rest)
    local key, valueText = rest:match("^(%S+)%s*(%S*)$")
    if not key then
        ns.Print(ns.L["DEV_SET_USAGE"])
        return
    end
    if ns.db[key] == nil then
        ns.Print(ns.L["DEV_UNKNOWN_KEY"]:format(key))
        return
    end
    local value = ParseValue(valueText)
    ns.db[key] = value
    ns.Settings.ApplyLive(key, value)
    ns.Print(ns.L["DEV_SET_APPLIED"]:format(key, tostring(value)))
end)

ns.Dev.RegisterVerb("layout", function(rest)
    ns.db.layout = rest
    ns.Settings.ApplyLive("layout", rest)
    ns.Print(ns.L["DEV_SET_APPLIED"]:format("layout", tostring(rest)))
end)

ns.Dev.RegisterVerb("select", function(rest)
    local questID = tonumber(rest:match("^%s*(%d+)"))
    if not questID then
        ns.Print(ns.L["DEV_SELECT_USAGE"])
        return
    end
    ns.Frame.OpenToQuest(questID)
end)

ns.Dev.RegisterVerb("combat", function(rest)
    local state = rest == "on"
    ns.Actions.SetCombatState(state)
    ns.Print(state and ns.L["DEV_COMBAT_ON"] or ns.L["DEV_COMBAT_OFF"])
end)

ns.Dev.RegisterVerb("hooks", function()
    local replaced, micro, tracker, mapWasShown = ns.Hooks.GetStatus()
    ns.Print(("ToggleQuestLog is %s"):format(replaced and "ours" or "original"))
    ns.Print(("micro button hook: %s"):format(micro and "installed" or "missing"))
    ns.Print(("tracker hooks: %s"):format(tracker and "installed" or "missing"))
    ns.Print(("mapWasShown: %s"):format(tostring(mapWasShown)))
end)

-- Live list state, for when the window shows an empty list: compares what
-- Build() would show against what the ScrollBox actually holds and draws.
ns.Dev.RegisterVerb("state", function()
    ns.Print(("ToggleQuestLog == Frame.Toggle: %s"):format(tostring(ToggleQuestLog == ns.Frame.Toggle)))
    ns.Print(("frame shown: %s"):format(tostring(ClassicQuestLogFrame and ClassicQuestLogFrame:IsShown())))
    ns.Print(("search filter: '%s'"):format(ns.Search.GetFilter()))

    local numEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
    ns.Print(("log entries: %s, quests: %s"):format(tostring(numEntries), tostring(numQuests)))

    local headers, rows = 0, 0
    for _, node in ipairs(ns.QuestList.Build()) do
        if node.isHeader then
            headers = headers + 1
        else
            rows = rows + 1
        end
    end
    ns.Print(("Build(): %d headers, %d rows"):format(headers, rows))

    local scrollBox = ClassicQuestLogFrame and ClassicQuestLogFrame.Inset.QuestList.ScrollBox
    local provider = scrollBox and scrollBox:GetDataProvider()
    ns.Print(("provider size: %s"):format(provider and tostring(provider:GetSize()) or "none"))
    if scrollBox then
        local drawn = 0
        scrollBox:ForEachFrame(function(frame)
            if frame:IsVisible() then
                drawn = drawn + 1
            end
        end)
        ns.Print(("scrollBox: %.0fx%.0f, visible %s, scroll %s, drawn frames %d"):format(
            scrollBox:GetWidth(), scrollBox:GetHeight(), tostring(scrollBox:IsVisible()),
            tostring(scrollBox:GetScrollPercentage()), drawn))
    end
end)

ns.Dev.RegisterVerb("search", function(rest)
    ns.Search.SetFilter(rest or "")
    local rows = 0
    for _, node in ipairs(ns.QuestList.Build()) do
        if not node.isHeader then
            rows = rows + 1
        end
    end
    ns.Print(("search '%s': %d matching quests"):format(rest or "", rows))
end)

-- Filter state and how each quest classifies, to check type detection.
ns.Dev.RegisterVerb("filters", function()
    ns.Print(ns.Filters.GetStateSummary())
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            local row = { isWatched = ns.QuestList.IsQuestWatched(info.questID) }
            row.difficulty = C_PlayerInfo.GetContentDifficultyQuestForPlayer(info.questID)
            local status, difficulty, types = ns.Filters.Describe(info, row)
            ns.Print(("  %s: %s, difficulty %s, types %s"):format(
                info.title, status, tostring(difficulty), types))
        end
    end
end)

-- What the Spoken Quests integration sees right now: the addon, its gates,
-- and how many quests a voice pack can read.
ns.Dev.RegisterVerb("spoken", function()
    ns.SpokenButtons.ReportStatus()
end)

-- What the details pane needs from this client: the world map's art and the
-- QuestInfo pieces it is built from. Anything MISSING falls back to the plain
-- log template or leaves a gap in the art.
local DETAILS_ATLASES = {
    "questlog-frame",
    "questlog-frame-filigree",
    "questlog-reward-top-frame",
    "questlog-reward-header-top",
    "questlog-reward-bottom",
    "questlog-reward-tile-vertical",
}

local DETAILS_GLOBALS = {
    "QUEST_TEMPLATE_MAP_DETAILS",
    "QUEST_TEMPLATE_MAP_REWARDS",
    "MapQuestInfoRewardsFrame",
    "QuestInfo_AdjustSpacerHeight",
    "QuestInfo_GetNumRewardRows",
}

ns.Dev.RegisterVerb("details", function()
    local missing = 0
    local function Report(name, ok)
        if not ok then
            missing = missing + 1
        end
        ns.Print(("  %-52s %s"):format(name, ok and "OK" or "MISSING"))
    end

    for _, atlasName in ipairs(DETAILS_ATLASES) do
        Report(atlasName, C_Texture.GetAtlasInfo(atlasName) ~= nil)
    end
    for _, name in ipairs(DETAILS_GLOBALS) do
        Report(name, _G[name] ~= nil)
    end
    local contrast = _G.QuestTextContrast
    local getAtlas = contrast and contrast.GetDefaultDetailsBackgroundAtlas
    Report("QuestTextContrast.GetDefaultDetailsBackgroundAtlas", getAtlas ~= nil)
    if getAtlas then
        local atlas = getAtlas()
        Report(("  background %s"):format(tostring(atlas)), atlas ~= nil and C_Texture.GetAtlasInfo(atlas) ~= nil)
    end

    ns.Print(ns.L["DEV_DETAILS_SUMMARY"]:format(missing))
end)
