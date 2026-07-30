require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_MapIntegration"
require "SurvivalPlannerList/SurvivalPlannerList_NavigationWidget"

SPLNavigationManager = SPLNavigationManager or {}
SPLNavigationManager.widgetsByPlayer = SPLNavigationManager.widgetsByPlayer or {}
SPLNavigationManager.lastSyncByPlayer = SPLNavigationManager.lastSyncByPlayer or {}

local DEFAULT_REFRESH_INTERVAL_SECONDS = 0.35
local MIN_REFRESH_INTERVAL_SECONDS = 0.10
local MAX_REFRESH_INTERVAL_SECONDS = 2.0
local LAYOUT_KEY = "SurvivalPlannerListNavigationLayout"
local NAVIGATION_WIDGET_SIZE = 80

local function timestampMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    return 0
end

local function getRefreshIntervalMs()
    local options = SandboxVars and SandboxVars.SurvivalPlannerList or nil
    local seconds = tonumber(options and options.NavigationRefreshInterval)
        or DEFAULT_REFRESH_INTERVAL_SECONDS
    seconds = math.max(
        MIN_REFRESH_INTERVAL_SECONDS,
        math.min(MAX_REFRESH_INTERVAL_SECONDS, seconds)
    )
    return math.floor(seconds * 1000)
end

local function playerScreenBounds(playerNum)
    if getPlayerScreenLeft and getPlayerScreenTop
        and getPlayerScreenWidth and getPlayerScreenHeight then
        return getPlayerScreenLeft(playerNum),
            getPlayerScreenTop(playerNum),
            getPlayerScreenWidth(playerNum),
            getPlayerScreenHeight(playerNum)
    end
    return 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight()
end

local function getLayout(player)
    local modData = player:getModData()
    if type(modData[LAYOUT_KEY]) ~= "table" then
        modData[LAYOUT_KEY] = {version = 1, positions = {}}
    end
    local layout = modData[LAYOUT_KEY]
    layout.version = 1
    if type(layout.positions) ~= "table" then
        layout.positions = {}
    end
    return layout
end

local function defaultPosition(playerNum)
    local left, top, width, height = playerScreenBounds(playerNum)
    return left + math.floor((width - NAVIGATION_WIDGET_SIZE) / 2),
        top + math.floor((height - NAVIGATION_WIDGET_SIZE) / 2)
end

local function savedPosition(player, playerNum, key)
    local position = getLayout(player).positions[key]
    if type(position) ~= "table" then
        return nil, nil
    end
    local nx = tonumber(position.nx)
    local ny = tonumber(position.ny)
    if not nx or not ny then
        return nil, nil
    end
    local left, top, width, height = playerScreenBounds(playerNum)
    return left + math.max(0, math.min(1, nx)) * math.max(0, width - 80),
        top + math.max(0, math.min(1, ny)) * math.max(0, height - 80)
end

function SPLNavigationManager.saveWidgetPosition(widget)
    local player = getSpecificPlayer(widget.playerNum)
    if not player then
        return
    end
    local left, top, width, height = playerScreenBounds(widget.playerNum)
    local availableWidth = math.max(1, width - widget.width)
    local availableHeight = math.max(1, height - widget.height)
    getLayout(player).positions[widget.navigationKey] = {
        nx = math.max(0, math.min(1, (widget.x - left) / availableWidth)),
        ny = math.max(0, math.min(1, (widget.y - top) / availableHeight)),
    }
end

local function removeWidget(widget)
    if widget then
        widget:setVisible(false)
        widget:removeFromUIManager()
    end
end

function SPLNavigationManager.clearPlayer(playerNum)
    local index = (playerNum or 0) + 1
    for _, widget in pairs(SPLNavigationManager.widgetsByPlayer[index] or {}) do
        removeWidget(widget)
    end
    SPLNavigationManager.widgetsByPlayer[index] = nil
    SPLNavigationManager.lastSyncByPlayer[index] = nil
    SPLMapIntegration.setTargets(playerNum, {})
end

function SPLNavigationManager.syncPlayer(playerNum, force)
    playerNum = playerNum or 0
    local player = getSpecificPlayer(playerNum)
    if not player then
        SPLNavigationManager.clearPlayer(playerNum)
        return
    end

    local index = playerNum + 1
    local now = timestampMs()
    if not force
        and now - (SPLNavigationManager.lastSyncByPlayer[index] or -1000) < getRefreshIntervalMs() then
        return
    end
    SPLNavigationManager.lastSyncByPlayer[index] = now

    local targets = SurvivalPlannerList.collectNavigationTargets(player)
    SPLMapIntegration.setTargets(playerNum, targets)
    local widgets = SPLNavigationManager.widgetsByPlayer[index] or {}
    SPLNavigationManager.widgetsByPlayer[index] = widgets
    local active = {}
    local hideForMap = SPLMapIntegration.isWorldMapVisible()

    for _, navigation in ipairs(targets) do
        active[navigation.key] = true
        local widget = widgets[navigation.key]
        if not widget then
            local x, y = savedPosition(player, playerNum, navigation.key)
            if not x or not y then
                x, y = defaultPosition(playerNum)
            end
            widget = SPLNavigationWidget:new(
                playerNum,
                navigation,
                x,
                y,
                SPLNavigationManager.saveWidgetPosition
            )
            widget:initialise()
            widget:addToUIManager()
            widget:setAlwaysOnTop(true)
            widget:clampToPlayerScreen()
            widgets[navigation.key] = widget
        else
            widget:setNavigation(navigation)
        end
        widget:setVisible(not hideForMap)
        if not hideForMap then
            widget:bringToTop()
        end
    end

    for key, widget in pairs(widgets) do
        if not active[key] then
            removeWidget(widget)
            widgets[key] = nil
        end
    end
end

function SPLNavigationManager.onPlayerUpdate(player)
    if player and player.getPlayerNum then
        SPLNavigationManager.syncPlayer(player:getPlayerNum(), false)
    end
end

function SPLNavigationManager.onCreatePlayer(playerNum)
    SPLNavigationManager.syncPlayer(playerNum, true)
end

function SPLNavigationManager.onGameStart()
    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, count - 1 do
        if getSpecificPlayer(playerNum) then
            SPLNavigationManager.syncPlayer(playerNum, true)
        end
    end
end

function SPLNavigationManager.onPlayerDeath(player)
    if player and player.getPlayerNum then
        SPLNavigationManager.clearPlayer(player:getPlayerNum())
    end
end

function SPLNavigationManager.onResolutionChange()
    for index, widgets in pairs(SPLNavigationManager.widgetsByPlayer) do
        local playerNum = index - 1
        local player = getSpecificPlayer(playerNum)
        for key, widget in pairs(widgets) do
            local x, y = nil, nil
            if player then
                x, y = savedPosition(player, playerNum, key)
            end
            if x and y then
                widget:setX(x)
                widget:setY(y)
            end
            widget:clampToPlayerScreen()
        end
    end
end

function SPLNavigationManager.onContainerUpdate()
    local count = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, count - 1 do
        SPLNavigationManager.syncPlayer(playerNum, false)
    end
end

Events.OnPlayerUpdate.Add(SPLNavigationManager.onPlayerUpdate)
Events.OnCreatePlayer.Add(SPLNavigationManager.onCreatePlayer)
Events.OnGameStart.Add(SPLNavigationManager.onGameStart)
Events.OnPlayerDeath.Add(SPLNavigationManager.onPlayerDeath)
Events.OnResolutionChange.Add(SPLNavigationManager.onResolutionChange)
Events.OnContainerUpdate.Add(SPLNavigationManager.onContainerUpdate)

return SPLNavigationManager
