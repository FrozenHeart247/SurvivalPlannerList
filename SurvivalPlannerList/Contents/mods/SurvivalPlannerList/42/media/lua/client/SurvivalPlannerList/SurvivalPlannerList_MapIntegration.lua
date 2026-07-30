require "ISUI/Maps/ISWorldMap"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"

SPLMapIntegration = SPLMapIntegration or {}
SPLMapIntegration.targetsByPlayer = SPLMapIntegration.targetsByPlayer or {}
SPLMapIntegration.pendingPlacement = SPLMapIntegration.pendingPlacement or nil

local MARKER_SIZE = 42
local MARKER_HIT_RADIUS = 24
local markerTexture = getTexture("media/textures/SPL_Marker.png")

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function drawRoundedMarker(ui, x, y, size, hovered)
    if markerTexture then
        if hovered then
            ui:drawTextureScaledAspect(
                markerTexture,
                x - 2,
                y - 2,
                size + 4,
                size + 4,
                0.65,
                0.72,
                0.86,
                0.44
            )
        end
        ui:drawTextureScaledAspect(markerTexture, x, y, size, size, 1, 1, 1, 1)
        return
    end

    local half = math.floor(size / 2)
    local borderR, borderG, borderB = 0.50, 0.61, 0.31
    if hovered then
        borderR, borderG, borderB = 0.72, 0.82, 0.43
    end

    ui:drawRect(x + 5, y, size - 10, size, 0.96, 0.08, 0.075, 0.06)
    ui:drawRect(x + 2, y + 5, size - 4, size - 10, 0.96, 0.08, 0.075, 0.06)
    ui:drawRect(x, y + 10, size, size - 20, 0.96, 0.08, 0.075, 0.06)

    ui:drawRectBorder(x + 5, y, size - 10, size, 1, borderR, borderG, borderB)
    ui:drawRectBorder(x, y + 10, size, size - 20, 1, borderR, borderG, borderB)
    ui:drawRect(x + 3, y + half - 2, 5, 5, 1, 0.64, 0.75, 0.38)
end

local function markerAt(worldMap, x, y)
    local targets = SPLMapIntegration.getTargets(worldMap.playerNum or 0)
    local best = nil
    local bestDistance = MARKER_HIT_RADIUS
    for _, navigation in ipairs(targets) do
        local target = navigation.target
        local sx = worldMap.mapAPI:worldToUIX(target.x, target.y)
        local sy = worldMap.mapAPI:worldToUIY(target.x, target.y)
        local dx = x - sx
        local dy = y - sy
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= bestDistance then
            best = navigation
            bestDistance = distance
        end
    end
    return best
end

local function drawTooltip(worldMap, navigation, markerX, markerY)
    local theme = SPLThemes.get(worldMap.playerNum or 0)
    local title = navigation.task.title or uiText("SPL_Map_Target", "Map target")
    local maxTextWidth = 270
    local wrapped = getTextManager():WrapText(UIFont.Small, title, maxTextWidth, 2, "...")
    local textWidth = math.min(maxTextWidth, getTextManager():MeasureStringX(UIFont.Small, wrapped))
    local tooltipWidth = math.max(130, textWidth + 24)
    local tooltipHeight = getTextManager():getFontHeight(UIFont.Small) * 2 + 18
    local tooltipX = markerX + MARKER_SIZE / 2 + 10
    local tooltipY = markerY - tooltipHeight / 2
    if tooltipX + tooltipWidth > worldMap.width - 8 then
        tooltipX = markerX - MARKER_SIZE / 2 - tooltipWidth - 10
    end
    tooltipY = math.max(8, math.min(tooltipY, worldMap.height - tooltipHeight - 8))

    worldMap:drawRect(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 0.95, theme.dialog.r, theme.dialog.g, theme.dialog.b)
    worldMap:drawRect(tooltipX, tooltipY, 4, tooltipHeight, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    worldMap:drawRectBorder(tooltipX, tooltipY, tooltipWidth, tooltipHeight, 1, theme.dialogBorder.r, theme.dialogBorder.g, theme.dialogBorder.b)
    worldMap:drawText(wrapped, tooltipX + 12, tooltipY + 8, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
end

function SPLMapIntegration.setTargets(playerNum, targets)
    SPLMapIntegration.targetsByPlayer[(playerNum or 0) + 1] = {
        at = getTimestampMs and getTimestampMs() or 0,
        values = targets or {},
    }
end

function SPLMapIntegration.getTargets(playerNum)
    playerNum = playerNum or 0
    local cached = SPLMapIntegration.targetsByPlayer[playerNum + 1]
    if cached then
        return cached.values
    end

    local player = getSpecificPlayer(playerNum)
    local targets = SurvivalPlannerList.collectNavigationTargets(player)
    SPLMapIntegration.setTargets(playerNum, targets)
    return targets
end

function SPLMapIntegration.isWorldMapVisible()
    return ISWorldMap_instance ~= nil and ISWorldMap_instance:isVisible()
end

function SPLMapIntegration.hideScreenWidgets(playerNum)
    local index = (playerNum or 0) + 1
    if SPLQuickButton and SPLQuickButton.instances then
        local quickButton = SPLQuickButton.instances[index]
        if quickButton then
            quickButton:setVisible(false)
        end
    end
    if SPLNavigationManager and SPLNavigationManager.widgetsByPlayer then
        for _, widget in pairs(SPLNavigationManager.widgetsByPlayer[index] or {}) do
            widget:setVisible(false)
        end
    end
end

function SPLMapIntegration.restoreScreenWidgets(playerNum)
    local index = (playerNum or 0) + 1
    if SPLQuickButton and SPLQuickButton.instances then
        local quickButton = SPLQuickButton.instances[index]
        if quickButton then
            quickButton:setVisible(true)
            quickButton:bringToTop()
        end
    end
    if SPLNavigationManager and SPLNavigationManager.syncPlayer then
        SPLNavigationManager.syncPlayer(playerNum or 0, true)
    end
end

function SPLMapIntegration.beginPlacement(playerNum, currentTarget, callback)
    playerNum = playerNum or 0
    if not ISWorldMap.IsAllowed() then
        return false
    end

    local player = getSpecificPlayer(playerNum)
    local centerX = currentTarget and currentTarget.x or (player and player:getX() or nil)
    local centerY = currentTarget and currentTarget.y or (player and player:getY() or nil)
    SPLMapIntegration.pendingPlacement = {
        playerNum = playerNum,
        callback = callback,
        currentTarget = currentTarget,
    }

    ISWorldMap.ShowWorldMap(playerNum, centerX, centerY, 18)
    local worldMap = ISWorldMap_instance
    if not worldMap or not worldMap:isVisible() then
        SPLMapIntegration.pendingPlacement = nil
        return false
    end

    if worldMap.symbolsUI then
        SPLMapIntegration.pendingPlacement.symbolsWereVisible = worldMap.symbolsUI:isVisible()
        worldMap.symbolsUI:undisplay()
        worldMap.symbolsUI:setVisible(false)
    end
    worldMap:bringToTop()
    return true
end

function SPLMapIntegration.finishPlacement(target)
    local pending = SPLMapIntegration.pendingPlacement
    if not pending then
        return
    end

    SPLMapIntegration.pendingPlacement = nil
    local callback = pending.callback
    if ISWorldMap_instance and ISWorldMap_instance:isVisible() then
        if ISWorldMap_instance.symbolsUI then
            ISWorldMap_instance.symbolsUI:setVisible(pending.symbolsWereVisible == true)
        end
        ISWorldMap_instance:close()
    end
    if callback then
        callback(target)
    end
end

local originalRender = ISWorldMap.render
local originalMouseUp = ISWorldMap.onMouseUp
local originalClose = ISWorldMap.close

if not ISWorldMap._SPLMapIntegrationWrapped then
    ISWorldMap._SPLMapIntegrationWrapped = true

    function ISWorldMap:render()
        SPLMapIntegration.hideScreenWidgets(self.playerNum or 0)
        originalRender(self)

        local theme = SPLThemes.get(self.playerNum or 0)
        local mouseX = self:getMouseX()
        local mouseY = self:getMouseY()
        local hovered = markerAt(self, mouseX, mouseY)
        for _, navigation in ipairs(SPLMapIntegration.getTargets(self.playerNum or 0)) do
            local target = navigation.target
            local sx = self.mapAPI:worldToUIX(target.x, target.y)
            local sy = self.mapAPI:worldToUIY(target.x, target.y)
            local x = math.floor(sx - MARKER_SIZE / 2)
            local y = math.floor(sy - MARKER_SIZE / 2)
            local isHovered = hovered and hovered.key == navigation.key
            drawRoundedMarker(self, x, y, MARKER_SIZE, isHovered)
            local icon = SurvivalPlannerList.getItemTexture(navigation.task.iconType)
            if icon then
                self:drawTextureScaledAspect(icon, x + 8, y + 8, MARKER_SIZE - 16, MARKER_SIZE - 16, 1, 1, 1, 1)
            else
                self:drawTextCentre("!", x + MARKER_SIZE / 2, y + 9, 0.90, 0.86, 0.70, 1, UIFont.Medium)
            end
        end

        if hovered then
            local sx = self.mapAPI:worldToUIX(hovered.target.x, hovered.target.y)
            local sy = self.mapAPI:worldToUIY(hovered.target.x, hovered.target.y)
            drawTooltip(self, hovered, sx, sy)
        end

        local pending = SPLMapIntegration.pendingPlacement
        if pending and pending.playerNum == (self.playerNum or 0) then
            local bannerWidth = math.min(520, self.width - 40)
            local bannerX = math.floor((self.width - bannerWidth) / 2)
            self:drawRect(bannerX, 18, bannerWidth, 48, 0.96, theme.dialog.r, theme.dialog.g, theme.dialog.b)
            self:drawRect(bannerX, 18, 5, 48, 1, theme.accent.r, theme.accent.g, theme.accent.b)
            self:drawRectBorder(bannerX, 18, bannerWidth, 48, 1, theme.dialogBorder.r, theme.dialogBorder.g, theme.dialogBorder.b)
            self:drawTextCentre(
                uiText("SPL_Map_PlaceHint", "Click the map to set the target. Drag to pan; Esc cancels."),
                self.width / 2,
                33,
                theme.text.r,
                theme.text.g,
                theme.text.b,
                1,
                UIFont.Small
            )
            self:drawRect(mouseX - 10, mouseY - 1, 21, 3, 1, theme.accentHover.r, theme.accentHover.g, theme.accentHover.b)
            self:drawRect(mouseX - 1, mouseY - 10, 3, 21, 1, theme.accentHover.r, theme.accentHover.g, theme.accentHover.b)
        end
    end

    function ISWorldMap:onMouseUp(x, y)
        local wasDragging = self.dragging
        local wasMoved = self.dragMoved
        local pending = SPLMapIntegration.pendingPlacement
        local clickedMarker = nil
        if not pending and wasDragging and not wasMoved then
            clickedMarker = markerAt(self, x, y)
        end

        local result = originalMouseUp(self, x, y)
        if pending and pending.playerNum == (self.playerNum or 0) and wasDragging and not wasMoved then
            local current = pending.currentTarget or {}
            SPLMapIntegration.finishPlacement({
                id = current.id,
                name = current.name or "",
                x = self.mapAPI:uiToWorldX(x, y),
                y = self.mapAPI:uiToWorldY(x, y),
                z = self.character and math.floor(self.character:getZ()) or 0,
                radius = current.radius or 15,
            })
            return true
        end

        if clickedMarker then
            self:close()
            if SurvivalPlannerList.openPlannerTask then
                SurvivalPlannerList.openPlannerTask(
                    self.playerNum or 0,
                    clickedMarker.planner,
                    clickedMarker.taskId
                )
            end
            return true
        end
        return result
    end

    function ISWorldMap:close()
        local pending = SPLMapIntegration.pendingPlacement
        if pending and pending.playerNum == (self.playerNum or 0) then
            SPLMapIntegration.pendingPlacement = nil
            local callback = pending.callback
            if self.symbolsUI then
                self.symbolsUI:setVisible(pending.symbolsWereVisible == true)
            end
            originalClose(self)
            SPLMapIntegration.restoreScreenWidgets(self.playerNum or 0)
            if callback then
                callback(nil)
            end
            return
        end
        local result = originalClose(self)
        SPLMapIntegration.restoreScreenWidgets(self.playerNum or 0)
        return result
    end
end

return SPLMapIntegration
