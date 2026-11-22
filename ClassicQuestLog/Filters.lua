local _, ns = ...

-- ---------------------------------------------------------------------------
-- Filters: the list filter dropdown. State is saved per character; every
-- quest must pass all active rules to stay in the list. The submenu sets hold
-- the keys the player has UNticked, so an empty set means "show everything".
-- ---------------------------------------------------------------------------

ns.Filters = {}

local TOGGLES = {
    { key = "currentZone", text = "FILTER_CURRENT_ZONE" },
    { key = "hideGrey", text = "FILTER_HIDE_GREY" },
    { key = "trackedOnly", text = "FILTER_TRACKED_ONLY" },
    { key = "partyOnly", text = "FILTER_PARTY_ONLY" },
}

local STATUSES = {
    { key = "inProgress", text = "FILTER_IN_PROGRESS" },
    { key = "complete", text = "FILTER_COMPLETE" },
    { key = "failed", text = "FILTER_FAILED" },
}

-- Ordered like the game's colours, hardest first. Grey (trivial) is handled
-- by the "Hide grey quests" toggle, so it has no entry here.
local DIFFICULTIES = {
    { key = "impossible", text = "FILTER_DIFF_RED", value = 4 },
    { key = "difficult", text = "FILTER_DIFF_ORANGE", value = 3 },
    { key = "fair", text = "FILTER_DIFF_YELLOW", value = 2 },
    { key = "easy", text = "FILTER_DIFF_GREEN", value = 1 },
}
local DIFFICULTY_KEY = {}
for _, entry in ipairs(DIFFICULTIES) do
    DIFFICULTY_KEY[entry.value] = entry.key
end
local TRIVIAL = 0

local TYPES = {
    { key = "normal", text = "FILTER_TYPE_NORMAL" },
    { key = "elite", text = "FILTER_TYPE_ELITE" },
    { key = "dungeon", text = "FILTER_TYPE_DUNGEON" },
    { key = "raid", text = "FILTER_TYPE_RAID" },
    { key = "pvp", text = "FILTER_TYPE_PVP" },
    { key = "daily", text = "FILTER_TYPE_DAILY" },
    { key = "weekly", text = "FILTER_TYPE_WEEKLY" },
    { key = "story", text = "FILTER_TYPE_STORY" },
}

-- Quest tag ids, from Enum.QuestTag when this build has it.
local TAG = {
    group = Enum and Enum.QuestTag and Enum.QuestTag.Group or 1,
    pvp = Enum and Enum.QuestTag and Enum.QuestTag.PvP or 41,
    raid = Enum and Enum.QuestTag and Enum.QuestTag.Raid or 62,
    dungeon = Enum and Enum.QuestTag and Enum.QuestTag.Dungeon or 81,
    raid10 = Enum and Enum.QuestTag and Enum.QuestTag.Raid10 or 88,
    raid25 = Enum and Enum.QuestTag and Enum.QuestTag.Raid25 or 89,
}
local FREQUENCY_DAILY = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily or 1
local FREQUENCY_WEEKLY = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly or 2

-- --- State -----------------------------------------------------------------

local function NewState()
    return {
        currentZone = false,
        hideGrey = false,
        trackedOnly = false,
        partyOnly = false,
        hiddenStatus = {},
        hiddenDifficulty = {},
        hiddenTypes = {},
    }
end

-- Used until the character DB exists (the frame loads before ADDON_LOADED).
local fallbackState = NewState()

local function GetState()
    return ns.chardb and ns.chardb.filters or fallbackState
end

function ns.Filters.IsDefault()
    local state = GetState()
    for _, toggle in ipairs(TOGGLES) do
        if state[toggle.key] then
            return false
        end
    end
    return next(state.hiddenStatus) == nil
        and next(state.hiddenDifficulty) == nil
        and next(state.hiddenTypes) == nil
end

function ns.Filters.Reset()
    local state = GetState()
    for _, toggle in ipairs(TOGGLES) do
        state[toggle.key] = false
    end
    wipe(state.hiddenStatus)
    wipe(state.hiddenDifficulty)
    wipe(state.hiddenTypes)
end

-- --- Quest classification --------------------------------------------------

local function GetStatus(questID)
    if C_QuestLog.IsFailed and C_QuestLog.IsFailed(questID) then
        return "failed"
    elseif C_QuestLog.IsComplete(questID) then
        return "complete"
    end
    return "inProgress"
end

-- A quest can have several types; returns a set of type keys.
local function GetTypes(info)
    local types = {}

    local tagInfo = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(info.questID)
    local tagID = tagInfo and tagInfo.tagID
    if tagID == TAG.dungeon then
        types.dungeon = true
    elseif tagID == TAG.raid or tagID == TAG.raid10 or tagID == TAG.raid25 then
        types.raid = true
    elseif tagID == TAG.pvp then
        types.pvp = true
    end
    if tagID == TAG.group or (tagInfo and tagInfo.isElite) or (info.suggestedGroup or 0) > 0 then
        types.elite = true
    end

    if info.frequency == FREQUENCY_DAILY then
        types.daily = true
    elseif info.frequency == FREQUENCY_WEEKLY then
        types.weekly = true
    end
    if info.isStory or info.campaignID then
        types.story = true
    end

    if next(types) == nil then
        types.normal = true
    end
    return types
end

-- Whether a quest row stays in the list. headerTitle is the zone header the
-- quest sits under (nil for a headerless quest); row comes from MakeRow.
function ns.Filters.Passes(info, headerTitle, row)
    local state = GetState()

    if state.currentZone and headerTitle ~= GetRealZoneText() then
        return false
    end
    if state.trackedOnly and not row.isWatched then
        return false
    end
    if state.partyOnly and (row.numPartyMembers or 0) == 0 then
        return false
    end

    local difficulty = row.difficulty
    if difficulty == TRIVIAL then
        if state.hideGrey then
            return false
        end
    elseif difficulty and state.hiddenDifficulty[DIFFICULTY_KEY[difficulty]] then
        return false
    end

    if next(state.hiddenStatus) and state.hiddenStatus[GetStatus(info.questID)] then
        return false
    end

    if next(state.hiddenTypes) then
        local shown = false
        for key in pairs(GetTypes(info)) do
            if not state.hiddenTypes[key] then
                shown = true
                break
            end
        end
        if not shown then
            return false
        end
    end

    return true
end

-- Dev helper: the classification of one quest, as printed by /cql test filters.
function ns.Filters.Describe(info, row)
    local keys = {}
    for key in pairs(GetTypes(info)) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return GetStatus(info.questID), row.difficulty, table.concat(keys, ",")
end

function ns.Filters.GetStateSummary()
    local state = GetState()
    local parts = {}
    for _, toggle in ipairs(TOGGLES) do
        parts[#parts + 1] = ("%s=%s"):format(toggle.key, tostring(state[toggle.key]))
    end
    for _, name in ipairs({ "hiddenStatus", "hiddenDifficulty", "hiddenTypes" }) do
        local keys = {}
        for key in pairs(state[name]) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        parts[#parts + 1] = ("%s={%s}"):format(name, table.concat(keys, ","))
    end
    return table.concat(parts, " ")
end

-- --- Menu ------------------------------------------------------------------

local function Refresh()
    ns.QuestList.Refresh(true)
end

local function CreateToggle(root, toggle)
    root:CreateCheckbox(ns.L[toggle.text],
        function() return GetState()[toggle.key] end,
        function() GetState()[toggle.key] = not GetState()[toggle.key] end)
end

-- A submenu of checkboxes backed by a "hidden" set, with Check all / Uncheck
-- all. entries is a list of { key, label } already filtered to what to show.
local function CreateSetSubmenu(root, title, setName, entries)
    local submenu = root:CreateButton(title)

    submenu:CreateButton(CHECK_ALL, function()
        wipe(GetState()[setName])
        return MenuResponse.Refresh
    end)
    submenu:CreateButton(UNCHECK_ALL, function()
        local hidden = GetState()[setName]
        for _, entry in ipairs(entries) do
            hidden[entry.key] = true
        end
        return MenuResponse.Refresh
    end)

    for _, entry in ipairs(entries) do
        submenu:CreateCheckbox(entry.label,
            function() return not GetState()[setName][entry.key] end,
            function()
                local hidden = GetState()[setName]
                hidden[entry.key] = not hidden[entry.key] or nil
            end)
    end
end

local function ColouredLabel(text, difficulty)
    if GetDifficultyColor then
        local ok, color = pcall(GetDifficultyColor, difficulty)
        if ok and color and color.WrapTextInColorCode then
            return color:WrapTextInColorCode(text)
        end
    end
    return text
end

-- Only the types some quest in the log has, in the fixed display order.
local function GetPresentTypes()
    local present = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isTask and not info.isHidden then
            for key in pairs(GetTypes(info)) do
                present[key] = true
            end
        end
    end

    local entries = {}
    for _, entry in ipairs(TYPES) do
        if present[entry.key] then
            entries[#entries + 1] = { key = entry.key, label = ns.L[entry.text] }
        end
    end
    return entries
end

local function SetupMenu(_, root)
    for _, toggle in ipairs(TOGGLES) do
        CreateToggle(root, toggle)
    end

    root:CreateDivider()

    local statuses = {}
    for _, entry in ipairs(STATUSES) do
        statuses[#statuses + 1] = { key = entry.key, label = ns.L[entry.text] }
    end
    CreateSetSubmenu(root, ns.L["FILTER_STATUS"], "hiddenStatus", statuses)

    local difficulties = {}
    for _, entry in ipairs(DIFFICULTIES) do
        difficulties[#difficulties + 1] = {
            key = entry.key,
            label = ColouredLabel(ns.L[entry.text], entry.value),
        }
    end
    CreateSetSubmenu(root, ns.L["FILTER_DIFFICULTY"], "hiddenDifficulty", difficulties)

    CreateSetSubmenu(root, ns.L["FILTER_TYPE"], "hiddenTypes", GetPresentTypes())
end

function ns.Filters.Init(dropdown)
    dropdown:SetDefaultCallback(function()
        ns.Filters.Reset()
        Refresh()
    end)
    dropdown:SetIsDefaultCallback(ns.Filters.IsDefault)
    dropdown:SetUpdateCallback(Refresh)
    dropdown:SetupMenu(SetupMenu)
end
