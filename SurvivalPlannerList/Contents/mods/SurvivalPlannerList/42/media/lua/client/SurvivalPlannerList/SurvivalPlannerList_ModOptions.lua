require "PZAPI/ModOptions"

SPLModOptions = SPLModOptions or {}

local OPTIONS_ID = "SurvivalPlannerList"
local OPEN_PLANNER_ID = "OpenPlanner"
local LEGACY_SECTION_ID = "[SurvivalPlannerList]"
local LEGACY_BINDING_ID = "SurvivalPlannerList_OpenPlanner"

local function translatedText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function removeLegacyKeyBindingEntries()
    if not keyBinding then
        return
    end

    for index = #keyBinding, 1, -1 do
        local value = keyBinding[index] and keyBinding[index].value
        if value == LEGACY_SECTION_ID or value == LEGACY_BINDING_ID then
            table.remove(keyBinding, index)
        end
    end
end

removeLegacyKeyBindingEntries()

local optionsTitle = translatedText("IGUI_SPL_Options_Title", "Survival Planner")
local openPlannerLabel = translatedText("IGUI_SPL_Options_OpenPlanner", "Open planner")
local openPlannerTooltip = translatedText(
    "IGUI_SPL_Options_OpenPlanner_Tooltip",
    "Keyboard shortcut used to open the carried Survival Planner."
)

local options = PZAPI.ModOptions:getOptions(OPTIONS_ID)
if not options then
    options = PZAPI.ModOptions:create(OPTIONS_ID, optionsTitle)
end
options.name = optionsTitle

local openPlannerKey = options:getOption(OPEN_PLANNER_ID)
if not openPlannerKey then
    openPlannerKey = options:addKeyBind(
        OPEN_PLANNER_ID,
        openPlannerLabel,
        Keyboard.KEY_K,
        openPlannerTooltip
    )
end
openPlannerKey.name = openPlannerLabel
openPlannerKey.tooltip = openPlannerTooltip

SPLModOptions.options = options
SPLModOptions.openPlannerKey = openPlannerKey

return SPLModOptions
