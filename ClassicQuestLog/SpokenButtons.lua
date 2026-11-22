local _, ns = ...

-- ---------------------------------------------------------------------------
-- SpokenButtons: Spoken Quests' Play buttons in the list rows and the round
-- Play / Report / Contribute strip on the detail pane, the same buttons the
-- built-in quest log shows. Spoken Quests deliberately exposes its internals
-- through the global VoiceOver table (its sound packs call in through it),
-- and the Spoken core offers Spoken:CreateRoundButton and
-- Spoken:DressBoxButton, so this module only wires their helpers onto our
-- frames: no copied art, no copied play/stop/queue behaviour.
--
-- The addon is entirely optional. Every lookup goes through _G at call time,
-- so load order never matters, and without Spoken Quests nothing here runs:
-- the buttons stay hidden and the rows keep their plain layout.
-- ---------------------------------------------------------------------------

ns.SpokenButtons = {}

-- The row's Play button, and the room it takes from the title. The built-in
-- log puts the button before the title too.
local PLAY_SIZE = 16
local PLUS_SIZE = 18

-- Left offsets of the row's pieces, without and with the button's room:
-- the watched check, the party-mates count, the title.
local PLAIN = { check = 6, mates = 22, title = 24 }
local PADDED = { check = 22, mates = 38, title = 40 }

local detailFrame
local strip -- { play, report, contribute } once created
local callbacksRegistered = false
local RegisterCallbacks -- defined below; called from DressRow and UpdateDetail

-- --- Spoken lookups --------------------------------------------------------

-- The Spoken Quests environment, or nil without it: the shared VoiceOver
-- table every one of its parts lives in.
local function Parts()
    local env = _G.VoiceOver
    if not (env and env.QuestOverlayUI and env.DataModules and env.Addon and env.Enums) then
        return nil
    end
    return env
end

-- A failing integration must never blank the list or the detail pane, so
-- every Spoken entry point runs through here (the QuestList does the same for
-- the detail pane: fill the list first, then risk the rest).
local function Safe(fn, fallback)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return fallback
end

-- Spoken's own gates for the quest log's buttons: its Quests part is on and
-- its "Play buttons in the quest log" setting is on.
local function RowsShown(env)
    return Safe(function() return env.QuestOverlayUI:ShowsQuestLogButtons() end, false)
end

-- --- List rows -------------------------------------------------------------

-- Sets the row's pieces to their left offsets with or without the button's
-- room. The Tag keeps its own anchor in both layouts.
local function LayoutRow(row, padded)
    local offsets = padded and PADDED or PLAIN
    row.Check:ClearAllPoints()
    row.Check:SetPoint("LEFT", offsets.check, 0)
    row.GroupMates:ClearAllPoints()
    row.GroupMates:SetPoint("LEFT", offsets.mates, 0)
    row.Title:ClearAllPoints()
    row.Title:SetPoint("LEFT", offsets.title, 0)
    row.Title:SetPoint("RIGHT", -60, 0)
end

-- Dresses the row's Play button once (Spoken's box style, the same look the
-- built-in log's rows have) and binds it to the quest the row now shows. One
-- button per pooled row, rebound on Init: the pattern Spoken's own tracker
-- adapter uses, so it never fights the built-in log's per-quest buttons over
-- a frame's parent.
local function DressPlay(row, questID, title, env)
    local play = row.PlayButton
    if not play.spokenDressed then
        play:SetSize(PLAY_SIZE, PLAY_SIZE)
        play.spokenDressed = true
        local spoken = _G.Spoken
        if spoken and spoken.DressBoxButton then
            Safe(function()
                spoken:DressBoxButton(play) -- checkbox border, Play glyph, SetState
                play.setPlayState = env.QuestOverlayUI.FollowQueue
                play:SetBox(nil, PLAY_SIZE, PLAY_SIZE)
            end)
        else
            -- Older Spoken without the core's dressing: the classic glyph.
            play:SetNormalTexture("Interface\\AddOns\\Spoken_Quests\\Textures\\QuestLogPlayButton")
        end
    end
    if play.spokenQuestID ~= questID then
        play.spokenQuestID = questID
        play.soundData = nil
        Safe(function()
            env.QuestOverlayUI:BindPlayButton(play, questID, title,
                "the Classic Quest Log's Play button")
        end)
    end
    play:Enable()
    Safe(function() env.QuestOverlayUI:SetPlayButtonState(play) end)
end

-- The Contribute button where Play would be, for a quest no pack voices yet:
-- the client's own plus icon, Spoken's contribute flow and tooltip, and its
-- right-click menu.
local function DressPlus(row, questID, title, env)
    local contribute = env.Contribute
    if not contribute then
        return false
    end
    local button = row.ContributeButton
    if not button.spokenDressed then
        button:SetSize(PLUS_SIZE, PLUS_SIZE)
        button:SetHitRectInsets(1, 1, 1, 1)
        button:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        button.spokenDressed = true
    end
    button:SetScript("OnClick", function()
        Safe(function() contribute:ShowFromLog(questID, title) end)
    end)
    button:SetScript("OnEnter", function(self)
        Safe(function() contribute:ShowTooltip(self) end)
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Safe(function() contribute:OfferLogMenu(button) end)
    return true
end

-- Called from the row mixin's Init on every list refresh: lays the row out
-- around the button's room and binds Play / Contribute / greyed-out Play to
-- the quest the row now shows.
function ns.SpokenButtons.DressRow(row, node)
    local env = Parts()
    local shown = env and RowsShown(env)
    LayoutRow(row, shown)

    local questID = node and node.questID
    if not shown or not questID then
        row.PlayButton:Hide()
        row.ContributeButton:Hide()
        return
    end
    Safe(function() RegisterCallbacks(env) end)

    -- The sound data is keyed by the title the client reports, without the
    -- level prefix the row shows in front of it.
    local title = Safe(function() return C_QuestLog.GetTitleForQuestID(questID) end, nil)
        or node.title or ""

    local hasVoice = Safe(function()
        return env.DataModules:PrepareSound(
            { event = env.Enums.SoundEvent.QuestAccept, questID = questID }) and true or false
    end, false)

    if hasVoice then
        row.ContributeButton:Hide()
        DressPlay(row, questID, title, env)
        row.PlayButton:Show()
        return
    end
    -- No voice: Contribute where Play would be, or Play greyed out.
    row.PlayButton:Hide()
    row.ContributeButton:Hide()
    if Safe(function() return env.Contribute and env.Contribute:CanOfferFromLog() end, false)
        and DressPlus(row, questID, title, env) then
        row.ContributeButton:Show()
        return
    end
    row.PlayButton:Show()
    row.PlayButton:Disable()
end

-- --- Detail pane -----------------------------------------------------------

-- ns.Detail.Init hands us the pane; the strip is created lazily off it.
function ns.SpokenButtons.Init(frame)
    detailFrame = frame
end

-- The detail pane's round buttons, created once the first time a quest is
-- shown. They sit on the header strip above the parchment, where Spoken puts
-- them on the world map's quest details. Report anchors the pair; Play sits
-- beside it, and the Contribute text button takes Report's spot while no
-- voice exists.
local function EnsureStrip(env)
    if strip then
        return strip
    end
    local spoken = _G.Spoken
    -- The player draws the round buttons; without it there is nothing to play.
    if not (spoken and spoken.CreateRoundButton) then
        return nil
    end
    local overlay = env.QuestOverlayUI

    local header = detailFrame.HeaderFrame
    local play = spoken:CreateRoundButton(header, "play", "ClassicQuestLogSpokenPlayButton")
    play:SetFrameLevel(header:GetFrameLevel() + 3)
    play.setPlayState = overlay.FollowQueue

    local report = spoken:CreateRoundButton(header, "report", "ClassicQuestLogSpokenReportButton")
    report:SetFrameLevel(header:GetFrameLevel() + 3)
    -- The world map's offsets for the same strip.
    report:SetPoint("RIGHT", header, "RIGHT", -11, 4)
    report:SetScript("OnClick", function(self)
        Safe(function()
            local target = env.ReportButton:TargetForQuest(self.questID, env.Enums.SoundEvent.QuestAccept)
            if target then
                env.ReportButton:ShowLink(target,
                    { fromLog = true, questID = self.questID, title = self.title })
            end
        end)
    end)
    report:HookScript("OnEnter", function()
        GameTooltip:SetOwner(report, "ANCHOR_LEFT")
        GameTooltip:SetText(env.L.OPT_REPORT_PROBLEM)
        GameTooltip:Show()
    end)
    report:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- With no line to play, the pair gives way to Contribute, in words: no
    -- glyph says it. Named, since UIPanelButtonTemplate names its pieces
    -- after its parent. It is centred on the same line as the round pair.
    local contribute = CreateFrame("Button", "ClassicQuestLogSpokenContributeButton",
        header, "UIPanelButtonTemplate")
    contribute:SetFrameLevel(header:GetFrameLevel() + 3)
    contribute:SetHeight(20)
    contribute:SetPoint("RIGHT", header, "RIGHT", -11, 4)
    contribute:Hide()

    strip = { play = play, report = report, contribute = contribute }
    return strip
end

-- Called from ns.Detail.Show: dresses the pane's strip for the quest being
-- shown, or hides it on the empty state.
function ns.SpokenButtons.UpdateDetail(questID)
    local env = Parts()
    local partOn = env and Safe(function() return env.Addon:IsPartOn() end, false)
    if not partOn or not questID or questID == 0 then
        if strip then
            strip.play:Hide()
            strip.report:Hide()
            strip.contribute:Hide()
        end
        return
    end
    Safe(function() RegisterCallbacks(env) end)

    local s = EnsureStrip(env)
    if not s then
        return
    end

    local overlay = env.QuestOverlayUI
    local title = Safe(function() return C_QuestLog.GetTitleForQuestID(questID) end) or ""
    s.report.questID = questID
    s.report.title = title

    -- Rebound rather than kept: this button stood for a different quest a
    -- moment ago. A line of this quest's already queued is the one it stands
    -- for, whoever queued it.
    Safe(function() overlay:BindPlayButton(s.play, questID, title,
        "the Classic Quest Log's detail Play button") end)
    s.play.soundData = Safe(function() return overlay:QueuedLine(questID) end)

    local hasVoice = Safe(function()
        return env.DataModules:PrepareSound(
            { event = env.Enums.SoundEvent.QuestAccept, questID = questID }) and true or false
    end, false)

    s.contribute:Hide()
    if hasVoice then
        s.play:Enable()
        s.play:Show()
        local hidden = _G.Spoken and _G.Spoken.AreReportButtonsHidden
            and Safe(function() return _G.Spoken:AreReportButtonsHidden() end, false)
        s.report:SetShown(not hidden)
    elseif Safe(function() return env.Contribute and env.Contribute:CanOfferFromLog() end, false) then
        s.play:Hide()
        s.report:Hide()
        local contribute = env.Contribute
        s.contribute:SetText(env.L.OPT_CONTRIBUTE)
        s.contribute:SetWidth(math.max(58, (s.contribute:GetTextWidth() or 0) + 24))
        s.contribute:SetScript("OnClick", function()
            Safe(function() contribute:ShowFromLog(questID, title) end)
        end)
        s.contribute:SetScript("OnEnter", function(self)
            Safe(function() contribute:ShowTooltip(self) end)
        end)
        s.contribute:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Safe(function() contribute:OfferLogMenu(s.contribute) end)
        s.contribute:Show()
    else
        s.play:Disable()
        s.play:Show()
        s.report:Hide()
    end

    -- Play in Report's corner while Report is hidden, rather than beside an
    -- empty space.
    s.play:ClearAllPoints()
    if s.report:IsShown() then
        s.play:SetPoint("RIGHT", s.report, "LEFT", -4, 0)
    else
        s.play:SetPoint("RIGHT", s.report, "RIGHT", 0, 0)
    end
    Safe(function() overlay:SetPlayButtonState(s.play) end)
end

-- --- Spoken notices --------------------------------------------------------

-- Spoken's own notices that change what our buttons show. The queue's
-- Play/Stop/Replay flip Spoken already drives: the first button it ever binds
-- registers its AUDIO_CHANGED listener for us, and QuestOverlayUI:RefreshStates
-- sweeps every bound button that is shown, ours included.
RegisterCallbacks = function(_env)
    if callbacksRegistered then
        return
    end
    local spoken = _G.Spoken
    if not (spoken and spoken.RegisterCallback) then
        return
    end
    -- Marked before the registrations rather than after: a retry after a
    -- failure would re-register the ones that succeeded, and each would
    -- refresh the list, and every refresh would retry again.
    callbacksRegistered = true

    local function ListShown()
        return _G.ClassicQuestLogFrame and _G.ClassicQuestLogFrame:IsShown()
    end
    -- A voice pack installed or its part switched: the rows answer on the
    -- next refresh, as any QUEST_LOG_UPDATE would.
    Safe(function() spoken:RegisterCallback("VOICE_PACKS_LOADED", function()
        if ListShown() then
            ns.QuestList.Refresh()
        end
    end) end)
    Safe(function() spoken:RegisterCallback("PART_SWITCHED", function(key)
        if key == "quests" and ListShown() then
            ns.QuestList.Refresh()
        end
    end) end)
    Safe(function() spoken:RegisterCallback("REPORT_SETTINGS_CHANGED", function()
        if ListShown() then
            ns.SpokenButtons.UpdateDetail(C_QuestLog.GetSelectedQuest())
        end
    end) end)
end

-- --- Dev verb --------------------------------------------------------------

-- /cql test spoken: what the integration sees right now.
function ns.SpokenButtons.ReportStatus()
    local env = Parts()
    if not env then
        ns.Print("Spoken Quests: not found (buttons hidden)")
        return
    end
    ns.Print(("Spoken Quests %s found"):format(env.AddonVersion or ""))
    local partOn = Safe(function() return env.Addon:IsPartOn() end, false)
    ns.Print(("quests part on: %s, quest log buttons on: %s")
        :format(tostring(partOn), tostring(RowsShown(env))))
    RegisterCallbacks(env)

    local quests, voiced = 0, 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            quests = quests + 1
            if Safe(function()
                return env.DataModules:PrepareSound(
                    { event = env.Enums.SoundEvent.QuestAccept, questID = info.questID })
            end) then
                voiced = voiced + 1
            end
        end
    end
    ns.Print(("%d of %d quests have a voice"):format(voiced, quests))
end
