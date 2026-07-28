require "SurvivalPlannerList/SurvivalPlannerList_Core"

SurvivalPlannerList.Automation = SurvivalPlannerList.Automation or {}

local Automation = SurvivalPlannerList.Automation
local CHECK_INTERVAL_MS = 900

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

function Automation.evaluatePlanner(planner, counts, canWrite)
    local data = SurvivalPlannerList.getData(planner)
    if not data or not canWrite then
        return false, {}
    end

    local changed = false
    local completedTitles = {}
    local completedAt = SurvivalPlannerList.now()

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

            local hasConditions = #(task.goals or {}) > 0 or #(task.subtasks or {}) > 0
            if task.autoComplete
                and hasConditions
                and SurvivalPlannerList.areGoalsMet(task.goals, counts)
                and allSubtasksDone(task) then
                task.status = SurvivalPlannerList.STATUS_DONE
                task.completedAt = completedAt
                task.completedBy = "automatic"
                table.insert(completedTitles, task.title)
                changed = true
            end
        end
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
    if #completedTitles == 0 or not HaloTextHelper or not HaloTextHelper.addText then
        return
    end

    local message
    local oneCompleted = getText("SPL_Auto_TaskCompleted")
    local manyCompleted = getText("SPL_Auto_TasksCompleted")
    if not oneCompleted or oneCompleted == "SPL_Auto_TaskCompleted" then
        oneCompleted = "Task completed"
    end
    if not manyCompleted or manyCompleted == "SPL_Auto_TasksCompleted" then
        manyCompleted = "Planner tasks completed"
    end
    if #completedTitles == 1 then
        message = oneCompleted .. ": " .. completedTitles[1]
    else
        message = manyCompleted .. ": " .. tostring(#completedTitles)
    end
    HaloTextHelper.addText(player, message)
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
        hasWritingTool = hasWritingTool,
        hasEraser = hasEraser,
    }

    local anyChanged = false
    local completedTitles = {}
    local canWrite = hasWritingTool and hasEraser
    for _, planner in ipairs(planners) do
        local changed, plannerCompletions = Automation.evaluatePlanner(planner, counts, canWrite)
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

function Automation.onPlayerUpdate(player)
    if not player then
        return
    end
    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    local index = playerNum + 1
    local now = timestampMs()
    if Automation.lastChecks[index] and now - Automation.lastChecks[index] < CHECK_INTERVAL_MS then
        return
    end
    Automation.lastChecks[index] = now
    Automation.scanPlayer(player)
end

Events.OnPlayerUpdate.Add(Automation.onPlayerUpdate)

return Automation
