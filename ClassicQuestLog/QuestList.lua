local _, ns = ...

-- ---------------------------------------------------------------------------
-- QuestList: builds the quest list (Stage 2) and owns the ScrollBox that
-- shows it. Build() is a pure function so /cql test list can print its result.
-- ---------------------------------------------------------------------------

ns.QuestList = {}

-- These mixins are global because Templates.xml resolves mixin= attributes by
-- global name when it loads, and this file loads before Templates.xml.
ClassicQuestLogHeaderMixin = {}
ClassicQuestLogQuestRowMixin = {}

local listPane
local scrollBox
local eventFrame
local listening = false
local refreshScheduled = false

local LIST_EVENTS = {
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "UNIT_QUEST_LOG_CHANGED",
    "QUEST_REMOVED",
    "ZONE_CHANGED_NEW_AREA",
}

-- --- Header mixin ----------------------------------------------------------

function ClassicQuestLogHeaderMixin:Init(node)
    self.node = node
    self.Name:SetText(node.title)
    self:UpdateExpandedState()
end

function ClassicQuestLogHeaderMixin:UpdateExpandedState()
    local atlas = self.node.isCollapsed and "common-button-list-plus" or "common-button-list-minus"
    self.StateIcon:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
end

function ClassicQuestLogHeaderMixin:OnClick()
    PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
    ns.QuestList.ToggleHeader(self.node)
end

-- --- Quest row mixin -------------------------------------------------------

function ClassicQuestLogQuestRowMixin:GetTitleColor()
    return self.node and self.node.difficultyColor or NORMAL_FONT_COLOR
end

function ClassicQuestLogQuestRowMixin:SetTitleColor(color)
    self.Title:SetTextColor(color.r, color.g, color.b)
end

function ClassicQuestLogQuestRowMixin:Init(node)
    self.node = node

    self.Title:SetText(node.title)
    -- A click refreshes the list and re-inits the row still under the cursor,
    -- so keep its hover colour.
    self:SetTitleColor(self:IsMouseOver() and HIGHLIGHT_FONT_COLOR or self:GetTitleColor())

    self.Tag:SetText(node.tagText or "")
    self.Check:SetShown(node.isWatched)

    if node.numPartyMembers and node.numPartyMembers > 0 then
        self.GroupMates:SetText("[" .. node.numPartyMembers .. "]")
        self.GroupMates:SetShown(true)
    else
        self.GroupMates:SetText("")
        self.GroupMates:SetShown(false)
    end

    self:SetSelectedState(node.selected)

    -- Spoken Quests' Play / Contribute button on this row, when the addon is
    -- installed and its quest log buttons are on; a no-op without it.
    ns.SpokenButtons.DressRow(self, node)

    -- Last, so a listener decorating the title sees its final anchors.
    ns.API.Fire("RowInit", self, node.questID, self.Title)
end

function ClassicQuestLogQuestRowMixin:SetSelectedState(selected)
    self.SelectedOverlay:SetShown(selected)
    self.HighlightOverlay:SetShown(not selected)
end

function ClassicQuestLogQuestRowMixin:OnEnter()
    self:SetTitleColor(HIGHLIGHT_FONT_COLOR)

    local names = self.node and self.node.partyNames
    if names and #names > 0 then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.L["LIST_PARTY_TOOLTIP"])
        for _, name in ipairs(names) do
            GameTooltip:AddLine(name)
        end
        GameTooltip:Show()
    end
end

function ClassicQuestLogQuestRowMixin:OnLeave()
    self:SetTitleColor(self:GetTitleColor())
    GameTooltip:Hide()
end

function ClassicQuestLogQuestRowMixin:OnClick(mouseButton)
    PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
    ns.Actions.RowClicked(self.node, mouseButton)
end

-- --- Row decorations (pure data helpers) -----------------------------------

-- While the log is open, refreshes arrive as bursts of QUEST_LOG_UPDATE;
-- coalesce them into one refresh.
local function ScheduleRefresh()
    if refreshScheduled then
        return
    end
    refreshScheduled = true
    C_Timer.After(0, function()
        refreshScheduled = false
        if listening then
            ns.QuestList.Refresh()
        end
    end)
end

local function GetSearchState()
    if ns.Search and ns.Search.IsActive() then
        return true, ns.Search.GetFilter():lower()
    end
    return false, nil
end

-- QuestUtilsOverrides.GetQuestTitlePrefix only answers when the client CVars
-- ask for it, so fall back to our own "[12] " / "[12+] " prefix (the " +
-- comes from a big suggested group, i.e. elite).
local function GetLevelPrefix(info)
    if not ns.db or not ns.db.showLevel then
        return ""
    end

    if QuestUtilsOverrides and QuestUtilsOverrides.GetQuestTitlePrefix then
        local prefix = QuestUtilsOverrides.GetQuestTitlePrefix(info)
        if prefix then
            return prefix
        end
    end

    local level = info.level or info.difficultyLevel
    if not level then
        return ""
    end

    if info.suggestedGroup and info.suggestedGroup >= 5 then
        return "[" .. level .. "+] "
    end
    return "[" .. level .. "] "
end

-- The quest's difficulty relative to the player (0 trivial .. 4 impossible).
local function GetQuestDifficulty(questID)
    if not C_PlayerInfo or not C_PlayerInfo.GetContentDifficultyQuestForPlayer then
        return nil
    end
    local ok, difficulty = pcall(C_PlayerInfo.GetContentDifficultyQuestForPlayer, questID)
    if not ok then
        return nil
    end
    return difficulty
end

-- Blizzard's override returns nil whenever the showQuestDifficultyColor CVar
-- is off, so we compute the colour ourselves.
local function GetDifficultyColorFor(difficulty)
    if not difficulty or not GetDifficultyColor then
        return nil
    end
    local colorOk, color = pcall(GetDifficultyColor, difficulty)
    if not colorOk then
        return nil
    end
    return color
end

-- Tag priority: Failed, then Complete, then the Camelot tag text.
local function Parens(text)
    if PARENS_TEMPLATE then
        return PARENS_TEMPLATE:format(text)
    end
    return "(" .. text .. ")"
end

local function GetTagText(questID)
    if C_QuestLog.IsFailed and C_QuestLog.IsFailed(questID) then
        return Parens(FAILED)
    elseif C_QuestLog.IsComplete(questID) then
        return Parens(COMPLETE)
    elseif QuestUtilsOverrides and QuestUtilsOverrides.GetQuestTagText then
        return QuestUtilsOverrides.GetQuestTagText(questID)
    end
    return nil
end

-- This build has no C_QuestLog.IsQuestWatched; it ships
-- QuestUtils_IsQuestWatched (a watched quest is one the log has a
-- QuestWatchType for: Automatic or Manual).
function ns.QuestList.IsQuestWatched(questID)
    if QuestUtils_IsQuestWatched then
        return QuestUtils_IsQuestWatched(questID) and true or false
    end
    if questID and C_QuestLog.GetQuestWatchType then
        return C_QuestLog.GetQuestWatchType(questID) ~= nil
    end
    return false
end

local function GetPartyInfo(questID)
    local num = 0
    if QuestUtils_GetNumPartyMembersOnQuest then
        num = QuestUtils_GetNumPartyMembersOnQuest(questID) or 0
    end
    if num == 0 then
        return 0, nil
    end

    local names = {}
    local numMembers = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for i = 1, numMembers do
        local unit = i == 1 and "party1" or "party" .. i
        if C_QuestLog.IsUnitOnQuest(unit, questID) then
            local name = UnitName(unit)
            if name and name ~= "" then
                names[#names + 1] = name
            end
        end
    end
    return num, names
end

local function MakeRow(info, searching)
    local questID = info.questID
    local numParty, partyNames = GetPartyInfo(questID)
    local difficulty = GetQuestDifficulty(questID)

    return {
        isHeader = false,
        questLogIndex = info.questLogIndex,
        questID = questID,
        title = (searching and "" or GetLevelPrefix(info)) .. (info.title or ""),
        tagText = GetTagText(questID),
        difficulty = difficulty,
        difficultyColor = (not searching and ns.db.difficultyColor) and GetDifficultyColorFor(difficulty) or nil,
        isWatched = ns.QuestList.IsQuestWatched(questID),
        numPartyMembers = numParty,
        partyNames = partyNames,
    }
end

-- --- Building the list -----------------------------------------------------

function ns.QuestList.Build()
    -- The frame loads before ADDON_LOADED, so the DB may not exist yet.
    if not ns.db then
        return {}
    end

    local searching, filter = GetSearchState()
    local nodes = {}
    local headerless = {}
    local current

    -- Emits a header and its rows only when the header has visible quests.
    -- A collapsed header still counts them, so it stays on screen to expand.
    local function Flush()
        if current then
            if current.visible > 0 then
                tinsert(nodes, current.node)
                for _, row in ipairs(current.rows) do
                    tinsert(nodes, row)
                end
            end
            current = nil
        end
    end

    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                Flush()
                current = {
                    node = {
                        isHeader = true,
                        title = info.title,
                        questLogIndex = info.questLogIndex,
                        isCollapsed = ns.QuestList.IsHeaderCollapsed(info.title),
                    },
                    rows = {},
                    visible = 0,
                }
            else
                local visible = not info.isTask and not info.isHidden
                    and (not info.isBounty or C_QuestLog.IsComplete(info.questID))
                if visible then
                    local row = MakeRow(info, searching)
                    -- While a search is active every header is treated as
                    -- expanded and only matching rows are kept. The filter
                    -- dropdown applies on top of both.
                    local matches = not searching or row.title:lower():find(filter, 1, true)
                    if matches and ns.Filters.Passes(info, current and current.node.title, row) then
                        if current then
                            current.visible = current.visible + 1
                            if searching or not current.node.isCollapsed then
                                tinsert(current.rows, row)
                            end
                        else
                            tinsert(headerless, row)
                        end
                    end
                end
            end
        end
    end
    Flush()

    for _, row in ipairs(headerless) do
        tinsert(nodes, row)
    end

    return nodes
end

function ns.QuestList.GetQuestCount()
    local _, current = C_QuestLog.GetNumQuestLogEntries()
    local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 0
    return current or 0, max or 0
end

-- --- ScrollBox wiring ------------------------------------------------------

function ns.QuestList.Init(parent)
    listPane = parent
    scrollBox = parent.ScrollBox
    local scrollBar = parent.ScrollBar

    -- Camelot anchoring: the scrollbar hugs the ScrollBox's right edge.
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 5, -2)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 5, 4)

    local view = CreateScrollBoxListLinearView(6, 6, 6, 6, 2)
    view:SetElementFactory(function(factory, node)
        -- This build's factory contract: factory(template, initializer). The
        -- initializer runs after layout, and the view stretches element width.
        if node.isHeader then
            factory("ClassicQuestLogHeaderTemplate", function(frame, elementData)
                frame:Init(elementData)
            end)
        else
            factory("ClassicQuestLogQuestRowTemplate", function(frame, elementData)
                frame:Init(elementData)
            end)
        end
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    scrollBox:SetDataProvider(CreateDataProvider({}))

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function()
        ScheduleRefresh()
    end)
end

-- Calls fn(row, questID, titleFontString) for each quest row the ScrollBox
-- currently holds (headers are skipped).
function ns.QuestList.ForEachQuestRow(fn)
    if not scrollBox then
        return
    end
    scrollBox:ForEachFrame(function(row, node)
        if node and not node.isHeader then
            fn(row, node.questID, row.Title)
        end
    end)
end

function ns.QuestList.Refresh(ensureSelection)
    if not scrollBox or not ns.db then
        return
    end

    local nodes = ns.QuestList.Build()

    local selectedQuestID = C_QuestLog.GetSelectedQuest()
    local validSelection = false
    if selectedQuestID and selectedQuestID ~= 0 then
        for _, node in ipairs(nodes) do
            if not node.isHeader and node.questID == selectedQuestID then
                validSelection = true
                break
            end
        end
    end

    if ensureSelection and not validSelection then
        -- On open, keep the selected quest if it is still in the visible
        -- list, otherwise select the first visible quest.
        selectedQuestID = nil
        for _, node in ipairs(nodes) do
            if not node.isHeader then
                selectedQuestID = node.questID
                C_QuestLog.SetSelectedQuest(node.questID)
                break
            end
        end
    end

    for _, node in ipairs(nodes) do
        if not node.isHeader then
            node.selected = (node.questID == selectedQuestID)
        end
    end

    -- Fill the list before touching the detail pane, so a failure there can
    -- never blank the list.
    scrollBox:SetDataProvider(CreateDataProvider(nodes), ScrollBoxConstants.RetainScrollPosition)

    local current, max = ns.QuestList.GetQuestCount()

    if listPane and listPane.EmptyText then
        -- A log with quests but an empty list means a filter hid them all.
        listPane.EmptyText:SetText(current > 0 and ns.L["FILTER_NO_MATCH"] or QUEST_LOG_NO_QUESTS)
        listPane.EmptyText:SetShown(#nodes == 0)
    end
    ns.Frame.SetQuestCount(current, max)

    if ns.Actions then
        ns.Actions.UpdateButtons()
    end

    if ensureSelection then
        if selectedQuestID then
            ns.Detail.Show(selectedQuestID)
        else
            ns.Detail.Show(nil)
        end
    end
end

function ns.QuestList.SelectQuest(questID)
    if not questID or questID == 0 then
        return
    end
    ns.QuestList.ExpandHeaderForQuest(questID)
    C_QuestLog.SetSelectedQuest(questID)
    ns.Detail.Show(questID)
    ns.QuestList.Refresh()
end

-- Collapse state belongs to this addon, saved per character by zone title.
-- The game's own header flag is not used: Blizzard's map code resets it on
-- every loading screen.
function ns.QuestList.IsHeaderCollapsed(title)
    local collapsed = ns.chardb and ns.chardb.collapsedHeaders
    return collapsed and title and collapsed[title] or false
end

local function SetHeaderCollapsed(title, collapsed)
    if ns.chardb and title then
        ns.chardb.collapsedHeaders = ns.chardb.collapsedHeaders or {}
        ns.chardb.collapsedHeaders[title] = collapsed or nil
    end
end

function ns.QuestList.ToggleHeader(node)
    if not node or not node.title then
        return
    end
    SetHeaderCollapsed(node.title, not node.isCollapsed)
    ns.QuestList.Refresh()
end

-- Expands the zone holding a quest so a selected quest is never hidden.
function ns.QuestList.ExpandHeaderForQuest(questID)
    local header
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                header = info.title
            elseif info.questID == questID then
                SetHeaderCollapsed(header, false)
                return
            end
        end
    end
end

-- Events are registered only while the window is shown.
function ns.QuestList.SetListening(shown)
    if not eventFrame or listening == shown then
        return
    end
    listening = shown
    for _, event in ipairs(LIST_EVENTS) do
        if shown then
            eventFrame:RegisterEvent(event)
        else
            eventFrame:UnregisterEvent(event)
        end
    end
end
