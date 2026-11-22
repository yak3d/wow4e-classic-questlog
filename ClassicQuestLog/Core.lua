local addonName, ns = ...

-- ---------------------------------------------------------------------------
-- Constants and defaults
-- ---------------------------------------------------------------------------
local ADDON_COLOR = "|cff00ccff"
local DB_VERSION = 1
local CHAR_DB_VERSION = 1

-- The seven settings from the plan. Every key here has a live-apply callback
-- in Settings.lua.
local DEFAULT_DB = {
    version = DB_VERSION,
    enabled = true,
    layout = "double",
    showLevel = true,
    difficultyColor = true,
    showSearch = true,
    hideMapQuestPanel = true,
    trackerOpensLog = true,
}

-- Per-character internal state. No settings UI for this (see plan, decision 3).
local DEFAULT_CHAR_DB = {
    version = CHAR_DB_VERSION,
    mapPanelCollapsed = false,
    collapsedHeaders = {},
    -- The filter dropdown. The hidden* sets list UNticked entries, so an
    -- empty set shows everything.
    filters = {
        currentZone = false,
        hideGrey = false,
        trackedOnly = false,
        partyOnly = false,
        hiddenStatus = {},
        hiddenDifficulty = {},
        hiddenTypes = {},
    },
}

-- Exposed so Settings.lua can use the same defaults when registering settings.
ns.defaults = DEFAULT_DB

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
function ns.Print(msg)
    print(ADDON_COLOR .. "ClassicQuestLog|r: " .. tostring(msg))
end

-- Recursively fills in any keys missing from dst using the values in src,
-- without overwriting values the player has already saved.
local function DeepCopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if dst[k] == nil then
                dst[k] = {}
            end
            if type(dst[k]) == "table" then
                DeepCopyDefaults(v, dst[k])
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- ---------------------------------------------------------------------------
-- Boot: SavedVariables init, char DB, settings registration
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= addonName then
            return
        end

        -- Initialize SavedVariables. LoadSavedVariablesFirst means the tables
        -- usually exist already; this only runs on a truly fresh install.
        if not ClassicQuestLogDB then
            ClassicQuestLogDB = {}
        end
        DeepCopyDefaults(DEFAULT_DB, ClassicQuestLogDB)

        -- DB migration
        if (ClassicQuestLogDB.version or 0) < DB_VERSION then
            -- Add per-version migration steps here as DB_VERSION grows.
            ClassicQuestLogDB.version = DB_VERSION
        end

        ns.db = ClassicQuestLogDB

        -- Per-character DB
        if not ClassicQuestLogCharDB then
            ClassicQuestLogCharDB = {}
        end
        DeepCopyDefaults(DEFAULT_CHAR_DB, ClassicQuestLogCharDB)
        if (ClassicQuestLogCharDB.version or 0) < CHAR_DB_VERSION then
            ClassicQuestLogCharDB.version = CHAR_DB_VERSION
        end
        ns.chardb = ClassicQuestLogCharDB

        -- Register the Settings -> AddOns category now that ns.db exists.
        ns.Settings.Init()

        -- The frame's OnLoad ran before the DB existed; sync it now.
        ns.Frame.ApplyLayout(ns.db.layout)
        ns.Search.SetShown(ns.db.showSearch)

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- The world is ready; hook frames and read player state from here on.
        ns.Print(ns.L["LOADED"])
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
-- These global names are SLASH_ + the addon name in upper case + an index.
SLASH_CLASSICQUESTLOG1 = "/classicquestlog"
SLASH_CLASSICQUESTLOG2 = "/cql"

SlashCmdList["CLASSICQUESTLOG"] = function(input)
    local L = ns.L
    -- rest holds everything after the subcommand, for commands that take arguments.
    local cmd, rest = input:match("^(%S+)%s*(.*)") -- luacheck: ignore rest
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        ns.Frame.Toggle()

    elseif cmd == "config" then
        ns.Settings.Open()

    elseif cmd == "help" then
        ns.Print(L["HELP_HEADER"])
        ns.Print(L["HELP_CONFIG"])
        ns.Print(L["HELP_TOGGLE"])
        ns.Print(L["HELP_TEST"])

    elseif cmd == "toggle" then
        ns.db.enabled = not ns.db.enabled
        ns.Hooks.SetEnabled(ns.db.enabled)
        ns.Print(ns.db.enabled and L["HOOK_TOGGLED_ON"] or L["HOOK_TOGGLED_OFF"])

    elseif cmd == "test" then
        ns.Dev.Handle(rest)

    else
        ns.Print(L["UNKNOWN_COMMAND"]:format(cmd))
    end
end
