require "ISUI/ISPanel"
require "ISUI/ISLayoutManager"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_MainPanel"

SPLQuickButton = ISPanel:derive("SPLQuickButton")
SPLQuickButton.instances = SPLQuickButton.instances or {}

local BUTTON_SIZE = 50
local DRAG_THRESHOLD = 5

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
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

local function layoutName(playerNum)
    return "SurvivalPlannerQuickButton" .. tostring(playerNum or 0)
end

function SPLQuickButton:initialise()
    ISPanel.initialise(self)
    local scriptItem = getScriptManager and getScriptManager():FindItem(SurvivalPlannerList.ITEM_TYPE) or nil
    self.iconTexture = scriptItem and scriptItem.getNormalTexture and scriptItem:getNormalTexture() or nil
    if not self.iconTexture and getScriptManager then
        local notebook = getScriptManager():FindItem(SurvivalPlannerList.DEFAULT_ICON)
        self.iconTexture = notebook and notebook.getNormalTexture and notebook:getNormalTexture() or nil
    end
end

function SPLQuickButton:clampToPlayerScreen()
    local left, top, width, height = playerScreenBounds(self.playerNum)
    self:setX(math.max(left, math.min(self.x, left + width - self.width)))
    self:setY(math.max(top, math.min(self.y, top + height - self.height)))
end

function SPLQuickButton:activate()
    local player = getSpecificPlayer(self.playerNum)
    if not player then
        return
    end

    local planner = SurvivalPlannerList.findPlayerItem(player, SurvivalPlannerList.isPlanner)
    if planner then
        SurvivalPlannerList.openPlannerUI(self.playerNum, planner)
        return
    end

    local message = uiText(
        "SPL_Message_PlannerNotCarried",
        "No Survival Planner found in your inventory or bags."
    )
    if player.setHaloNote then
        player:setHaloNote(message, 220, 150, 100, 300)
    elseif HaloTextHelper and HaloTextHelper.addText then
        HaloTextHelper.addText(player, message)
    end
end

function SPLQuickButton:onMouseDown(x, y)
    if not self:getIsVisible() then
        return
    end
    self.dragging = true
    self.dragMoved = false
    self.dragStartMouseX = getMouseX()
    self.dragStartMouseY = getMouseY()
    self.dragStartX = self.x
    self.dragStartY = self.y
    self:setCapture(true)
    self:bringToTop()
    return true
end

function SPLQuickButton:updateDrag()
    if not self.dragging then
        return
    end
    local dx = getMouseX() - self.dragStartMouseX
    local dy = getMouseY() - self.dragStartMouseY
    if not self.dragMoved and (math.abs(dx) >= DRAG_THRESHOLD or math.abs(dy) >= DRAG_THRESHOLD) then
        self.dragMoved = true
    end
    if self.dragMoved then
        self:setX(self.dragStartX + dx)
        self:setY(self.dragStartY + dy)
        self:clampToPlayerScreen()
    end
end

function SPLQuickButton:onMouseMove(dx, dy)
    self.mouseOver = true
    self:updateDrag()
end

function SPLQuickButton:onMouseMoveOutside(dx, dy)
    self.mouseOver = false
    self:updateDrag()
end

function SPLQuickButton:finishDrag(activateOnClick)
    if not self.dragging then
        return
    end
    self:updateDrag()
    local wasMoved = self.dragMoved
    self.dragging = false
    self.dragMoved = false
    self:setCapture(false)
    self:clampToPlayerScreen()
    if activateOnClick and not wasMoved then
        self:activate()
    end
end

function SPLQuickButton:onMouseUp(x, y)
    self:finishDrag(self:isMouseOver())
    return true
end

function SPLQuickButton:onMouseUpOutside(x, y)
    self:finishDrag(false)
    return true
end

function SPLQuickButton:prerender()
    local hovered = self:isMouseOver() or self.dragging
    local alpha = hovered and 0.98 or 0.88
    local borderR, borderG, borderB = 0.43, 0.50, 0.28
    if hovered then
        borderR, borderG, borderB = 0.63, 0.72, 0.38
    end

    self:drawRect(3, 4, self.width - 3, self.height - 3, 0.34, 0, 0, 0)
    self:drawRect(0, 0, self.width - 3, self.height - 3, alpha, 0.14, 0.13, 0.10)
    self:drawRect(0, 0, 4, self.height - 3, 1, 0.50, 0.61, 0.31)
    self:drawRectBorder(0, 0, self.width - 3, self.height - 3, 1, borderR, borderG, borderB)

    if self.iconTexture then
        self:drawTextureScaledAspect(self.iconTexture, 8, 6, 34, 34, 1, 1, 1, 1)
    else
        self:drawTextCentre("P", 24, 11, 0.87, 0.84, 0.68, 1, UIFont.Medium)
    end
end

function SPLQuickButton:RestoreLayout(name, layout)
    local x = tonumber(layout.x)
    local y = tonumber(layout.y)
    if x and y then
        self:setX(x)
        self:setY(y)
    end
    self:clampToPlayerScreen()
end

function SPLQuickButton:SaveLayout(name, layout)
    layout.x = self:getX()
    layout.y = self:getY()
    layout.visible = "true"
end

function SPLQuickButton:new(playerNum)
    local left, top, screenWidth, screenHeight = playerScreenBounds(playerNum)
    local x = left + screenWidth - BUTTON_SIZE - 18
    local y = top + math.floor((screenHeight - BUTTON_SIZE) / 2)
    local o = ISPanel.new(self, x, y, BUTTON_SIZE, BUTTON_SIZE)
    o.playerNum = playerNum or 0
    o.background = false
    o.moveWithMouse = false
    o.mouseOver = false
    o.dragging = false
    o.dragMoved = false
    o:setWantMouseEvents(true)
    return o
end

function SPLQuickButton.createForPlayer(playerNum)
    playerNum = playerNum or 0
    local index = playerNum + 1
    local existing = SPLQuickButton.instances[index]
    if existing then
        existing:setVisible(true)
        existing:clampToPlayerScreen()
        existing:bringToTop()
        return existing
    end

    local button = SPLQuickButton:new(playerNum)
    button:initialise()
    ISLayoutManager.RegisterWindow(layoutName(playerNum), SPLQuickButton, button)
    button:addToUIManager()
    button:setAlwaysOnTop(true)
    button:bringToTop()
    SPLQuickButton.instances[index] = button
    return button
end

function SPLQuickButton.onCreatePlayer(playerNum)
    SPLQuickButton.createForPlayer(playerNum)
end

function SPLQuickButton.onGameStart()
    local playerCount = getNumActivePlayers and getNumActivePlayers() or 1
    for playerNum = 0, playerCount - 1 do
        if getSpecificPlayer(playerNum) then
            SPLQuickButton.createForPlayer(playerNum)
        end
    end
end

function SPLQuickButton.onPlayerDeath(player)
    if not player or not player.getPlayerNum then
        return
    end
    local playerNum = player:getPlayerNum()
    local index = playerNum + 1
    local button = SPLQuickButton.instances[index]
    if button then
        button:setVisible(false)
        button:removeFromUIManager()
        SPLQuickButton.instances[index] = nil
    end
end

function SPLQuickButton.onResolutionChange()
    for _, button in pairs(SPLQuickButton.instances) do
        button:clampToPlayerScreen()
    end
end

Events.OnCreatePlayer.Add(SPLQuickButton.onCreatePlayer)
Events.OnGameStart.Add(SPLQuickButton.onGameStart)
Events.OnPlayerDeath.Add(SPLQuickButton.onPlayerDeath)
Events.OnResolutionChange.Add(SPLQuickButton.onResolutionChange)

return SPLQuickButton
