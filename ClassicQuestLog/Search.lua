local _, ns = ...

-- ---------------------------------------------------------------------------
-- Search: the search box filter (Stage 6). While a filter is active,
-- QuestList treats every header as expanded and keeps only matching rows.
-- ---------------------------------------------------------------------------

ns.Search = {}

local box
local filter = ""

local function ApplyFilter(text)
    text = strtrim(text or "")
    if filter == text then
        return false
    end
    filter = text
    return true
end

function ns.Search.IsActive()
    return filter ~= ""
end

function ns.Search.GetFilter()
    return filter
end

-- Called from the EditBox; refreshes the list when the filter actually moved.
function ns.Search.OnTextChanged(text)
    if ApplyFilter(text) then
        ns.QuestList.Refresh()
    end
end

function ns.Search.SetShown(shown)
    if not box then
        return
    end
    box:SetShown(shown)
    if not shown then
        -- Hiding the box clears the filter so the full list returns.
        box:SetText("")
        if ApplyFilter("") then
            ns.QuestList.Refresh()
        end
    end
end

-- For dev verbs: applies a filter without focusing the box.
function ns.Search.SetFilter(text)
    if box then
        box:SetText(text or "")
        -- SetText fires OnTextChanged, which applies and refreshes.
        return
    end
    if ApplyFilter(text) then
        ns.QuestList.Refresh()
    end
end

function ns.Search.Init(searchBox)
    box = searchBox

    -- The template ships its own OnTextChanged (it drives the clear button);
    -- chain ours after it instead of replacing it.
    local originalHandler = box:GetScript("OnTextChanged")
    box:SetScript("OnTextChanged", function(self, ...)
        if originalHandler then
            originalHandler(self, ...)
        end
        ns.Search.OnTextChanged(self:GetText())
    end)

    if SEARCH and box.Instructions then
        box.Instructions:SetText(SEARCH)
    end

    -- ns.db may not exist yet (the frame loads before ADDON_LOADED); Core.lua
    -- applies the setting once the DB is ready.
    if ns.db and ns.db.showSearch ~= nil then
        ns.Search.SetShown(ns.db.showSearch)
    end
end
