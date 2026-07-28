require "ISUI/ISInventoryPane"
require "SurvivalPlannerList/SurvivalPlannerList_Core"

local installedRefresh = nil
local installedRender = nil
local lastAlertByPlayer = {}

local function playFoundAlert(playerNum)
    local now = getTimestampMs and getTimestampMs() or 0
    local lastAlert = lastAlertByPlayer[playerNum + 1] or -10000
    if now - lastAlert < 2500 then
        return
    end
    lastAlertByPlayer[playerNum + 1] = now
    getSoundManager():playUISound("UIActivateButton")
end

local function collectHighlights(pane, targets)
    local highlights = {}
    local visibleTypes = {}
    local hasHighlights = false
    for _, group in ipairs(pane.itemslist or {}) do
        for _, item in ipairs(group.items or {}) do
            if item and instanceof(item, "InventoryItem") then
                local fullType = item:getFullType()
                if targets[fullType] then
                    highlights[item] = true
                    visibleTypes[fullType] = true
                    hasHighlights = true
                end
            end
        end
    end
    return hasHighlights and highlights or nil, visibleTypes
end

local function updateFoundAlert(pane, visibleTypes)
    local previous = pane.splVisibleTrackedTypes or {}
    local foundNew = false
    for fullType in pairs(visibleTypes) do
        if not previous[fullType] then
            foundNew = true
            break
        end
    end
    pane.splVisibleTrackedTypes = visibleTypes
    if foundNew then
        playFoundAlert(pane.player or 0)
    end
end

local function restoreBaseHighlights(pane)
    if pane.itemsToHighlight == pane.splHighlightProxy then
        pane.itemsToHighlight = pane.splBaseHighlightMap
        pane.itemsToHighlightOwner = pane.splBaseHighlightOwner
    end
    pane.splHighlightProxy = nil
    pane.splHighlightItems = nil
end

local function installHighlightProxy(pane, baseMap, baseOwner)
    pane.splBaseHighlightMap = baseMap
    pane.splBaseHighlightOwner = baseOwner

    local ownerPane = pane
    pane.splHighlightProxy = setmetatable({}, {
        __index = function(_, inventoryItem)
            if ownerPane.splHighlightItems and ownerPane.splHighlightItems[inventoryItem] then
                ownerPane.splPendingHighlight = true
                return true
            end
            ownerPane.splPendingHighlight = nil
            if ownerPane.splBaseHighlightMap then
                return ownerPane.splBaseHighlightMap[inventoryItem]
            end
            return nil
        end,
    })
    pane.itemsToHighlight = pane.splHighlightProxy
    pane.itemsToHighlightOwner = baseOwner or pane.parent or pane
end

local function refreshPlannerHighlights(pane)
    if not pane.itemslist then
        restoreBaseHighlights(pane)
        pane.splVisibleTrackedTypes = {}
        pane.splTrackingRevision = SurvivalPlannerList._trackingRevision
        return
    end

    local player = getSpecificPlayer(pane.player or 0)
    if not player then
        return
    end

    local baseMap = pane.itemsToHighlight
    local baseOwner = pane.itemsToHighlightOwner
    if baseMap == pane.splHighlightProxy then
        baseMap = pane.splBaseHighlightMap
        baseOwner = pane.splBaseHighlightOwner
    end

    local targets = SurvivalPlannerList.getTrackedTargetsForPlayer(player)
    local ourHighlights, visibleTypes = collectHighlights(pane, targets)
    updateFoundAlert(pane, visibleTypes)
    pane.splHighlightItems = ourHighlights
    pane.splTrackingRevision = SurvivalPlannerList._trackingRevision

    if not ourHighlights then
        pane.splBaseHighlightMap = baseMap
        pane.splBaseHighlightOwner = baseOwner
        pane.itemsToHighlight = baseMap
        pane.itemsToHighlightOwner = baseOwner
        pane.splHighlightProxy = nil
        return
    end

    installHighlightProxy(pane, baseMap, baseOwner)
end

local function wrapInventoryPane()
    if ISInventoryPane.refreshContainer ~= installedRefresh then
        local previousRefresh = ISInventoryPane.refreshContainer
        installedRefresh = function(pane)
            previousRefresh(pane)
            refreshPlannerHighlights(pane)
        end
        ISInventoryPane.refreshContainer = installedRefresh
    end

    if ISInventoryPane.renderdetails ~= installedRender then
        local previousRender = ISInventoryPane.renderdetails
        installedRender = function(pane, doDragged)
            if pane.splTrackingRevision ~= SurvivalPlannerList._trackingRevision then
                refreshPlannerHighlights(pane)
            end
            if doDragged or not pane.splHighlightItems then
                previousRender(pane, doDragged)
                return
            end

            local pulse = 0.45 + ((math.sin((getTimestampMs and getTimestampMs() or 0) / 190) + 1) / 2) * 0.55
            local previousDrawRect = pane.drawRect
            pane.drawRect = function(self, x, y, width, height, a, r, g, b)
                if self.splPendingHighlight and a >= 0.19 and r >= 0.99 and g >= 0.99 and b >= 0.99 then
                    self.splPendingHighlight = nil
                    previousDrawRect(self, x, y, width, height, 0.075 * pulse, 1.0, 0.78, 0.18)
                    previousDrawRect(self, x, y, 4, height, 0.34 * pulse, 1.0, 0.74, 0.10)
                    previousDrawRect(self, x, y + height - 2, width, 2, 0.18 * pulse, 1.0, 0.74, 0.10)
                    return
                end
                previousDrawRect(self, x, y, width, height, a, r, g, b)
            end

            local ok, message = pcall(previousRender, pane, doDragged)
            pane.drawRect = previousDrawRect
            pane.splPendingHighlight = nil
            if not ok then
                error(message)
            end
        end
        ISInventoryPane.renderdetails = installedRender
    end
end

wrapInventoryPane()
Events.OnGameStart.Add(wrapInventoryPane)

return SurvivalPlannerList
