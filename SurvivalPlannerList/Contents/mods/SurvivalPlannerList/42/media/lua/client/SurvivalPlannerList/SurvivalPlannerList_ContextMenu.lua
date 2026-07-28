require "ISUI/ISInventoryPane"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_MainPanel"

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function openPlanner(planner, playerNum)
    if not planner or not SurvivalPlannerList.isPlanner(planner) then
        return
    end
    SurvivalPlannerList.openPlannerUI(playerNum, planner)
end

local function addPlannerContextOption(playerNum, context, items)
    local actualItems = ISInventoryPane.getActualItems(items)
    for _, item in ipairs(actualItems) do
        if SurvivalPlannerList.isPlanner(item) then
            local option = context:addOption(
                uiText("ContextMenu_SurvivalPlannerList_Open", "Open Survival Planner"),
                item,
                openPlanner,
                playerNum
            )
            option.iconTexture = item:getTexture()
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(addPlannerContextOption)

return SurvivalPlannerList
