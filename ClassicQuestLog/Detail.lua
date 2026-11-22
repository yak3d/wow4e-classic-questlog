local _, ns = ...

-- ---------------------------------------------------------------------------
-- Detail: the quest details pane (Stage 3), shown the way the world map shows
-- its quest details (QuestMapFrame_ShowQuestDetails). It reuses Blizzard's
-- QuestInfo twice: QUEST_TEMPLATE_MAP_DETAILS into our own ScrollChild for the
-- text, and QUEST_TEMPLATE_MAP_REWARDS into the rewards panel pinned to the
-- bottom.
--
-- QuestInfo_Display reaches the detail frame through
-- parentFrame:GetParent():GetParent(), so the chain must be
-- Detail -> ScrollFrame -> ScrollChild, and Detail.questID must be set before
-- every display.
--
-- The QuestInfo widgets and MapQuestInfoRewardsFrame are shared: the NPC
-- QuestFrame and the world map's details borrow them, so we redisplay when
-- either lets them go.
-- ---------------------------------------------------------------------------

ns.Detail = {}

local detailFrame
local eventFrame
local lastQuestID
local listening = false

local DETAIL_EVENTS = {
    "QUEST_LOG_UPDATE",
    "QUEST_FINISHED",
    "CVAR_UPDATE",
}

-- The rewards panel never collapses below this while the text scrolls, so it
-- stays clear that more rewards follow the first row (the map's value).
local REWARDS_MIN_HEIGHT = 124

-- True when this client has what the map-style display needs.
local function HasMapTemplates()
    return QUEST_TEMPLATE_MAP_DETAILS ~= nil
        and QUEST_TEMPLATE_MAP_REWARDS ~= nil
        and MapQuestInfoRewardsFrame ~= nil
        and QuestInfo_AdjustSpacerHeight ~= nil
        and QuestInfo_GetNumRewardRows ~= nil
end

-- Scales a background texture to the pane's width, keeping the atlas's
-- aspect, and crops it at the pane's height (the map's
-- AdjustBackgroundTexture, capped at our height instead of 440).
local function FitTexture(texture)
    local atlasName = texture:GetAtlas()
    if not atlasName then
        return
    end
    local atlasInfo = C_Texture.GetAtlasInfo(atlasName)
    if not atlasInfo or atlasInfo.width == 0 then
        return
    end

    local width = detailFrame:GetWidth()
    local neededHeight = atlasInfo.height * width / atlasInfo.width
    local maxHeight = detailFrame:GetHeight()
    texture:SetWidth(width)
    if maxHeight > 0 and neededHeight > maxHeight then
        texture:SetTexCoord(0, 1, 0, maxHeight / neededHeight)
        texture:SetHeight(maxHeight)
    else
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetHeight(neededHeight)
    end
end

local function UpdateBackground()
    local atlas = QuestTextContrast and QuestTextContrast.GetDefaultDetailsBackgroundAtlas
        and QuestTextContrast.GetDefaultDetailsBackgroundAtlas()
    if atlas then
        detailFrame.Bg:SetAtlas(atlas)
        FitTexture(detailFrame.Bg)
    end
end

-- The map's details template, widened by however much wider our pane is than
-- the map's, and narrowed so the scrollbar fits inside the pane to its right
-- (the map keeps its scrollbar outside).
local SCROLLBAR_ROOM = 14
local detailsTemplate
local function GetDetailsTemplate()
    if not detailsTemplate then
        detailsTemplate = {}
        for key, value in pairs(QUEST_TEMPLATE_MAP_DETAILS) do
            detailsTemplate[key] = value
        end
        local extraWidth = ns.Frame.DETAIL_WIDTH - ns.Frame.MAP_DETAIL_WIDTH
        detailsTemplate.contentWidth = QUEST_TEMPLATE_MAP_DETAILS.contentWidth + extraWidth - SCROLLBAR_ROOM
    end
    return detailsTemplate
end

-- The scrollbar runs down the pane's right edge, from under the header strip
-- to just above the rewards panel, so it follows the panel as it shrinks and
-- never sits under it. With no panel it runs to the text's bottom.
local function AnchorScrollBar(withRewards)
    local bar = detailFrame.ScrollFrame.ScrollBar
    if not bar then
        return
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", detailFrame, "TOPRIGHT", -8, -48)
    if withRewards then
        bar:SetPoint("BOTTOMRIGHT", detailFrame.RewardsFrameContainer, "TOPRIGHT", -7, 4)
    else
        bar:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -8, 33)
    end
end

-- Resizes the rewards panel and tells listeners when its height really changed
-- (it follows the scroll, so this runs on every scroll step).
local function SetContainerHeight(container, height)
    local changed = math.abs(container:GetHeight() - height) > 0.01
    container:SetHeight(height)
    if changed then
        ns.API.Fire("DetailLayout")
    end
end

-- Shrinks the rewards panel while there is text left to scroll past it, and
-- grows it back as the text reaches the end (the map's
-- AdjustRewardsFrameContainer). isFixedHeight is nil until the first call
-- after a display decides it.
local function AdjustRewardsFrameContainer()
    local container = detailFrame.RewardsFrameContainer
    if container.isFixedHeight or not container:IsShown() then
        return
    end

    local scroll = detailFrame.ScrollFrame
    local scrollRange = scroll:GetVerticalScrollRange()
    local rewardsHeight = container.RewardsFrame:GetHeight()

    if container.isFixedHeight == nil then
        container.isFixedHeight = scrollRange == 0 or QuestInfo_GetNumRewardRows() <= 1
        if container.isFixedHeight then
            SetContainerHeight(container, rewardsHeight)
            return
        end
    end

    local pixelsToHide = scrollRange - scroll:GetVerticalScroll()
    SetContainerHeight(container, math.max(rewardsHeight - pixelsToHide, REWARDS_MIN_HEIGHT))
end

-- The map's SetRewardsHeight: the text's closing spacer matches the panel, so
-- the text can scroll clear of it.
local function SetRewardsHeight(height)
    local container = detailFrame.RewardsFrameContainer
    container.isFixedHeight = nil
    container.RewardsFrame:SetHeight(height)
    QuestInfo_AdjustSpacerHeight(height)
    container.RewardsFrame.Label:SetShown(QuestInfo_GetNumRewardRows() > 0)
    detailFrame.ScrollFrame:UpdateScrollChildRect()
    AdjustRewardsFrameContainer()
end

local function ShowEmpty()
    detailFrame.questID = nil
    detailFrame.Empty:Show()
    detailFrame.EmptyText:Show()
    detailFrame.ScrollFrame:Hide()
    detailFrame.RewardsFrameContainer:Hide()
    detailFrame.SealMaterialBG:Hide()
    ns.SpokenButtons.UpdateDetail(nil)
    ns.API.Fire("DetailShown", nil)
end

local function HideEmpty()
    detailFrame.Empty:Hide()
    detailFrame.EmptyText:Hide()
    detailFrame.ScrollFrame:Show()
end

function ns.Detail.Show(questID)
    if not detailFrame then
        return
    end

    if not questID or questID == 0 then
        ShowEmpty()
        return
    end

    HideEmpty()

    if lastQuestID ~= questID then
        detailFrame.ScrollFrame:SetVerticalScroll(0)
    end
    lastQuestID = questID

    detailFrame.questID = questID

    -- Read before every display: it follows the Quest Text Contrast option.
    UpdateBackground()

    local scrollChild = detailFrame.ScrollFrame.ScrollChild
    local withRewards = HasMapTemplates()
    AnchorScrollBar(withRewards)
    if withRewards then
        detailFrame.RewardsFrameContainer:Show()
        QuestInfo_Display(GetDetailsTemplate(), scrollChild)
        QuestInfo_Display(QUEST_TEMPLATE_MAP_REWARDS, detailFrame.RewardsFrameContainer.RewardsFrame,
            nil, nil, true)
        FitTexture(detailFrame.SealMaterialBG)

        -- The map's heights: the rewards plus the panel's header and cap, or
        -- the cap alone when there are none.
        local height
        if MapQuestInfoRewardsFrame:IsShown() then
            height = MapQuestInfoRewardsFrame:GetHeight() + 62
        else
            height = 59
        end
        SetRewardsHeight(height)
    else
        -- Without the map templates the rewards stay in the text.
        detailFrame.RewardsFrameContainer:Hide()
        QuestInfo_Display(QUEST_TEMPLATE_LOG, scrollChild)
        FitTexture(detailFrame.SealMaterialBG)
    end

    -- Spoken Quests' round Play / Report / Contribute strip on the header; a
    -- no-op without the addon.
    ns.SpokenButtons.UpdateDetail(questID)

    ns.API.Fire("DetailShown", questID)
end

function ns.Detail.RefreshSelected()
    if not detailFrame then
        return
    end
    local questID = C_QuestLog.GetSelectedQuest()
    if questID and questID ~= 0 then
        ns.Detail.Show(questID)
    else
        ShowEmpty()
    end
end

-- The world map's quest details take the shared QuestInfo widgets and
-- MapQuestInfoRewardsFrame; take them back once the map closes.
local function WatchWorldMap()
    if not WorldMapFrame then
        return false
    end
    WorldMapFrame:HookScript("OnHide", function()
        if detailFrame:IsVisible() then
            ns.Detail.RefreshSelected()
        end
    end)
    return true
end

function ns.Detail.Init(frame)
    detailFrame = frame
    ns.SpokenButtons.Init(frame)

    local scroll = frame.ScrollFrame
    scroll:SetScrollChild(scroll.ScrollChild)
    scroll:HookScript("OnVerticalScroll", function()
        if detailFrame.questID then
            AdjustRewardsFrameContainer()
        end
    end)
    scroll:HookScript("OnScrollRangeChanged", function()
        if detailFrame.questID then
            AdjustRewardsFrameContainer()
        end
    end)

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_LOG_UPDATE" or event == "QUEST_FINISHED" then
            -- QUEST_FINISHED means the NPC QuestFrame borrowed the QuestInfo
            -- widgets; redisplay to get them back.
            ns.Detail.RefreshSelected()
        elseif event == "CVAR_UPDATE" then
            local first, second = ...
            if first == "QuestTextContrast" or second == "QuestTextContrast" then
                ns.Detail.RefreshSelected()
            end
        elseif event == "ADDON_LOADED" and ... == "Blizzard_WorldMap" then
            eventFrame:UnregisterEvent("ADDON_LOADED")
            WatchWorldMap()
        end
    end)
    if not WatchWorldMap() then
        eventFrame:RegisterEvent("ADDON_LOADED")
    end

    -- Start on the empty state until a quest is selected.
    ns.Detail.RefreshSelected()
end

-- Events are registered only while the window is shown.
function ns.Detail.SetListening(shown)
    if not eventFrame or listening == shown then
        return
    end
    listening = shown
    for _, event in ipairs(DETAIL_EVENTS) do
        if shown then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:UnregisterEvent(event)
        end
    end
end
