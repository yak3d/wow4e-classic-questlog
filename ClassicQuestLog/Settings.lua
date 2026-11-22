local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- Settings: Settings -> AddOns -> Classic Quest Log (Stage 6).
-- Every setting is registered against the account-wide DB and applied live
-- through SetOnValueChangedCallback.
-- ---------------------------------------------------------------------------

-- Locale.lua is listed before this file in the TOC, so ns.L already exists.
local L = ns.L

ns.Settings = {}

-- Setting variable names must be unique across every loaded addon, so they are
-- prefixed with this addon's name.
local VAR_PREFIX = addonName .. "_"

local category = nil

-- ---------------------------------------------------------------------------
-- Live apply
-- ---------------------------------------------------------------------------
local function LiveApply(key, value)
    if key == "enabled" then
        ns.Hooks.SetEnabled(value)

    elseif key == "layout" then
        ns.Frame.ApplyLayout(value)

    elseif key == "showLevel" or key == "difficultyColor" then
        ns.QuestList.Refresh()

    elseif key == "showSearch" then
        ns.Search.SetShown(value)

    elseif key == "hideMapQuestPanel" then
        if value then
            SetCVar("questLogOpen", "0")
            if ns.chardb then
                ns.chardb.mapPanelCollapsed = true
            end
        else
            SetCVar("questLogOpen", "1")
            if ns.chardb then
                ns.chardb.mapPanelCollapsed = false
            end
        end

    elseif key == "trackerOpensLog" then
        -- The hooks read the flag on every click; nothing to apply.
    end
end

-- Public for Dev.lua's `set` verb, which flips a DB key and runs the same
-- callback the settings panel would.
function ns.Settings.ApplyLive(key, value)
    LiveApply(key, value)
end

-- ---------------------------------------------------------------------------
-- Registration helpers
-- ---------------------------------------------------------------------------
local function Register(key, varType, label, default)
    local setting = Settings.RegisterAddOnSetting(
        category,
        VAR_PREFIX .. key,
        key,
        ns.db,
        varType,
        label,
        default
    )

    -- The DB is already updated when the callback fires, so read the new value
    -- from the setting itself instead of relying on the callback's arguments.
    local function OnChanged()
        LiveApply(key, setting:GetValue())
    end
    if setting.SetValueChangedCallback then
        setting:SetValueChangedCallback(OnChanged)
    elseif setting.SetOnValueChangedCallback then
        setting:SetOnValueChangedCallback(OnChanged)
    end

    return setting
end

local function AddCheckbox(key, label, tooltip, default)
    local setting = Register(key, Settings.VarType.Boolean, label, default)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddDropdown(key, label, tooltip, default, choices)
    local setting = Register(key, Settings.VarType.String, label, default)

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            container:Add(choice.value, choice.label)
        end
        return container:GetData()
    end

    Settings.CreateDropdown(category, setting, GetOptions, tooltip)
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------
-- Called from Core.lua on ADDON_LOADED once ns.db has been assigned. Safe to
-- call more than once.
function ns.Settings.Init()
    if category or not ns.db then
        return
    end

    local defaults = ns.defaults

    category = Settings.RegisterVerticalLayoutCategory(L["TITLE"])

    AddCheckbox("enabled", L["SETTING_ENABLED"], L["SETTING_ENABLED_TT"], defaults.enabled)

    AddDropdown("layout", L["SETTING_LAYOUT"], L["SETTING_LAYOUT_TT"], defaults.layout, {
        { value = "double", label = L["SETTING_LAYOUT_DOUBLE"] },
        { value = "single", label = L["SETTING_LAYOUT_SINGLE"] },
    })

    AddCheckbox("showLevel", L["SETTING_SHOW_LEVEL"], L["SETTING_SHOW_LEVEL_TT"], defaults.showLevel)
    AddCheckbox("difficultyColor", L["SETTING_DIFFICULTY_COLOR"], L["SETTING_DIFFICULTY_COLOR_TT"], defaults.difficultyColor)
    AddCheckbox("showSearch", L["SETTING_SHOW_SEARCH"], L["SETTING_SHOW_SEARCH_TT"], defaults.showSearch)
    AddCheckbox("hideMapQuestPanel", L["SETTING_HIDE_MAP_QUEST_PANEL"], L["SETTING_HIDE_MAP_QUEST_PANEL_TT"], defaults.hideMapQuestPanel)
    AddCheckbox("trackerOpensLog", L["SETTING_TRACKER_OPENS_LOG"], L["SETTING_TRACKER_OPENS_LOG_TT"], defaults.trackerOpensLog)

    Settings.RegisterAddOnCategory(category)
end

-- ---------------------------------------------------------------------------
-- Open the panel (used by /cql config)
-- ---------------------------------------------------------------------------
function ns.Settings.Open()
    if not category then
        ns.Settings.Init()
    end
    if category then
        Settings.OpenToCategory(category:GetID())
    end
end
