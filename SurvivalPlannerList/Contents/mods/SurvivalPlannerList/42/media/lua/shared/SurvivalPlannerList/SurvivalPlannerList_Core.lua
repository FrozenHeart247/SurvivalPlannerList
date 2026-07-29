SurvivalPlannerList = SurvivalPlannerList or {}

SurvivalPlannerList.ID = "SurvivalPlannerList"
SurvivalPlannerList.ITEM_TYPE = "SurvivalPlannerList.SurvivalPlanner"
SurvivalPlannerList.DATA_VERSION = 3
SurvivalPlannerList.DEFAULT_ICON = "Base.Notebook"
SurvivalPlannerList.STATUS_ACTIVE = "active"
SurvivalPlannerList.STATUS_PLANNED = "planned"
SurvivalPlannerList.STATUS_DONE = "done"

SurvivalPlannerList.WRITING_TOOLS = {
    ["Base.Pen"] = true,
    ["Base.BluePen"] = true,
    ["Base.GreenPen"] = true,
    ["Base.RedPen"] = true,
    ["Base.Pencil"] = true,
    ["Base.PencilSpiffo"] = true,
    ["Base.PenFancy"] = true,
    ["Base.PenMultiColor"] = true,
    ["Base.PenSpiffo"] = true,
    ["Base.PenLight"] = true,
}

local VALID_STATUSES = {
    [SurvivalPlannerList.STATUS_ACTIVE] = true,
    [SurvivalPlannerList.STATUS_PLANNED] = true,
    [SurvivalPlannerList.STATUS_DONE] = true,
}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$") or ""
end

local function safeNow()
    if getGameTime then
        local gameTime = getGameTime()
        if gameTime and gameTime.getWorldAgeHours then
            return gameTime:getWorldAgeHours()
        end
    end
    return 0
end

local plannerIdCounter = 0

local function newPlannerId()
    plannerIdCounter = plannerIdCounter + 1
    local stamp = getTimestampMs and getTimestampMs() or math.floor(safeNow() * 3600000)
    local randomPart = ZombRand and ZombRand(1000000) or math.random(0, 999999)
    return tostring(stamp) .. "-" .. tostring(randomPart) .. "-" .. tostring(plannerIdCounter)
end

local function inventoryItems(container)
    if not container or not container.getItems then
        return nil
    end
    return container:getItems()
end

local function itemFullType(item)
    if not item then
        return nil
    end
    if item.getFullType then
        return item:getFullType()
    end
    return nil
end

local function visitContainer(container, visitor, visited)
    if not container or type(visitor) ~= "function" then
        return nil
    end

    visited = visited or {}
    if visited[container] then
        return nil
    end
    visited[container] = true

    local items = inventoryItems(container)
    if not items or not items.size or not items.get then
        return nil
    end

    for index = 0, items:size() - 1 do
        local item = items:get(index)
        local result = visitor(item)
        if result ~= nil then
            return result
        end

        local nested = item and item.getInventory and item:getInventory() or nil
        if nested then
            result = visitContainer(nested, visitor, visited)
            if result ~= nil then
                return result
            end
        end
    end

    return nil
end

function SurvivalPlannerList.trim(value)
    return trim(value)
end

function SurvivalPlannerList.now()
    return safeNow()
end

function SurvivalPlannerList.isPlanner(item)
    return itemFullType(item) == SurvivalPlannerList.ITEM_TYPE
end

function SurvivalPlannerList.visitPlayerInventory(player, visitor)
    if not player or not player.getInventory then
        return nil
    end
    return visitContainer(player:getInventory(), visitor, {})
end

function SurvivalPlannerList.findPlayerItem(player, predicate)
    if not player or type(predicate) ~= "function" then
        return nil
    end

    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    if primary and predicate(primary) then
        return primary
    end

    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if secondary and secondary ~= primary and predicate(secondary) then
        return secondary
    end

    return SurvivalPlannerList.visitPlayerInventory(player, function(item)
        if predicate(item) then
            return item
        end
        return nil
    end)
end

function SurvivalPlannerList.isWritingTool(item)
    local fullType = itemFullType(item)
    if fullType and SurvivalPlannerList.WRITING_TOOLS[fullType] then
        return true
    end

    -- Build 42.19 exposes namespaced item tags through ItemTag enums.
    -- Passing the enum (rather than a raw string) also supports modded pens.
    if ItemTag and ItemTag.WRITE and item and item.hasTag and item:hasTag(ItemTag.WRITE) then
        return true
    end

    local bareType = fullType and fullType:match("^[^%.]+%.(.+)$") or nil
    return bareType ~= nil and (bareType:match("^Pen") or bareType:match("^Pencil")) ~= nil
end

function SurvivalPlannerList.isEraser(item)
    if itemFullType(item) == "Base.Eraser" then
        return true
    end
    return ItemTag
        and ItemTag.ERASER
        and item
        and item.hasTag
        and item:hasTag(ItemTag.ERASER)
        or false
end

function SurvivalPlannerList.findWritingTool(player)
    return SurvivalPlannerList.findPlayerItem(player, SurvivalPlannerList.isWritingTool)
end

function SurvivalPlannerList.findEraser(player)
    return SurvivalPlannerList.findPlayerItem(player, SurvivalPlannerList.isEraser)
end

function SurvivalPlannerList.hasWritingTool(player)
    return SurvivalPlannerList.findWritingTool(player) ~= nil
end

function SurvivalPlannerList.hasEraser(player)
    return SurvivalPlannerList.findEraser(player) ~= nil
end

function SurvivalPlannerList.getEditAccess(player)
    local hasWritingTool = SurvivalPlannerList.hasWritingTool(player)
    local hasEraser = SurvivalPlannerList.hasEraser(player)
    return hasWritingTool and hasEraser, hasWritingTool, hasEraser
end

local function nextId(data)
    local id = math.max(1, tonumber(data.nextId) or 1)
    data.nextId = id + 1
    return id
end

local function normalizeGoal(raw)
    if type(raw) ~= "table" then
        return nil
    end

    local fullType = trim(raw.fullType)
    if fullType == "" then
        fullType = trim(raw.targetType)
    end
    if fullType == "" then
        return nil
    end

    local name = trim(raw.name)
    if name == "" then
        name = trim(raw.targetName)
    end

    return {
        kind = "item",
        fullType = fullType,
        name = name ~= "" and name or fullType,
        quantity = math.max(1, math.min(9999, math.floor(tonumber(raw.quantity) or 1))),
    }
end

local function normalizeGoals(rawGoals)
    local goals = {}
    local byType = {}
    if type(rawGoals) ~= "table" then
        return goals
    end

    for _, rawGoal in ipairs(rawGoals) do
        local goal = normalizeGoal(rawGoal)
        if goal then
            local existing = byType[goal.fullType]
            if existing then
                existing.quantity = math.max(existing.quantity, goal.quantity)
                if existing.name == existing.fullType and goal.name ~= goal.fullType then
                    existing.name = goal.name
                end
            else
                byType[goal.fullType] = goal
                table.insert(goals, goal)
            end
        end
    end
    return goals
end

function SurvivalPlannerList.copyGoals(rawGoals)
    return normalizeGoals(rawGoals)
end

local function normalizeMapTarget(data, raw)
    if type(raw) ~= "table" then
        return nil
    end

    local x = tonumber(raw.x)
    local y = tonumber(raw.y)
    if not x or not y or x ~= x or y ~= y then
        return nil
    end

    local id = tonumber(raw.id)
    if not id or id < 1 then
        id = nextId(data)
    elseif id >= (tonumber(data.nextId) or 1) then
        data.nextId = id + 1
    end

    return {
        id = id,
        name = trim(raw.name),
        x = x,
        y = y,
        z = math.floor(tonumber(raw.z) or 0),
        radius = math.max(1, math.min(500, tonumber(raw.radius) or 15)),
    }
end

local function normalizeMapTargets(data, rawTargets, legacyTarget)
    local targets = {}
    local source = rawTargets
    if type(source) ~= "table" or #source == 0 then
        source = type(legacyTarget) == "table" and {legacyTarget} or {}
    end

    local seenIds = {}
    for _, rawTarget in ipairs(source) do
        local target = normalizeMapTarget(data, rawTarget)
        if target and not seenIds[target.id] then
            seenIds[target.id] = true
            table.insert(targets, target)
        end
    end
    return targets
end

function SurvivalPlannerList.copyMapTargets(rawTargets)
    local targets = {}
    if type(rawTargets) ~= "table" then
        return targets
    end
    for _, raw in ipairs(rawTargets) do
        if type(raw) == "table" and tonumber(raw.x) and tonumber(raw.y) then
            table.insert(targets, {
                id = tonumber(raw.id),
                name = trim(raw.name),
                x = tonumber(raw.x),
                y = tonumber(raw.y),
                z = math.floor(tonumber(raw.z) or 0),
                radius = math.max(1, math.min(500, tonumber(raw.radius) or 15)),
            })
        end
    end
    return targets
end

function SurvivalPlannerList.areGoalsMet(goals, counts)
    if type(goals) ~= "table" or #goals == 0 then
        return true
    end
    counts = counts or {}
    for _, goal in ipairs(goals) do
        if (tonumber(counts[goal.fullType]) or 0) < (tonumber(goal.quantity) or 1) then
            return false
        end
    end
    return true
end

local function normalizeSubtask(data, raw)
    if type(raw) ~= "table" then
        return nil
    end

    local title = trim(raw.title)
    if title == "" then
        return nil
    end

    local id = tonumber(raw.id)
    if not id or id < 1 then
        id = nextId(data)
    elseif id >= (tonumber(data.nextId) or 1) then
        data.nextId = id + 1
    end

    local subtask = {
        id = id,
        title = title,
        done = raw.done == true,
        goals = normalizeGoals(raw.goals),
        autoComplete = raw.autoComplete == true,
        completedAt = tonumber(raw.completedAt),
        completedBy = trim(raw.completedBy) ~= "" and trim(raw.completedBy) or nil,
    }
    if not subtask.done then
        subtask.completedAt = nil
        subtask.completedBy = nil
    end
    return subtask
end

local function normalizeTask(data, raw)
    if type(raw) ~= "table" then
        return nil
    end

    local title = trim(raw.title)
    if title == "" then
        return nil
    end

    local id = tonumber(raw.id)
    if not id or id < 1 then
        id = nextId(data)
    elseif id >= (tonumber(data.nextId) or 1) then
        data.nextId = id + 1
    end

    local task = {
        id = id,
        title = title,
        status = VALID_STATUSES[raw.status] and raw.status or SurvivalPlannerList.STATUS_ACTIVE,
        iconType = trim(raw.iconType) ~= "" and trim(raw.iconType) or SurvivalPlannerList.DEFAULT_ICON,
        createdAt = tonumber(raw.createdAt) or safeNow(),
        completedAt = tonumber(raw.completedAt),
        completedBy = trim(raw.completedBy) ~= "" and trim(raw.completedBy) or nil,
        autoComplete = raw.autoComplete == true,
        goals = normalizeGoals(raw.goals),
        mapTargets = normalizeMapTargets(data, raw.mapTargets, raw.mapTarget),
        trackedTargetId = tonumber(raw.trackedTargetId),
        navigationEnabled = raw.navigationEnabled == true,
        subtasks = {},
    }

    local trackedTargetFound = false
    for _, target in ipairs(task.mapTargets) do
        if tonumber(target.id) == task.trackedTargetId then
            trackedTargetFound = true
            break
        end
    end
    if not trackedTargetFound then
        task.trackedTargetId = task.mapTargets[1] and task.mapTargets[1].id or nil
    end
    if task.status == SurvivalPlannerList.STATUS_DONE or not task.trackedTargetId then
        task.navigationEnabled = false
    end

    if #task.goals == 0 and trim(raw.targetType) ~= "" then
        table.insert(task.goals, normalizeGoal({
            fullType = raw.targetType,
            name = raw.targetName,
            quantity = raw.targetQuantity,
        }))
    end

    if type(raw.subtasks) == "table" then
        for _, rawSubtask in ipairs(raw.subtasks) do
            local subtask = normalizeSubtask(data, rawSubtask)
            if subtask then
                table.insert(task.subtasks, subtask)
            end
        end
    end

    if task.status ~= SurvivalPlannerList.STATUS_DONE then
        task.completedAt = nil
        task.completedBy = nil
    end

    return task
end

local function normalizeTrackedItem(raw)
    if type(raw) ~= "table" then
        return nil
    end

    local fullType = trim(raw.fullType)
    if fullType == "" then
        return nil
    end

    return {
        fullType = fullType,
        name = trim(raw.name) ~= "" and trim(raw.name) or fullType,
    }
end

local function normalizeData(data)
    if type(data) ~= "table" then
        data = {}
    end

    data.version = SurvivalPlannerList.DATA_VERSION
    data.nextId = math.max(1, tonumber(data.nextId) or 1)
    data.plannerId = trim(data.plannerId)
    if data.plannerId == "" then
        data.plannerId = newPlannerId()
    end

    local tasks = {}
    if type(data.tasks) == "table" then
        for _, rawTask in ipairs(data.tasks) do
            local task = normalizeTask(data, rawTask)
            if task then
                table.insert(tasks, task)
            end
        end
    end
    data.tasks = tasks

    local trackedItems = {}
    local seenTypes = {}
    if type(data.trackedItems) == "table" then
        for _, rawTrackedItem in ipairs(data.trackedItems) do
            local trackedItem = normalizeTrackedItem(rawTrackedItem)
            if trackedItem and not seenTypes[trackedItem.fullType] then
                seenTypes[trackedItem.fullType] = true
                table.insert(trackedItems, trackedItem)
            end
        end
    end
    data.trackedItems = trackedItems

    return data
end

function SurvivalPlannerList.getData(planner)
    if not SurvivalPlannerList.isPlanner(planner) or not planner.getModData then
        return nil
    end

    local modData = planner:getModData()
    modData.SurvivalPlannerList = normalizeData(modData.SurvivalPlannerList)
    return modData.SurvivalPlannerList
end

function SurvivalPlannerList.save(planner)
    local data = SurvivalPlannerList.getData(planner)
    if not data then
        return false
    end

    data.updatedAt = safeNow()
    SurvivalPlannerList.invalidateTrackingCache()
    if planner.transmitModData then
        planner:transmitModData()
    end
    if triggerEvent then
        triggerEvent("OnContainerUpdate")
    end
    return true
end

function SurvivalPlannerList.findTask(data, taskId)
    if type(data) ~= "table" or type(data.tasks) ~= "table" then
        return nil, nil
    end

    taskId = tonumber(taskId)
    for index, task in ipairs(data.tasks) do
        if tonumber(task.id) == taskId then
            return task, index
        end
    end
    return nil, nil
end

function SurvivalPlannerList.getPlannerKey(planner)
    local data = SurvivalPlannerList.getData(planner)
    return data and data.plannerId or nil
end

function SurvivalPlannerList.getTaskMapTarget(task)
    if type(task) ~= "table" or type(task.mapTargets) ~= "table" then
        return nil
    end

    local trackedTargetId = tonumber(task.trackedTargetId)
    for _, target in ipairs(task.mapTargets) do
        if tonumber(target.id) == trackedTargetId then
            return target
        end
    end
    return task.mapTargets[1]
end

function SurvivalPlannerList.moveTaskToFront(data, taskId)
    local task, index = SurvivalPlannerList.findTask(data, taskId)
    if not task or not index or index == 1 then
        return task ~= nil
    end
    table.remove(data.tasks, index)
    table.insert(data.tasks, 1, task)
    return true
end

function SurvivalPlannerList.addTask(planner, values)
    local data = SurvivalPlannerList.getData(planner)
    if not data or type(values) ~= "table" then
        return nil
    end

    local title = trim(values.title)
    if title == "" then
        return nil
    end

    local task = {
        id = nextId(data),
        title = title,
        status = values.status == SurvivalPlannerList.STATUS_PLANNED
            and SurvivalPlannerList.STATUS_PLANNED
            or SurvivalPlannerList.STATUS_ACTIVE,
        iconType = trim(values.iconType) ~= "" and trim(values.iconType) or SurvivalPlannerList.DEFAULT_ICON,
        goals = normalizeGoals(values.goals),
        mapTargets = normalizeMapTargets(data, values.mapTargets, values.mapTarget),
        trackedTargetId = tonumber(values.trackedTargetId),
        navigationEnabled = values.navigationEnabled == true,
        autoComplete = values.autoComplete == true,
        createdAt = safeNow(),
        completedAt = nil,
        subtasks = {},
    }
    if #task.mapTargets > 0 then
        local trackedTargetFound = false
        for _, target in ipairs(task.mapTargets) do
            if tonumber(target.id) == task.trackedTargetId then
                trackedTargetFound = true
                break
            end
        end
        task.trackedTargetId = trackedTargetFound and task.trackedTargetId or task.mapTargets[1].id
    else
        task.trackedTargetId = nil
        task.navigationEnabled = false
    end
    table.insert(data.tasks, 1, task)
    SurvivalPlannerList.save(planner)
    return task
end

function SurvivalPlannerList.updateTask(planner, taskId, values)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    if not task or type(values) ~= "table" then
        return false
    end

    local title = trim(values.title)
    if title == "" then
        return false
    end

    task.title = title
    task.iconType = trim(values.iconType) ~= "" and trim(values.iconType) or SurvivalPlannerList.DEFAULT_ICON
    task.goals = normalizeGoals(values.goals)
    task.mapTargets = normalizeMapTargets(data, values.mapTargets, values.mapTarget)
    task.trackedTargetId = tonumber(values.trackedTargetId)
    local trackedTargetFound = false
    for _, target in ipairs(task.mapTargets) do
        if tonumber(target.id) == task.trackedTargetId then
            trackedTargetFound = true
            break
        end
    end
    task.trackedTargetId = trackedTargetFound
        and task.trackedTargetId
        or (task.mapTargets[1] and task.mapTargets[1].id or nil)
    task.navigationEnabled = values.navigationEnabled == true
        and task.status ~= SurvivalPlannerList.STATUS_DONE
        and task.trackedTargetId ~= nil
    task.autoComplete = values.autoComplete == true
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.setTaskIcon(planner, taskId, iconType)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    iconType = trim(iconType)
    if not task or iconType == "" then
        return false
    end
    task.iconType = iconType
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.setTaskStatus(planner, taskId, status)
    if not VALID_STATUSES[status] then
        return false
    end

    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    if not task then
        return false
    end

    task.status = status
    task.completedAt = status == SurvivalPlannerList.STATUS_DONE and safeNow() or nil
    task.completedBy = status == SurvivalPlannerList.STATUS_DONE and "manual" or nil
    if status == SurvivalPlannerList.STATUS_DONE then
        task.navigationEnabled = false
        SurvivalPlannerList.moveTaskToFront(data, task.id)
    end
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.setTaskNavigation(planner, taskId, enabled)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    local target = task and SurvivalPlannerList.getTaskMapTarget(task) or nil
    if not task or task.status == SurvivalPlannerList.STATUS_DONE or not target then
        return false
    end
    task.navigationEnabled = enabled == true
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.reorderTask(planner, taskId, dropIndex)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    if not task or (
        task.status ~= SurvivalPlannerList.STATUS_ACTIVE
        and task.status ~= SurvivalPlannerList.STATUS_PLANNED
    ) then
        return false
    end

    local statusTasks = {}
    local sourceIndex = nil
    for _, candidate in ipairs(data.tasks) do
        if candidate.status == task.status then
            table.insert(statusTasks, candidate)
            if tonumber(candidate.id) == tonumber(task.id) then
                sourceIndex = #statusTasks
            end
        end
    end
    if not sourceIndex or #statusTasks < 2 then
        return false
    end

    dropIndex = math.max(1, math.min(#statusTasks + 1, tonumber(dropIndex) or sourceIndex))
    local insertIndex = dropIndex
    if sourceIndex < dropIndex then
        insertIndex = insertIndex - 1
    end
    if insertIndex == sourceIndex then
        return false
    end

    table.remove(statusTasks, sourceIndex)
    table.insert(statusTasks, insertIndex, task)

    local statusIndex = 1
    for index, candidate in ipairs(data.tasks) do
        if candidate.status == task.status then
            data.tasks[index] = statusTasks[statusIndex]
            statusIndex = statusIndex + 1
        end
    end
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.deleteTask(planner, taskId)
    local data = SurvivalPlannerList.getData(planner)
    local index = nil
    if data then
        local ignored
        ignored, index = SurvivalPlannerList.findTask(data, taskId)
    end
    if not data or not index then
        return false
    end

    table.remove(data.tasks, index)
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.clearDone(planner)
    local data = SurvivalPlannerList.getData(planner)
    if not data then
        return false
    end

    local kept = {}
    for _, task in ipairs(data.tasks) do
        if task.status ~= SurvivalPlannerList.STATUS_DONE then
            table.insert(kept, task)
        end
    end
    data.tasks = kept
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.addSubtask(planner, taskId, values)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    if type(values) ~= "table" then
        values = {title = values}
    end
    local title = trim(values.title)
    if not task or title == "" then
        return false
    end

    table.insert(task.subtasks, {
        id = nextId(data),
        title = title,
        done = false,
        goals = normalizeGoals(values.goals),
        autoComplete = values.autoComplete == true,
        completedAt = nil,
        completedBy = nil,
    })
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.findSubtask(task, subtaskId)
    if type(task) ~= "table" or type(task.subtasks) ~= "table" then
        return nil, nil
    end

    subtaskId = tonumber(subtaskId)
    for index, subtask in ipairs(task.subtasks) do
        if tonumber(subtask.id) == subtaskId then
            return subtask, index
        end
    end
    return nil, nil
end

function SurvivalPlannerList.toggleSubtask(planner, taskId, subtaskId)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    local subtask = task and SurvivalPlannerList.findSubtask(task, subtaskId) or nil
    if not subtask then
        return false
    end

    subtask.done = not subtask.done
    subtask.completedAt = subtask.done and safeNow() or nil
    subtask.completedBy = subtask.done and "manual" or nil
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.updateSubtask(planner, taskId, subtaskId, values)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    local subtask = task and SurvivalPlannerList.findSubtask(task, subtaskId) or nil
    if not subtask or type(values) ~= "table" then
        return false
    end

    local title = trim(values.title)
    if title == "" then
        return false
    end

    subtask.title = title
    subtask.goals = normalizeGoals(values.goals)
    subtask.autoComplete = values.autoComplete == true
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.deleteSubtask(planner, taskId, subtaskId)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    local _, index = nil, nil
    if task then
        _, index = SurvivalPlannerList.findSubtask(task, subtaskId)
    end
    if not task or not index then
        return false
    end

    table.remove(task.subtasks, index)
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.addTrackedItem(planner, fullType, name)
    local data = SurvivalPlannerList.getData(planner)
    fullType = trim(fullType)
    if not data or fullType == "" then
        return false
    end

    for _, trackedItem in ipairs(data.trackedItems) do
        if trackedItem.fullType == fullType then
            return false
        end
    end

    table.insert(data.trackedItems, {
        fullType = fullType,
        name = trim(name) ~= "" and trim(name) or fullType,
    })
    return SurvivalPlannerList.save(planner)
end

function SurvivalPlannerList.removeTrackedItem(planner, fullType)
    local data = SurvivalPlannerList.getData(planner)
    fullType = trim(fullType)
    if not data or fullType == "" then
        return false
    end

    for index, trackedItem in ipairs(data.trackedItems) do
        if trackedItem.fullType == fullType then
            table.remove(data.trackedItems, index)
            return SurvivalPlannerList.save(planner)
        end
    end
    return false
end

SurvivalPlannerList._itemCatalog = SurvivalPlannerList._itemCatalog or nil
SurvivalPlannerList._itemCatalogByType = SurvivalPlannerList._itemCatalogByType or {}
SurvivalPlannerList.CUSTOM_ICONS = SurvivalPlannerList.CUSTOM_ICONS or {}
SurvivalPlannerList._customIconsById = SurvivalPlannerList._customIconsById or {}

function SurvivalPlannerList.registerTaskIcon(iconId, texturePath, nameKey, fallbackName)
    iconId = trim(iconId)
    texturePath = trim(texturePath)
    if iconId == "" or texturePath == "" then
        return false
    end

    local entry = SurvivalPlannerList._customIconsById[iconId]
    if not entry then
        entry = {
            fullType = iconId,
            isCustomIcon = true,
        }
        SurvivalPlannerList._customIconsById[iconId] = entry
        table.insert(SurvivalPlannerList.CUSTOM_ICONS, entry)
    end
    entry.texturePath = texturePath
    entry.nameKey = trim(nameKey)
    entry.fallbackName = trim(fallbackName) ~= "" and trim(fallbackName) or iconId
    entry.texture = nil
    return true
end

SurvivalPlannerList.registerTaskIcon(
    "SPL.Icon.Travel",
    "media/textures/SPL_Icon_Travel.png",
    "SPL_Icon_Travel",
    "Travel"
)
SurvivalPlannerList.registerTaskIcon(
    "SPL.Icon.Animals",
    "media/textures/SPL_Icon_Animals.png",
    "SPL_Icon_Animals",
    "Animals"
)
SurvivalPlannerList.registerTaskIcon(
    "SPL.Icon.Car",
    "media/textures/SPL_Icon_Car.png",
    "SPL_Icon_Car",
    "Vehicle"
)
SurvivalPlannerList.registerTaskIcon(
    "SPL.Icon.Unknown",
    "media/textures/SPL_Icon_Unknow.png",
    "SPL_Icon_Unknown",
    "Unknown"
)
SurvivalPlannerList.registerTaskIcon(
    "SPL.Icon.CheckLocation",
    "media/textures/SPL_Icon_CheckLocation.png",
    "SPL_Icon_CheckLocation",
    "Check location"
)

local function customIconName(entry)
    if getText and entry.nameKey ~= "" then
        local translated = getText(entry.nameKey)
        if translated and translated ~= entry.nameKey then
            return translated
        end
    end
    return entry.fallbackName or entry.fullType
end

function SurvivalPlannerList.getCustomIconCatalog()
    for _, entry in ipairs(SurvivalPlannerList.CUSTOM_ICONS) do
        entry.name = customIconName(entry)
        if not entry.texture and getTexture then
            entry.texture = getTexture(entry.texturePath)
        end
    end
    return SurvivalPlannerList.CUSTOM_ICONS
end

function SurvivalPlannerList.getIconCatalog()
    local catalog = {}
    for _, entry in ipairs(SurvivalPlannerList.getCustomIconCatalog()) do
        if entry.texture then
            table.insert(catalog, entry)
        end
    end
    for _, entry in ipairs(SurvivalPlannerList.getItemCatalog()) do
        table.insert(catalog, entry)
    end
    return catalog
end

function SurvivalPlannerList.getItemCatalog()
    if SurvivalPlannerList._itemCatalog then
        return SurvivalPlannerList._itemCatalog
    end

    local catalog = {}
    local byType = {}
    if getAllItems then
        local allItems = getAllItems()
        if allItems and allItems.size and allItems.get then
            for index = 0, allItems:size() - 1 do
                local scriptItem = allItems:get(index)
                if scriptItem and not scriptItem:getObsolete() and not scriptItem:isHidden() then
                    local fullType = scriptItem:getFullName()
                    local texture = scriptItem.getNormalTexture and scriptItem:getNormalTexture() or nil
                    if fullType and fullType ~= "" and texture and texture:getName() ~= "Question_On" and not byType[fullType] then
                        local entry = {
                            fullType = fullType,
                            name = scriptItem:getDisplayName() or fullType,
                            texture = texture,
                            scriptItem = scriptItem,
                        }
                        byType[fullType] = entry
                        table.insert(catalog, entry)
                    end
                end
            end
        end
    end

    table.sort(catalog, function(a, b)
        local left = string.lower(a.name or a.fullType)
        local right = string.lower(b.name or b.fullType)
        if left == right then
            return a.fullType < b.fullType
        end
        return left < right
    end)

    SurvivalPlannerList._itemCatalog = catalog
    SurvivalPlannerList._itemCatalogByType = byType
    return catalog
end

function SurvivalPlannerList.getCatalogEntry(fullType)
    fullType = trim(fullType)
    if fullType == "" then
        return nil
    end

    local entry = SurvivalPlannerList._customIconsById[fullType]
    if entry then
        entry.name = customIconName(entry)
        if not entry.texture and getTexture then
            entry.texture = getTexture(entry.texturePath)
        end
        return entry
    end

    SurvivalPlannerList.getItemCatalog()
    entry = SurvivalPlannerList._itemCatalogByType[fullType]
    if entry then
        return entry
    end

    if getScriptManager then
        local scriptItem = getScriptManager():FindItem(fullType)
        if scriptItem then
            entry = {
                fullType = fullType,
                name = scriptItem:getDisplayName() or fullType,
                texture = scriptItem.getNormalTexture and scriptItem:getNormalTexture() or nil,
                scriptItem = scriptItem,
            }
            SurvivalPlannerList._itemCatalogByType[fullType] = entry
            return entry
        end
    end
    return nil
end

function SurvivalPlannerList.getItemTexture(fullType)
    local entry = SurvivalPlannerList.getCatalogEntry(fullType)
    return entry and entry.texture or nil
end

function SurvivalPlannerList.getItemName(fullType)
    local entry = SurvivalPlannerList.getCatalogEntry(fullType)
    return entry and entry.name or fullType
end

SurvivalPlannerList._trackingCache = SurvivalPlannerList._trackingCache or {}
SurvivalPlannerList._trackingRevision = SurvivalPlannerList._trackingRevision or 0

function SurvivalPlannerList.invalidateTrackingCache()
    SurvivalPlannerList._trackingCache = {}
    SurvivalPlannerList._trackingRevision = SurvivalPlannerList._trackingRevision + 1
end

function SurvivalPlannerList.getTrackedTargetsForPlayer(player)
    if not player then
        return {}
    end

    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    local now = getTimestampMs and getTimestampMs() or 0
    local cached = SurvivalPlannerList._trackingCache[playerNum + 1]
    if cached and (now - cached.at) < 500 then
        return cached.targets
    end

    local targets = {}
    SurvivalPlannerList.visitPlayerInventory(player, function(item)
        if SurvivalPlannerList.isPlanner(item) then
            local data = SurvivalPlannerList.getData(item)
            if data then
                for _, trackedItem in ipairs(data.trackedItems) do
                    targets[trackedItem.fullType] = trackedItem.name
                end
                for _, task in ipairs(data.tasks) do
                    if task.status == SurvivalPlannerList.STATUS_ACTIVE then
                        for _, goal in ipairs(task.goals or {}) do
                            targets[goal.fullType] = goal.name or task.title
                        end
                        for _, subtask in ipairs(task.subtasks or {}) do
                            if not subtask.done then
                                for _, goal in ipairs(subtask.goals or {}) do
                                    targets[goal.fullType] = goal.name or subtask.title
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end)

    SurvivalPlannerList._trackingCache[playerNum + 1] = {
        at = now,
        targets = targets,
    }
    return targets
end

function SurvivalPlannerList.collectNavigationTargets(player)
    local targets = {}
    if not player then
        return targets
    end

    SurvivalPlannerList.visitPlayerInventory(player, function(item)
        if not SurvivalPlannerList.isPlanner(item) then
            return nil
        end

        local data = SurvivalPlannerList.getData(item)
        if not data then
            return nil
        end

        for _, task in ipairs(data.tasks or {}) do
            local target = SurvivalPlannerList.getTaskMapTarget(task)
            if task.navigationEnabled == true
                and task.status ~= SurvivalPlannerList.STATUS_DONE
                and target then
                table.insert(targets, {
                    key = tostring(data.plannerId) .. ":" .. tostring(task.id),
                    plannerId = data.plannerId,
                    planner = item,
                    taskId = task.id,
                    task = task,
                    target = target,
                })
            end
        end
        return nil
    end)

    return targets
end

return SurvivalPlannerList
