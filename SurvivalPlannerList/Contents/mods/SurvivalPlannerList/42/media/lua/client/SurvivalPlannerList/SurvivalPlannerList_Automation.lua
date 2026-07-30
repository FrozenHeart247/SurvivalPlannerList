require "SurvivalPlannerList/SurvivalPlannerList_Core"

SurvivalPlannerList.Automation = SurvivalPlannerList.Automation or {}

local Automation = SurvivalPlannerList.Automation
local DEFAULT_SCAN_INTERVAL_SECONDS = 1.0
local MIN_SCAN_INTERVAL_SECONDS = 0.25
local MAX_SCAN_INTERVAL_SECONDS = 5.0
local DEFAULT_ARRIVAL_RADIUS = 5
local MAX_ARRIVAL_RADIUS = 50

Automation.snapshots = Automation.snapshots or {}
Automation.lastChecks = Automation.lastChecks or {}

local function timestampMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getGameTime then
        local gameTime = getGameTime()
        if gameTime and gameTime.getWorldAgeHours then
            return math.floor(gameTime:getWorldAgeHours() * 3600000)
        end
    end
    return 0
end

local function allSubtasksDone(task)
    for _, subtask in ipairs(task.subtasks or {}) do
        if not subtask.done then
            return false
        end
    end
    return true
end

local function getArrivalRadius()
    local options = SandboxVars and SandboxVars.SurvivalPlannerList or nil
    return math.max(
        1,
        math.min(MAX_ARRIVAL_RADIUS, tonumber(options and options.ArrivalRadius) or DEFAULT_ARRIVAL_RADIUS)
    )
end

local function getScanIntervalMs()
    local options = SandboxVars and SandboxVars.SurvivalPlannerList or nil
    local seconds = tonumber(options and options.InventoryScanInterval)
        or DEFAULT_SCAN_INTERVAL_SECONDS
    seconds = math.max(
        MIN_SCAN_INTERVAL_SECONDS,
        math.min(MAX_SCAN_INTERVAL_SECONDS, seconds)
    )
    return math.floor(seconds * 1000)
end

local function isPlayerAtTarget(player, target, radius)
    if not player or type(target) ~= "table" then
        return false
    end

    local targetX = tonumber(target.x)
    local targetY = tonumber(target.y)
    if not targetX or not targetY then
        return false
    end

    local playerZ = math.floor(tonumber(player:getZ()) or 0)
    local targetZ = math.floor(tonumber(target.z) or 0)
    if playerZ ~= targetZ then
        return false
    end

    local dx = player:getX() - targetX
    local dy = player:getY() - targetY
    return dx * dx + dy * dy <= radius * radius
end

function Automation.evaluatePlanner(planner, counts, canWrite, player, arrivalRadius)
    local data = SurvivalPlannerList.getData(planner)
    if not data or not canWrite then
        return false, {}
    end

    local changed = false
    local completedTitles = {}
    local completedTaskIds = {}
    local completedAt = SurvivalPlannerList.now()
    arrivalRadius = tonumber(arrivalRadius) or getArrivalRadius()

    for _, task in ipairs(data.tasks or {}) do
        if task.status == SurvivalPlannerList.STATUS_ACTIVE then
            for _, subtask in ipairs(task.subtasks or {}) do
                if not subtask.done
                    and subtask.autoComplete
                    and #(subtask.goals or {}) > 0
                    and SurvivalPlannerList.areGoalsMet(subtask.goals, counts) then
                    subtask.done = true
                    subtask.completedAt = completedAt
                    subtask.completedBy = "automatic"
                    changed = true
                end
            end

            local mapTarget = SurvivalPlannerList.getTaskMapTarget(task)
            local completedByArrival = task.autoCompleteOnArrival == true
                and mapTarget
                and isPlayerAtTarget(player, mapTarget, arrivalRadius)
            local hasConditions = #(task.goals or {}) > 0 or #(task.subtasks or {}) > 0
            local completedByItems = task.autoComplete
                and hasConditions
                and SurvivalPlannerList.areGoalsMet(task.goals, counts)
                and allSubtasksDone(task)
            if completedByArrival or completedByItems then
                task.status = SurvivalPlannerList.STATUS_DONE
                task.completedAt = completedAt
                task.completedBy = completedByArrival and "arrival" or "automatic"
                task.navigationEnabled = false
                table.insert(completedTitles, task.title)
                table.insert(completedTaskIds, task.id)
                changed = true
            end
        end
    end

    for index = #completedTaskIds, 1, -1 do
        SurvivalPlannerList.moveTaskToFront(data, completedTaskIds[index])
    end

    return changed, completedTitles
end

local function refreshOpenPanels(playerNum)
    if not SPLMainPanel or not SPLMainPanel.instances then
        return
    end
    local panel = SPLMainPanel.instances[playerNum + 1]
    if panel and panel:getIsVisible() then
        panel:refreshList()
    end
end

local function showCompletionHalo(player, completedTitles)
    if #completedTitles == 0 then
        return
    end

    local message
    local oneCompleted = getText("IGUI_SPL_Auto_TaskCompleted")
    local manyCompleted = getText("IGUI_SPL_Auto_TasksCompleted")
    if not oneCompleted or oneCompleted == "IGUI_SPL_Auto_TaskCompleted" then
        oneCompleted = "Plan completed"
    end
    if not manyCompleted or manyCompleted == "IGUI_SPL_Auto_TasksCompleted" then
        manyCompleted = "Plans completed"
    end
    if #completedTitles == 1 then
        message = oneCompleted .. ": " .. completedTitles[1]
    else
        message = manyCompleted .. ": " .. tostring(#completedTitles)
    end
    if player and player.setHaloNote then
        player:setHaloNote(message, 155, 205, 105, 300)
    elseif HaloTextHelper and HaloTextHelper.addText then
        HaloTextHelper.addText(player, message)
    end
end

function Automation.scanPlayer(player)
    if not player or not player.getInventory then
        return nil
    end

    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    local counts = {}
    local planners = {}
    local hasWritingTool = false
    local hasEraser = false

    SurvivalPlannerList.visitPlayerInventory(player, function(item)
        local fullType = item and item.getFullType and item:getFullType() or nil
        if fullType then
            counts[fullType] = (counts[fullType] or 0) + 1
        end
        if SurvivalPlannerList.isPlanner(item) then
            table.insert(planners, item)
        end
        if not hasWritingTool and SurvivalPlannerList.isWritingTool(item) then
            hasWritingTool = true
        end
        if not hasEraser and SurvivalPlannerList.isEraser(item) then
            hasEraser = true
        end
        return nil
    end)

    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if not hasWritingTool then
        hasWritingTool = SurvivalPlannerList.isWritingTool(primary)
            or SurvivalPlannerList.isWritingTool(secondary)
    end
    if not hasEraser then
        hasEraser = SurvivalPlannerList.isEraser(primary)
            or SurvivalPlannerList.isEraser(secondary)
    end

    Automation.snapshots[playerNum + 1] = {
        at = timestampMs(),
        counts = counts,
        planners = planners,
        hasWritingTool = hasWritingTool,
        hasEraser = hasEraser,
    }

    local anyChanged = false
    local completedTitles = {}
    local canWrite = hasWritingTool and hasEraser
    local arrivalRadius = getArrivalRadius()
    for _, planner in ipairs(planners) do
        local changed, plannerCompletions = Automation.evaluatePlanner(
            planner,
            counts,
            canWrite,
            player,
            arrivalRadius
        )
        if changed then
            SurvivalPlannerList.save(planner)
            anyChanged = true
        end
        for _, title in ipairs(plannerCompletions) do
            table.insert(completedTitles, title)
        end
    end

    if anyChanged then
        refreshOpenPanels(playerNum)
        showCompletionHalo(player, completedTitles)
        if getSoundManager then
            getSoundManager():playUISound("UIActivateButton")
        end
    end
    return Automation.snapshots[playerNum + 1]
end

function Automation.getSnapshot(playerNum)
    return Automation.snapshots[(playerNum or 0) + 1]
end

function Automation.getCounts(playerNum)
    local snapshot = Automation.getSnapshot(playerNum)
    return snapshot and snapshot.counts or {}
end

function Automation.getPlanners(playerNum)
    local snapshot = Automation.getSnapshot(playerNum)
    return snapshot and snapshot.planners or {}
end

function Automation.getEditAccess(playerNum)
    local snapshot = Automation.getSnapshot(playerNum)
    if not snapshot then
        return false, false, false
    end
    return snapshot.hasWritingTool and snapshot.hasEraser,
        snapshot.hasWritingTool == true,
        snapshot.hasEraser == true
end

function Automation.getScanIntervalMs()
    return getScanIntervalMs()
end

function Automation.onPlayerUpdate(player)
    if not player then
        return
    end
    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    local index = playerNum + 1
    local now = timestampMs()
    if Automation.lastChecks[index]
        and now - Automation.lastChecks[index] < getScanIntervalMs() then
        return
    end
    Automation.lastChecks[index] = now
    Automation.scanPlayer(player)
end

Events.OnPlayerUpdate.Add(Automation.onPlayerUpdate)

return Automation
