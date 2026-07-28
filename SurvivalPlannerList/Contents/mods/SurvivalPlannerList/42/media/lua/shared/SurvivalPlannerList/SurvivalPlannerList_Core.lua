SurvivalPlannerList = SurvivalPlannerList or {}

SurvivalPlannerList.ID = "SurvivalPlannerList"
SurvivalPlannerList.ITEM_TYPE = "SurvivalPlannerList.SurvivalPlanner"
SurvivalPlannerList.DATA_VERSION = 1
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

function SurvivalPlannerList.findWritingTool(player)
    return SurvivalPlannerList.findPlayerItem(player, function(item)
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
        if bareType and (bareType:match("^Pen") or bareType:match("^Pencil")) then
            return true
        end
        return false
    end)
end

function SurvivalPlannerList.findEraser(player)
    return SurvivalPlannerList.findPlayerItem(player, function(item)
        return itemFullType(item) == "Base.Eraser"
    end)
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

    return {
        id = id,
        title = title,
        done = raw.done == true,
    }
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
        targetType = trim(raw.targetType) ~= "" and trim(raw.targetType) or nil,
        targetName = trim(raw.targetName) ~= "" and trim(raw.targetName) or nil,
        createdAt = tonumber(raw.createdAt) or safeNow(),
        completedAt = tonumber(raw.completedAt),
        subtasks = {},
    }

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
        targetType = trim(values.targetType) ~= "" and trim(values.targetType) or nil,
        targetName = trim(values.targetName) ~= "" and trim(values.targetName) or nil,
        createdAt = safeNow(),
        completedAt = nil,
        subtasks = {},
    }
    table.insert(data.tasks, task)
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
    task.targetType = trim(values.targetType) ~= "" and trim(values.targetType) or nil
    task.targetName = trim(values.targetName) ~= "" and trim(values.targetName) or nil
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

function SurvivalPlannerList.addSubtask(planner, taskId, title)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    title = trim(title)
    if not task or title == "" then
        return false
    end

    table.insert(task.subtasks, {
        id = nextId(data),
        title = title,
        done = false,
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

    SurvivalPlannerList.getItemCatalog()
    local entry = SurvivalPlannerList._itemCatalogByType[fullType]
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

function SurvivalPlannerList.invalidateTrackingCache()
    SurvivalPlannerList._trackingCache = {}
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
                    if task.status == SurvivalPlannerList.STATUS_ACTIVE and task.targetType then
                        targets[task.targetType] = task.targetName or task.title
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

return SurvivalPlannerList
