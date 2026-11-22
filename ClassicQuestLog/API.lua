local _, ns = ...

-- ---------------------------------------------------------------------------
-- API: the public surface other addons (Forever Quest Tint, for one) use to
-- draw on this window without reaching into ns. The global
-- ClassicQuestLogAPI is created while the file loads, so an addon can test
-- for it at any time; nothing in it depends on load order.
--
-- Getters answer from the live frames. Changes are announced through
-- EventRegistry, which is how this addon already talks to the world map, so a
-- listener never has to poll:
--
--   ClassicQuestLog.DetailShown (questID|nil)
--       the detail pane was filled for a quest, or emptied. Fires after the
--       text, the rewards panel and Spoken's strip are laid out.
--   ClassicQuestLog.DetailLayout ()
--       the rewards panel changed height while the text scrolled.
--   ClassicQuestLog.RowInit (row, questID, titleFontString)
--       a quest row in the list was (re)filled. The title is plain text
--       again at this point, so a listener decorates it from scratch.
--   ClassicQuestLog.WindowHidden ()
--       the window closed.
--
-- version is bumped on a breaking change.
-- ---------------------------------------------------------------------------

ns.API = {}

local API = {
    version = 1,
    Events = {
        DetailShown = "ClassicQuestLog.DetailShown",
        DetailLayout = "ClassicQuestLog.DetailLayout",
        RowInit = "ClassicQuestLog.RowInit",
        WindowHidden = "ClassicQuestLog.WindowHidden",
    },
}
ClassicQuestLogAPI = API

-- Announces one of API.Events. A listener's error is reported, not thrown:
-- it must never stop the pane or the list from filling.
function ns.API.Fire(name, ...)
    if not EventRegistry then
        return
    end
    local ok, err = pcall(EventRegistry.TriggerEvent, EventRegistry, API.Events[name], ...)
    if not ok then
        geterrorhandler()(err)
    end
end

-- The window, or nil before it has loaded.
function API.GetFrame()
    return ClassicQuestLogFrame
end

-- The detail pane (the right-hand side, or the lower half in the single layout).
function API.GetDetailFrame()
    return ClassicQuestLogFrame and ClassicQuestLogFrame.Detail
end

-- The pane's parchment: the same Quest Text Contrast atlas the world map's
-- quest details use, scaled to the pane's width and cropped to its height.
-- Its parent holds RewardsFrameContainer, the panel pinned over its bottom.
function API.GetDetailParchment()
    local detail = API.GetDetailFrame()
    return detail and detail.Bg
end

-- The strip along the top of the pane, where Spoken's round buttons sit.
function API.GetDetailHeader()
    local detail = API.GetDetailFrame()
    return detail and detail.HeaderFrame
end

-- The quest the pane shows, or nil when it is empty or the window is closed.
function API.GetDisplayedQuestID()
    local frame, detail = ClassicQuestLogFrame, API.GetDetailFrame()
    if frame and frame:IsShown() and detail then
        return detail.questID
    end
end

-- Calls fn(row, questID, titleFontString) for every quest row that exists in
-- the list right now (the visible ones; headers are skipped).
function API.ForEachQuestRow(fn)
    ns.QuestList.ForEachQuestRow(fn)
end
