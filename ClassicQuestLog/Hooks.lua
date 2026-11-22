local _, ns = ...

-- ---------------------------------------------------------------------------
-- Hooks: the Blizzard takeover (Stage 5). L / micro button, the map quest
-- panel collapse-once, and tracker routing.
--
-- Taint discipline: the one allowed global replacement is ToggleQuestLog;
-- everything else is a hooksecurefunc post-hook, and every panel call has an
-- InCombatLockdown fallback.
-- ---------------------------------------------------------------------------

ns.Hooks = {}

local originalToggleQuestLog
local toggleReplaced = false
local microHookInstalled = false
local trackerHooksInstalled = false
local mapWasShown = false

-- Snapshots the map state before click handlers run.
local mouseFrame = CreateFrame("Frame")
mouseFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
mouseFrame:SetScript("OnEvent", function()
    if WorldMapFrame then
        mapWasShown = WorldMapFrame:IsShown()
    else
        mapWasShown = false
    end
end)

-- ---

function ns.Hooks.SetEnabled(enabled)
    if enabled and not toggleReplaced then
        if not originalToggleQuestLog then
            originalToggleQuestLog = ToggleQuestLog
        end
        ToggleQuestLog = ns.Frame.Toggle
        toggleReplaced = true
    elseif not enabled and toggleReplaced then
        ToggleQuestLog = originalToggleQuestLog
        toggleReplaced = false
    end
end

function ns.Hooks.GetStatus()
    return toggleReplaced, microHookInstalled, trackerHooksInstalled, mapWasShown
end

-- ---

-- Tracker left-click -> our log. The guard covers the other click branches
-- too: a chat link, a watch toggle or an auto-complete popup never opens the
-- map, so those clicks fail the map-state check on their own.
local function OnBlockHeaderClickHook(_, block, mouseButton)
    if not (ns.db and ns.db.trackerOpensLog) then
        return
    end
    if mouseButton == "RightButton" or mapWasShown then
        return
    end
    if InCombatLockdown() then
        return
    end
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then
        return
    end

    local questID = block and block.id
    if not questID then
        return
    end

    HideUIPanel(WorldMapFrame)
    ns.Frame.OpenToQuest(questID)
end

-- The "View in quest log" menu item shows Blizzard's popup; route it to ours.
local function OpenQuestDetailsHook(questID)
    if InCombatLockdown() then
        return
    end
    if not (QuestLogPopupDetailFrame and QuestLogPopupDetailFrame:IsShown()) then
        return
    end

    HideUIPanel(QuestLogPopupDetailFrame)
    ns.Frame.OpenToQuest(questID)
end

-- ---

function ns.Hooks.Install()
    ns.Hooks.SetEnabled(ns.db and ns.db.enabled)

    -- The original UpdateMicroButton only checks WorldMapFrame, so our log
    -- needs this post-hook to show the pushed state.
    if QuestLogMicroButton and not microHookInstalled then
        hooksecurefunc(QuestLogMicroButton, "UpdateMicroButton", function(self)
            if ClassicQuestLogFrame and ClassicQuestLogFrame:IsShown() and self.SetPushed then
                self:SetPushed()
            end
        end)
        microHookInstalled = true
    end

    -- Collapse the map quest panel once per character, then never touch it
    -- again: the map's own side-panel toggle persists from then on.
    if ns.db and ns.db.hideMapQuestPanel and ns.chardb and not ns.chardb.mapPanelCollapsed then
        SetCVar("questLogOpen", "0")
        ns.chardb.mapPanelCollapsed = true
    end

    if not trackerHooksInstalled then
        if QuestObjectiveTracker and QuestObjectiveTracker.OnBlockHeaderClick then
            hooksecurefunc(QuestObjectiveTracker, "OnBlockHeaderClick", OnBlockHeaderClickHook)
        end
        if CampaignQuestObjectiveTracker and CampaignQuestObjectiveTracker.OnBlockHeaderClick then
            hooksecurefunc(CampaignQuestObjectiveTracker, "OnBlockHeaderClick", OnBlockHeaderClickHook)
        end
        if QuestUtil and QuestUtil.OpenQuestDetails then
            hooksecurefunc(QuestUtil, "OpenQuestDetails", OpenQuestDetailsHook)
        end
        trackerHooksInstalled = true
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        ns.Hooks.Install()
    end
end)
