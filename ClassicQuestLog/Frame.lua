local _, ns = ...

-- ---------------------------------------------------------------------------
-- Frame: the window shell (Stage 1). Owns the layouts, the UI panel
-- registration and the show/hide pair with combat fallbacks.
-- ---------------------------------------------------------------------------

ns.Frame = {}

-- Global because Frame.xml resolves mixin= by global name; this file loads
-- before Frame.xml.
ClassicQuestLogFrameMixin = {}

local frame
local currentLayout = "double"
local pendingLayout

-- The world map's quest details pane is 308 wide. Ours is 40 wider in both
-- layouts for longer lines of quest text; the map's fixed-width art is
-- stretched to fit (Frame.xml). Its scrollbar sits inside it (Detail.lua),
-- so the window keeps the frame's usual 6px right inset.
local MAP_DETAIL_WIDTH = 308
local DETAIL_WIDTH = MAP_DETAIL_WIDTH + 40
ns.Frame.MAP_DETAIL_WIDTH = MAP_DETAIL_WIDTH
ns.Frame.DETAIL_WIDTH = DETAIL_WIDTH
local RIGHT_GUTTER = 6
-- There is no bottom button bar: the list stops at the frame's 4px bottom
-- inset (ButtonFrameTemplate_HideButtonBar's offset). The quest buttons hang
-- 6 below the detail pane, so they end on the same line as the list.
local PANE_BOTTOM = 4
local DETAIL_BOTTOM = PANE_BOTTOM + 6

ns.Frame.LAYOUTS = {
    double = {
        width = 4 + 322 + 4 + DETAIL_WIDTH + RIGHT_GUTTER,
        -- The detail pane is 502 tall, as on the world map.
        height = 60 + 502 + DETAIL_BOTTOM,
        insetWidth = 322,
    },
    single = {
        width = 4 + DETAIL_WIDTH + RIGHT_GUTTER,
        height = 704,
        insetHeight = 170,
    },
}

-- --- Layout ----------------------------------------------------------------

function ns.Frame.ApplyLayout(name)
    local layoutName = ns.Frame.LAYOUTS[name] and name or "double"
    local layout = ns.Frame.LAYOUTS[layoutName]

    currentLayout = layoutName
    if ns.db then
        ns.db.layout = layoutName
    end

    if InCombatLockdown() then
        -- In combat, store the layout and apply it on PLAYER_REGEN_ENABLED.
        pendingLayout = layoutName
        return
    end
    pendingLayout = nil

    if not frame then
        return
    end

    frame:SetSize(layout.width, layout.height)

    -- Attic: title bar, portrait, count and Show Map (y 0..-60).
    frame.CountFrame:ClearAllPoints()
    frame.CountFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -32)

    frame.ShowMapButton:ClearAllPoints()
    frame.ShowMapButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -28)

    -- Panes.
    local inset = frame.Inset
    inset:ClearAllPoints()
    local detail = frame.Detail
    detail:ClearAllPoints()

    -- Search row (y -62..-82) sits above the list pane.
    local listTop = -90

    if layoutName == "single" then
        inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, listTop)
        inset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -RIGHT_GUTTER, listTop)
        inset:SetHeight(layout.insetHeight)

        detail:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 0, -4)
        detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RIGHT_GUTTER, DETAIL_BOTTOM)
    else
        inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, listTop)
        inset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, PANE_BOTTOM)
        inset:SetWidth(layout.insetWidth)

        detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + layout.insetWidth + 4, -60)
        detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RIGHT_GUTTER, DETAIL_BOTTOM)
    end

    -- The search row is centred in the dark strip between the attic and the
    -- list. The strip's bordered inside runs y -63.3..-90 and x 7.5..330 (the
    -- detail pane's edge); the offsets below leave equal gaps on all sides,
    -- allowing for the search art reaching 4.5 left of its frame.
    local rowCenterY = 13.33
    frame.FilterDropdown:ClearAllPoints()
    frame.FilterDropdown:SetPoint("RIGHT", inset, "TOPRIGHT", -2.5, rowCenterY)
    -- The template pins the text to the top edge; centre it, nudged left so
    -- the text and the arrow read as one group.
    local filterText = frame.FilterDropdown.Text
    filterText:ClearAllPoints()
    filterText:SetPoint("CENTER", frame.FilterDropdown, "CENTER", -6, 0)
    frame.SearchBox:ClearAllPoints()
    frame.SearchBox:SetPoint("LEFT", inset, "TOPLEFT", 14, rowCenterY)
    frame.SearchBox:SetPoint("RIGHT", frame.FilterDropdown, "LEFT", -4, 0)

    -- Detail internals, at the world map's offsets: the text starts under the
    -- header strip and ends above the quest buttons.
    detail.ScrollFrame:ClearAllPoints()
    detail.ScrollFrame:SetPoint("TOPLEFT", detail, "TOPLEFT", 5, -43)
    detail.ScrollFrame:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 5, 29)
    detail.ScrollFrame:SetWidth(DETAIL_WIDTH - 10)
    detail.ScrollFrame.ScrollChild:SetWidth(DETAIL_WIDTH - 10)

    -- The quest buttons split the pane's width in three.
    local third = math.floor(DETAIL_WIDTH / 3)
    detail.AbandonButton:SetWidth(third)
    detail.ShareButton:SetWidth(DETAIL_WIDTH - 2 * third)
    detail.TrackButton:SetWidth(third)

    if frame:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(frame)
    end
    if ns.Detail then
        ns.Detail.RefreshSelected()
    end
    if ns.QuestList then
        ns.QuestList.Refresh()
    end
end

function ns.Frame.GetLayoutName()
    return currentLayout
end

-- --- Count box -------------------------------------------------------------

function ns.Frame.SetQuestCount(current, max)
    if not frame or not frame.CountFrame or not frame.CountFrame.Text then
        return
    end
    frame.CountFrame.Text:SetText(ns.L["FRAME_COUNT"]:format(current or 0, max or 0))
    if max and max > 0 and current >= max then
        frame.CountFrame.Text:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    else
        frame.CountFrame.Text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
end

-- --- Show / hide -----------------------------------------------------------

function ns.Frame.Show()
    if not frame then
        return
    end
    if InCombatLockdown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        frame:Show()
    else
        ShowUIPanel(frame)
    end
end

function ns.Frame.Hide()
    if not frame then
        return
    end
    if InCombatLockdown() then
        frame:Hide()
    else
        HideUIPanel(frame)
    end
end

function ns.Frame.Toggle()
    if frame and frame:IsShown() then
        ns.Frame.Hide()
    else
        ns.Frame.Show()
    end
end

-- Opens the log and selects a quest (used by Show Map-free tracker routing
-- and /cql test select).
function ns.Frame.OpenToQuest(questID)
    ns.Frame.Show()
    if questID and ns.QuestList then
        ns.QuestList.SelectQuest(questID)
    end
end

-- --- Mixin -----------------------------------------------------------------

function ns.Frame.OnFrameLoaded(f)
    frame = f

    -- UI panel registration: classic QuestLogFrame values. The frame pushes
    -- other left panels but is not pushed itself.
    UIPanelWindows["ClassicQuestLogFrame"] = { area = "left", pushable = 0, whileDead = 1 }
    tinsert(UISpecialFrames, "ClassicQuestLogFrame")

    -- Frame-owned event: apply a layout that combat deferred.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        if pendingLayout then
            ns.Frame.ApplyLayout(pendingLayout)
        end
    end)

    ns.QuestList.Init(f.Inset.QuestList)
    ns.Detail.Init(f.Detail)
    ns.Search.Init(f.SearchBox)
    ns.Filters.Init(f.FilterDropdown)
    ns.Actions.Init(f)

    ns.Frame.ApplyLayout(ns.db and ns.db.layout or "double")
end

function ClassicQuestLogFrameMixin:OnLoad()
    self:SetPortraitToAsset("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    self:SetTitle(QUEST_LOG)
    ns.Frame.OnFrameLoaded(self)
end

function ClassicQuestLogFrameMixin:OnShow()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
    ns.QuestList.SetListening(true)
    ns.Detail.SetListening(true)
    ns.QuestList.Refresh(true)
    ns.Detail.RefreshSelected()
    ns.Actions.OnFrameShown()
    if QuestLogMicroButton then
        QuestLogMicroButton:UpdateMicroButton()
    end
end

function ClassicQuestLogFrameMixin:OnHide()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
    ns.QuestList.SetListening(false)
    ns.Detail.SetListening(false)
    ns.Actions.OnFrameHidden()
    if QuestLogMicroButton then
        QuestLogMicroButton:UpdateMicroButton()
    end
    ns.API.Fire("WindowHidden")
end
