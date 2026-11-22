local _, ns = ...

-- ---------------------------------------------------------------------------
-- Actions: Abandon / Share / Track / Close, Show Map, and modified row clicks
-- (Stage 4). Buttons and the Show Map icon live on the frame; the combat gate
-- disables everything that touches secure state.
-- ---------------------------------------------------------------------------

ns.Actions = {}

local frame
local combatSimulated = false
local eventFrame

local function IsCombat()
    return combatSimulated or InCombatLockdown()
end

local function GetSelectedQuestID()
    local questID = C_QuestLog.GetSelectedQuest()
    if questID and questID ~= 0 then
        return questID
    end
    return nil
end

local function GetWatchCount()
    return C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or 0
end

local function GetWatchCap()
    local constants = (type(Constants) == "table" and Constants.QuestWatchConsts)
        or (type(Enum) == "table" and Enum.QuestWatchConsts)
    if constants and constants.MAX_QUEST_WATCHES then
        return constants.MAX_QUEST_WATCHES
    end
    return 25
end

-- Blizzard's TrackQuest plays its own error at the cap and checks
-- QuestUtil.CanRemoveQuestWatch, so prefer it and fall back to the C API.
local function ToggleWatch(questID)
    if QuestMapQuestOptions_TrackQuest then
        QuestMapQuestOptions_TrackQuest(questID)
        return
    end
    if ns.QuestList.IsQuestWatched(questID) then
        C_QuestLog.RemoveQuestWatch(questID)
    else
        C_QuestLog.AddQuestWatch(questID)
    end
end

function ns.Actions.UpdateButtons()
    if not frame then
        return
    end

    local questID = GetSelectedQuestID()
    local combat = IsCombat()

    local canAbandon = questID ~= nil and C_QuestLog.CanAbandonQuest(questID)
    frame.Detail.AbandonButton:SetEnabled(not combat and canAbandon)

    local inGroup = (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) > 0
    local canShare = questID ~= nil and C_QuestLog.IsPushableQuest(questID) and inGroup
    frame.Detail.ShareButton:SetEnabled(not combat and canShare)

    local watched = ns.QuestList.IsQuestWatched(questID)
    local canTrack = questID ~= nil and (watched or GetWatchCount() < GetWatchCap())
    frame.Detail.TrackButton:SetEnabled(not combat and canTrack)
    frame.Detail.TrackButton:SetText(watched and UNTRACK_QUEST_ABBREV or TRACK_QUEST_ABBREV)

    frame.ShowMapButton:SetEnabled(not combat and questID ~= nil)
end

-- --- Button actions --------------------------------------------------------

function ns.Actions.AbandonQuest()
    if IsCombat() then
        return
    end
    local questID = GetSelectedQuestID()
    if questID and C_QuestLog.CanAbandonQuest(questID) and QuestMapQuestOptions_AbandonQuest then
        -- Shows Blizzard's confirm popup, with the items variant when relevant.
        QuestMapQuestOptions_AbandonQuest(questID)
    end
end

function ns.Actions.ShareQuest()
    if IsCombat() then
        return
    end
    local questID = GetSelectedQuestID()
    local inGroup = (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) > 0
    if questID and C_QuestLog.IsPushableQuest(questID) and inGroup and QuestMapQuestOptions_ShareQuest then
        QuestMapQuestOptions_ShareQuest(questID)
    end
end

function ns.Actions.TrackQuest()
    if IsCombat() then
        return
    end
    local questID = GetSelectedQuestID()
    if not questID then
        return
    end
    if ns.QuestList.IsQuestWatched(questID) then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
    ToggleWatch(questID)
end

function ns.Actions.ShowMap()
    if IsCombat() then
        return
    end
    local questID = GetSelectedQuestID()
    if not questID then
        return
    end

    local mapID = GetQuestUiMapID and GetQuestUiMapID(questID, true)
    if not mapID or mapID == 0 then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    if mapID and mapID ~= 0 then
        OpenWorldMap(mapID)
        EventRegistry:TriggerEvent("MapCanvas.PingQuestID", questID)
    end
end

-- --- Row clicks ------------------------------------------------------------

-- Plain click selects the quest (Stage 2.5); shift-click links into an open
-- chat box; alt/ctrl-click toggles the watch like QUESTWATCHTOGGLE.
function ns.Actions.RowClicked(node, mouseButton)
    if not node or not node.questID or mouseButton ~= "LeftButton" then
        return
    end

    if IsShiftKeyDown() then
        if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID then
            ChatFrameUtil.TryInsertQuestLinkForQuestID(node.questID)
        end
        return
    end

    if IsAltKeyDown() or IsControlKeyDown() then
        if not IsCombat() then
            if ns.QuestList.IsQuestWatched(node.questID) then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            else
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            ToggleWatch(node.questID)
        end
        return
    end

    ns.QuestList.SelectQuest(node.questID)
end

-- --- Frame wiring ----------------------------------------------------------

function ns.Actions.Init(f)
    frame = f

    f.Detail.AbandonButton:SetText(ABANDON_QUEST_ABBREV)
    f.Detail.ShareButton:SetText(SHARE_QUEST_ABBREV)
    f.Detail.TrackButton:SetText(TRACK_QUEST_ABBREV)
    f.ShowMapButton:SetText(SHOW_MAP)

    f.Detail.AbandonButton:SetScript("OnClick", function()
        ns.Actions.AbandonQuest()
    end)
    f.Detail.ShareButton:SetScript("OnClick", function()
        ns.Actions.ShareQuest()
    end)
    f.Detail.TrackButton:SetScript("OnClick", function()
        ns.Actions.TrackQuest()
    end)
    f.ShowMapButton:SetScript("OnClick", function()
        ns.Actions.ShowMap()
    end)

    eventFrame = CreateFrame("Frame")
    -- Combat state drives the button gate; the other two drive the enable
    -- rules and are only registered while the window is shown.
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        ns.Actions.UpdateButtons()
    end)
end

function ns.Actions.OnFrameShown()
    eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    ns.Actions.UpdateButtons()
end

function ns.Actions.OnFrameHidden()
    eventFrame:UnregisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

-- Driven by /cql test combat on|off; simulates the gate without real lockdown.
function ns.Actions.SetCombatState(enabled)
    combatSimulated = enabled and true or false
    ns.Actions.UpdateButtons()
end
