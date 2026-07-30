require "ISUI/ISPanel"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"

SPLNavigationWidget = ISPanel:derive("SPLNavigationWidget")

local WIDGET_SIZE = 80
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

local function directionAndDistance(player, target)
    if not player or not target then
        return 0, 0
    end
    local dx = target.x - player:getX()
    local dy = target.y - player:getY()
    local screenDX = (dx - dy) * 0.5
    local screenDY = (dx + dy) * 0.25
    return math.atan2(screenDY, screenDX), math.sqrt(dx * dx + dy * dy)
end

local function formatDistance(distance)
    if distance >= 1000 then
        return string.format("%.1f %s", distance / 1000, uiText("IGUI_SPL_Unit_Kilometers", "km"))
    end
    return string.format("%d %s", math.floor(distance + 0.5), uiText("IGUI_SPL_Unit_Tiles", "tiles"))
end

local function renderRotatedTexture(texture, centerX, centerY, width, height, angle, r, g, b, a)
    if not texture then
        return
    end
    local halfWidth = width / 2
    local halfHeight = height / 2
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)
    local x1 = centerX - cosAngle * halfWidth + sinAngle * halfHeight
    local y1 = centerY - sinAngle * halfWidth - cosAngle * halfHeight
    local x2 = centerX + cosAngle * halfWidth + sinAngle * halfHeight
    local y2 = centerY + sinAngle * halfWidth - cosAngle * halfHeight
    local x3 = centerX + cosAngle * halfWidth - sinAngle * halfHeight
    local y3 = centerY + sinAngle * halfWidth + cosAngle * halfHeight
    local x4 = centerX - cosAngle * halfWidth - sinAngle * halfHeight
    local y4 = centerY - sinAngle * halfWidth + cosAngle * halfHeight
    getRenderer():render(texture, x1, y1, x2, y2, x3, y3, x4, y4, r, g, b, a, nil)
end

function SPLNavigationWidget:initialise()
    ISPanel.initialise(self)
    self.markerTexture = getTexture("media/textures/SPL_Marker.png")
    self.arrowTexture = getTexture("media/textures/SPL_Arrow.png")
        or getTexture("media/ui/ArrowRight.png")
end

function SPLNavigationWidget:setNavigation(navigation)
    self.navigation = navigation
    self.planner = navigation.planner
    self.taskId = navigation.taskId
    self.taskTitle = navigation.task.title
    self.target = navigation.target
    self.iconTexture = SurvivalPlannerList.getItemTexture(navigation.task.iconType)
end

function SPLNavigationWidget:clampToPlayerScreen()
    local left, top, width, height = playerScreenBounds(self.playerNum)
    self:setX(math.max(left, math.min(self.x, left + width - self.width)))
    self:setY(math.max(top, math.min(self.y, top + height - self.height)))
end

function SPLNavigationWidget:activate()
    if SurvivalPlannerList.openPlannerTask then
        SurvivalPlannerList.openPlannerTask(self.playerNum, self.planner, self.taskId)
    end
end

function SPLNavigationWidget:onMouseDown(x, y)
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

function SPLNavigationWidget:updateDrag()
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

function SPLNavigationWidget:onMouseMove(dx, dy)
    self:updateDrag()
end

function SPLNavigationWidget:onMouseMoveOutside(dx, dy)
    self:updateDrag()
end

function SPLNavigationWidget:finishDrag(activateOnClick)
    if not self.dragging then
        return
    end
    self:updateDrag()
    local moved = self.dragMoved
    self.dragging = false
    self.dragMoved = false
    self:setCapture(false)
    self:clampToPlayerScreen()
    if moved and self.onPositionChanged then
        self.onPositionChanged(self)
    elseif activateOnClick then
        self:activate()
    end
end

function SPLNavigationWidget:onMouseUp(x, y)
    self:finishDrag(self:isMouseOver())
    return true
end

function SPLNavigationWidget:onMouseUpOutside(x, y)
    self:finishDrag(false)
    return true
end

function SPLNavigationWidget:prerender()
    local theme = SPLThemes.get(self.playerNum)
    local hovered = self:isMouseOver() or self.dragging
    local centerX = self.width / 2
    local centerY = self.height / 2
    local border = theme.accent
    if hovered then
        border = theme.accentHover
    end

    if self.markerTexture then
        local markerSize = hovered and 62 or 58
        self:drawTextureScaledAspect(
            self.markerTexture,
            centerX - markerSize / 2,
            centerY - markerSize / 2,
            markerSize,
            markerSize,
            1,
            1,
            1,
            1
        )
    else
        self:drawRect(centerX - 15, centerY - 23, 30, 46, 0.92, theme.card.r, theme.card.g, theme.card.b)
        self:drawRect(centerX - 20, centerY - 19, 40, 38, 0.92, theme.card.r, theme.card.g, theme.card.b)
        self:drawRect(centerX - 23, centerY - 14, 46, 28, 0.92, theme.card.r, theme.card.g, theme.card.b)
        self:drawRectBorder(centerX - 15, centerY - 23, 30, 46, 1, border.r, border.g, border.b)
        self:drawRectBorder(centerX - 23, centerY - 14, 46, 28, 1, border.r, border.g, border.b)
        self:drawRect(centerX - 19, centerY - 10, 4, 20, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    end

    if self.iconTexture then
        self:drawTextureScaledAspect(self.iconTexture, centerX - 15, centerY - 15, 30, 30, 1, 1, 1, 1)
    else
        self:drawTextCentre("!", centerX, centerY - 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    end
end

function SPLNavigationWidget:render()
    ISPanel.render(self)
    local theme = SPLThemes.get(self.playerNum)
    local player = getSpecificPlayer(self.playerNum)
    local angle, distance = directionAndDistance(player, self.target)
    local orbit = 34
    local absoluteCenterX = self.x + self.width / 2 + math.cos(angle) * orbit
    local absoluteCenterY = self.y + self.height / 2 + math.sin(angle) * orbit
    renderRotatedTexture(
        self.arrowTexture,
        absoluteCenterX,
        absoluteCenterY,
        28,
        28,
        angle,
        1,
        1,
        1,
        1
    )

    if not self:isMouseOver() or self.dragging then
        return
    end

    local title = self.taskTitle or uiText("IGUI_SPL_Map_Target", "Map target")
    local width = 260
    local wrapped = getTextManager():WrapText(UIFont.Small, title, width - 22, 2, "...")
    local tooltipHeight = getTextManager():getFontHeight(UIFont.Small) * 3 + 20
    local tooltipX = self.width + 8
    local left, top, screenWidth = playerScreenBounds(self.playerNum)
    if self.x + tooltipX + width > left + screenWidth then
        tooltipX = -width - 8
    end
    local tooltipY = math.floor((self.height - tooltipHeight) / 2)
    self:drawRect(tooltipX, tooltipY, width, tooltipHeight, 0.96, theme.dialog.r, theme.dialog.g, theme.dialog.b)
    self:drawRect(tooltipX, tooltipY, 4, tooltipHeight, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawRectBorder(tooltipX, tooltipY, width, tooltipHeight, 1, theme.dialogBorder.r, theme.dialogBorder.g, theme.dialogBorder.b)
    self:drawText(wrapped, tooltipX + 12, tooltipY + 8, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(
        formatDistance(distance),
        tooltipX + 12,
        tooltipY + tooltipHeight - getTextManager():getFontHeight(UIFont.Small) - 8,
        theme.accent.r,
        theme.accent.g,
        theme.accent.b,
        1,
        UIFont.Small
    )
end

function SPLNavigationWidget:new(playerNum, navigation, x, y, onPositionChanged)
    local o = ISPanel.new(self, x, y, WIDGET_SIZE, WIDGET_SIZE)
    o.playerNum = playerNum or 0
    o.navigationKey = navigation.key
    o.onPositionChanged = onPositionChanged
    o.background = false
    o.moveWithMouse = false
    o.dragging = false
    o.dragMoved = false
    o:setWantMouseEvents(true)
    o:setNavigation(navigation)
    return o
end

return SPLNavigationWidget
