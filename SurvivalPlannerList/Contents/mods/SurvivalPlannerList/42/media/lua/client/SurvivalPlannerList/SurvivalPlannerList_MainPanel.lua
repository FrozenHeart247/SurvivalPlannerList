require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISResizeWidget"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"
require "SurvivalPlannerList/SurvivalPlannerList_StyledScrollBar"
require "SurvivalPlannerList/SurvivalPlannerList_ItemPicker"
require "SurvivalPlannerList/SurvivalPlannerList_TaskEditor"
require "SurvivalPlannerList/SurvivalPlannerList_SubtaskEditor"
require "SurvivalPlannerList/SurvivalPlannerList_Automation"

SPLPlannerList = ISScrollingListBox:derive("SPLPlannerList")
SPLConfirmDialog = ISPanel:derive("SPLConfirmDialog")
SPLThemeRow = ISButton:derive("SPLThemeRow")
SPLThemeMenu = ISPanel:derive("SPLThemeMenu")
SPLResizeWidget = ISResizeWidget:derive("SPLResizeWidget")
SPLMainPanel = ISPanel:derive("SPLMainPanel")
SPLMainPanel.instances = SPLMainPanel.instances or {}
SPLMainPanel.savedPositions = SPLMainPanel.savedPositions or {}

local PAD = 12
local BUTTON_HEIGHT = 28
local STATUS_HEIGHT = 36
local TAB_HEIGHT = 34
local CARD_GAP = 10
local CARD_SIDE_PAD = 7
local TASK_BOTTOM_PAD = 8
local TASK_MIN_HEADER_HEIGHT = 64
local GOAL_HEIGHT = 22
local SUBTASK_BASE_HEIGHT = 28
local SUBTASK_GOAL_HEIGHT = 20
local SUBTASK_SEPARATOR_HEIGHT = 10
local TRACKING_HEIGHT = 68
local CHECKBOX_SIZE = 14
local SCROLLBAR_GUTTER = 18
local DRAG_THRESHOLD = 5
local FONT_HEIGHT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local DIALOG_BUTTON_WIDTH = 132
local DIALOG_BUTTON_HEIGHT = 30
local PANEL_LAYOUT_KEY = "SurvivalPlannerListPanelLayout"
local THEME_BUTTON_SIZE = 26
local THEME_MENU_WIDTH = 224
local THEME_ROW_HEIGHT = 34
local THEME_ROW_GAP = 4
local MIN_PANEL_WIDTH = 620
local MIN_PANEL_HEIGHT = 430
local RESIZE_HANDLE_SIZE = 18
local RESIZE_BOTTOM_INSET = RESIZE_HANDLE_SIZE + 3

local TAB_ORDER = {
    SurvivalPlannerList.STATUS_ACTIVE,
    SurvivalPlannerList.STATUS_PLANNED,
    SurvivalPlannerList.STATUS_DONE,
    "tracking",
}

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function copyColor(source, alpha)
    return SPLThemes.copyColor(source, alpha)
end

local function styleButton(button, background, hover, border, text)
    SPLThemes.styleButton(button, background, hover, border, text)
end

local function clampUnit(value)
    return math.max(0, math.min(1, tonumber(value) or 0.5))
end

local function savePanelPosition(panel)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local availableWidth = math.max(1, screenWidth - panel.width)
    local availableHeight = math.max(1, screenHeight - panel.height)
    local position = {
        nx = clampUnit(panel.x / availableWidth),
        ny = clampUnit(panel.y / availableHeight),
        width = math.floor(panel.width),
        height = math.floor(panel.height),
    }
    local index = panel.playerNum + 1
    SPLMainPanel.savedPositions[index] = position

    local player = getSpecificPlayer(panel.playerNum)
    if player and player.getModData then
        player:getModData()[PANEL_LAYOUT_KEY] = {
            nx = position.nx,
            ny = position.ny,
            width = position.width,
            height = position.height,
        }
    end
end

local function restorePanelPosition(panel)
    local index = panel.playerNum + 1
    local position = SPLMainPanel.savedPositions[index]
    local player = getSpecificPlayer(panel.playerNum)
    if not position and player and player.getModData then
        local stored = player:getModData()[PANEL_LAYOUT_KEY]
        if type(stored) == "table" then
            position = {
                nx = clampUnit(stored.nx),
                ny = clampUnit(stored.ny),
                width = tonumber(stored.width),
                height = tonumber(stored.height),
            }
        end
    end
    if not position then
        return
    end

    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local maximumWidth = math.max(1, screenWidth - 20)
    local maximumHeight = math.max(1, screenHeight - 20)
    panel.width = math.max(
        math.min(MIN_PANEL_WIDTH, maximumWidth),
        math.min(maximumWidth, tonumber(position.width) or panel.width)
    )
    panel.height = math.max(
        math.min(MIN_PANEL_HEIGHT, maximumHeight),
        math.min(maximumHeight, tonumber(position.height) or panel.height)
    )
    local availableWidth = math.max(0, screenWidth - panel.width)
    local availableHeight = math.max(0, screenHeight - panel.height)
    panel:setX(math.floor(clampUnit(position.nx) * availableWidth))
    panel:setY(math.floor(clampUnit(position.ny) * availableHeight))
end

function SPLResizeWidget:onMouseDown(x, y)
    if not self:getIsVisible() then
        return
    end

    self.resizeStartMouseX = getMouseX()
    self.resizeStartMouseY = getMouseY()
    self.resizeStartWidth = self.target.width
    self.resizeStartHeight = self.target.height
    self.resizing = true
    self:setCapture(true)
    return true
end

function SPLResizeWidget:updateResize()
    if not self.resizing then
        return
    end

    local width = self.resizeStartWidth + (getMouseX() - self.resizeStartMouseX)
    local height = self.resizeStartHeight + (getMouseY() - self.resizeStartMouseY)
    if self.yonly then
        width = self.resizeStartWidth
    end

    if self.resizeFunction then
        self.resizeFunction(self.target, width, height)
    else
        self.target:setWidth(width)
        self.target:setHeight(height)
    end
end

function SPLResizeWidget:onMouseMove(dx, dy)
    self.mouseOver = true
    self:updateResize()
end

function SPLResizeWidget:onMouseMoveOutside(dx, dy)
    self.mouseOver = false
    self:updateResize()
end

function SPLResizeWidget:onMouseUp(x, y)
    local result = ISResizeWidget.onMouseUp(self, x, y)
    savePanelPosition(self.target)
    return result
end

function SPLResizeWidget:onMouseUpOutside(x, y)
    local result = ISResizeWidget.onMouseUpOutside(self, x, y)
    savePanelPosition(self.target)
    return result
end

function SPLResizeWidget:render()
    local theme = self.target and self.target.theme
    if not theme then
        return
    end

    local color = self.mouseOver and theme.accentHover or theme.mutedText
    self:drawLine2(5, self.height - 3, self.width - 3, 5, 1, color.r, color.g, color.b)
    self:drawLine2(10, self.height - 3, self.width - 3, 10, 1, color.r, color.g, color.b)
    self:drawLine2(15, self.height - 3, self.width - 3, 15, 1, color.r, color.g, color.b)
end

local function taskStatusText(status)
    if status == SurvivalPlannerList.STATUS_ACTIVE then
        return uiText("SPL_Tab_Active", "Active")
    elseif status == SurvivalPlannerList.STATUS_PLANNED then
        return uiText("SPL_Tab_Planned", "Planned")
    elseif status == SurvivalPlannerList.STATUS_DONE then
        return uiText("SPL_Tab_Done", "Done")
    end
    return uiText("SPL_Tab_Tracking", "Item Tracking")
end

local function calculateTaskLayout(task, listWidth)
    local cardWidth = listWidth - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2
    local titleMaxWidth = math.max(120, cardWidth - 72 - 52)
    local titleText = getTextManager():WrapText(UIFont.Medium, task.title or "", titleMaxWidth)
    local titleHeight = getTextManager():MeasureStringY(UIFont.Medium, titleText)
    local headerHeight = 8 + titleHeight + 10

    headerHeight = headerHeight + #(task.goals or {}) * GOAL_HEIGHT
    headerHeight = math.max(TASK_MIN_HEADER_HEIGHT, headerHeight)

    return titleText, titleHeight, headerHeight
end

local function calculateSubtaskHeight(subtask)
    return SUBTASK_BASE_HEIGHT + #(subtask.goals or {}) * SUBTASK_GOAL_HEIGHT
end

local function drawGoalLine(list, goal, x, y, maxWidth, iconSize, counts, muted, showProgress)
    local theme = list.ownerPanel and list.ownerPanel.theme or SPLThemes.get(0)
    local current = tonumber(counts and counts[goal.fullType]) or 0
    local required = tonumber(goal.quantity) or 1
    local complete = current >= required
    local texture = SurvivalPlannerList.getItemTexture(goal.fullType)
    if texture then
        list:drawTextureScaledAspect(texture, x, y, iconSize, iconSize, 1, 1, 1, 1)
    end

    local progressText = showProgress == false
        and "x" .. tostring(required)
        or tostring(current) .. "/" .. tostring(required)
    local progressWidth = getTextManager():MeasureStringX(UIFont.Small, progressText)
    local nameWidth = math.max(40, maxWidth - iconSize - 9 - progressWidth - 12)
    local goalName = getTextManager():WrapText(UIFont.Small, goal.name or goal.fullType, nameWidth, 1, "...")
    local color = theme.mutedText
    if complete then
        color = theme.success
    elseif muted then
        color = theme.subtleText
    end
    list:drawText(goalName, x + iconSize + 7, y, color.r, color.g, color.b, 1, UIFont.Small)
    list:drawTextRight(progressText, x + maxWidth, y, color.r, color.g, color.b, 1, UIFont.Small)
end

function SPLPlannerList:doDrawItem(y, row, alt)
    local theme = self.ownerPanel and self.ownerPanel.theme or SPLThemes.get(0)
    local height = row.height or (TASK_MIN_HEADER_HEIGHT + CARD_GAP)
    local data = row.item
    local cardX = CARD_SIDE_PAD
    local cardY = y + CARD_GAP / 2
    local cardWidth = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2
    local cardHeight = height - CARD_GAP
    local selected = self.selected == row.index
    local hovered = self.mouseoverselected == row.index and self:isMouseOver()

    local background = theme.card
    local border = theme.cardBorder
    if selected then
        background = theme.cardSelected
        border = theme.cardSelectedBorder
    elseif hovered then
        background = theme.cardHover
        border = theme.cardHoverBorder
    end
    self:drawRect(cardX, cardY, cardWidth, cardHeight, background.a or 0.98, background.r, background.g, background.b)

    if data.kind == "tracked" then
        local texture = SurvivalPlannerList.getItemTexture(data.fullType)
        self:drawRect(cardX, cardY, 4, cardHeight, 1, theme.accent.r, theme.accent.g, theme.accent.b)
        if texture then
            self:drawTextureScaledAspect(texture, cardX + 16, cardY + 9, 40, 40, 1, 1, 1, 1)
        end
        self:drawText(data.name or data.fullType, cardX + 70, cardY + 9, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
        self:drawText(data.fullType, cardX + 70, cardY + 34, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    else
        local task = data.task
        local accent = theme.success
        if task.status == SurvivalPlannerList.STATUS_PLANNED then
            accent = theme.planned
        elseif task.status == SurvivalPlannerList.STATUS_DONE then
            accent = theme.done
        end
        self:drawRect(cardX, cardY, 4, cardHeight, 1, accent.r, accent.g, accent.b)

        local texture = SurvivalPlannerList.getItemTexture(task.iconType)
        if texture then
            self:drawTextureScaledAspect(texture, cardX + 16, cardY + 11, 42, 42, 1, 1, 1, 1)
        else
            self:drawRectBorder(cardX + 16, cardY + 11, 42, 42, 1, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b)
        end

        local textX = cardX + 72
        local titleText = row.titleText or task.title
        local titleHeight = row.titleHeight or getTextManager():MeasureStringY(UIFont.Medium, titleText)
        local headerHeight = row.headerHeight or TASK_MIN_HEADER_HEIGHT
        self:drawText(titleText, textX, cardY + 8, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)

        local goalY = cardY + 8 + titleHeight + 5
        local goalWidth = cardX + cardWidth - 16 - textX
        for _, goal in ipairs(task.goals or {}) do
            drawGoalLine(
                self,
                goal,
                textX,
                goalY,
                goalWidth,
                18,
                self.ownerPanel.inventoryCounts,
                task.status ~= SurvivalPlannerList.STATUS_ACTIVE,
                task.status ~= SurvivalPlannerList.STATUS_DONE
            )
            goalY = goalY + GOAL_HEIGHT
        end

        local subY = cardY + headerHeight
        if #(task.subtasks or {}) > 0 then
            self:drawRect(
                cardX + 16,
                subY - 5,
                cardWidth - 30,
                1,
                theme.divider.a or 0.78,
                theme.divider.r,
                theme.divider.g,
                theme.divider.b
            )
        end
        for subtaskIndex, subtask in ipairs(task.subtasks or {}) do
            if subtaskIndex > 1 then
                local separatorY = subY + math.floor(SUBTASK_SEPARATOR_HEIGHT / 2)
                self:drawRect(
                    cardX + 20,
                    separatorY,
                    cardWidth - 40,
                    1,
                    theme.divider.a or 0.78,
                    theme.divider.r,
                    theme.divider.g,
                    theme.divider.b
                )
                subY = subY + SUBTASK_SEPARATOR_HEIGHT
            end
            local subtaskHeight = calculateSubtaskHeight(subtask)
            local color = subtask.done and theme.success or theme.text
            local checkboxX = cardX + 20
            local textY = subY + math.floor((SUBTASK_BASE_HEIGHT - FONT_HEIGHT_SMALL) / 2)
            local checkboxY = subY + math.floor((SUBTASK_BASE_HEIGHT - CHECKBOX_SIZE) / 2)
            self:drawRectBorder(checkboxX, checkboxY, CHECKBOX_SIZE, CHECKBOX_SIZE, 1, color.r, color.g, color.b)
            if subtask.done then
                self:drawRect(checkboxX + 3, checkboxY + 3, 8, 8, 1, color.r, color.g, color.b)
            end
            local subtaskTitleWidth = cardX + cardWidth - 44 - (checkboxX + 26)
            local subtaskTitle = getTextManager():WrapText(
                UIFont.Small,
                subtask.title,
                subtaskTitleWidth,
                1,
                "..."
            )
            self:drawText(subtaskTitle, checkboxX + 26, textY, color.r, color.g, color.b, 1, UIFont.Small)
            self:drawTextRight(
                "X",
                cardX + cardWidth - 18,
                textY,
                theme.dangerHover.r,
                theme.dangerHover.g,
                theme.dangerHover.b,
                1,
                UIFont.Small
            )

            local subGoalY = subY + SUBTASK_BASE_HEIGHT
            local subGoalX = checkboxX + 26
            local subGoalWidth = cardX + cardWidth - 28 - subGoalX
            for _, goal in ipairs(subtask.goals or {}) do
                drawGoalLine(
                    self,
                    goal,
                    subGoalX,
                    subGoalY,
                    subGoalWidth,
                    16,
                    self.ownerPanel.inventoryCounts,
                    subtask.done or task.status ~= SurvivalPlannerList.STATUS_ACTIVE,
                    task.status ~= SurvivalPlannerList.STATUS_DONE
                )
                subGoalY = subGoalY + SUBTASK_GOAL_HEIGHT
            end
            subY = subY + subtaskHeight
        end
    end

    self:drawRectBorder(cardX, cardY, cardWidth, cardHeight, border.a or 0.92, border.r, border.g, border.b)
    return y + height
end

function SPLPlannerList:addScrollBars()
    self:removeScrollBars()
    self.vscroll = SPLStyledScrollBar:new(self)
    self.vscroll:initialise()
    self:addChild(self.vscroll)
end

function SPLPlannerList:getDropIndex(contentY)
    local y = 0
    for index, row in ipairs(self.items) do
        local height = row.height or self.itemheight
        if contentY < y + height / 2 then
            return index
        end
        y = y + height
    end
    return #self.items + 1
end

function SPLPlannerList:clearTaskDrag()
    self.dragCandidate = nil
    self.draggingTask = false
    self.dragRow = nil
    self.dropIndex = nil
    if self:getIsCaptured() then
        self:setCapture(false)
    end
end

function SPLPlannerList:onMouseDown(x, y)
    if self:isMouseOverScrollBar() or x >= self.width - SCROLLBAR_GUTTER then
        return
    end

    local contentY = self:getMouseY()
    local rowIndex = self:rowAt(x, contentY)
    local row = self.items[rowIndex]
    if not row then
        return
    end

    getSoundManager():playUISound("UISelectListItem")
    self.selected = rowIndex
    self:invokeOnMouseDownFunction()

    if not self.ownerPanel:isTaskReorderEnabled()
        or not row.item
        or row.item.kind ~= "task" then
        return
    end

    local localY = contentY - self:topOfItem(rowIndex) - CARD_GAP / 2
    local headerHeight = row.headerHeight or TASK_MIN_HEADER_HEIGHT
    local cardRight = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD
    if localY < 0
        or localY >= headerHeight
        or x < CARD_SIDE_PAD + 66
        or x > cardRight then
        return
    end

    self.dragCandidate = row
    self.dragRow = row
    self.dragStartScreenX = getMouseX()
    self.dragStartScreenY = getMouseY()
    self.dropIndex = rowIndex
    self:setCapture(true)
end

function SPLPlannerList:updateTaskDrag()
    if not self.dragCandidate then
        return
    end

    if not self.draggingTask then
        local dx = math.abs(getMouseX() - self.dragStartScreenX)
        local dy = math.abs(getMouseY() - self.dragStartScreenY)
        if dx < DRAG_THRESHOLD and dy < DRAG_THRESHOLD then
            return
        end
        self.draggingTask = true
    end

    local viewportY = self:getMouseY() + self:getYScroll()
    local currentScroll = self:getYScroll()
    if viewportY < 28 then
        self:setYScroll(currentScroll + 12)
    elseif viewportY > self.height - 28 then
        self:setYScroll(currentScroll - 12)
    end
    self.dropIndex = self:getDropIndex(self:getMouseY())
end

function SPLPlannerList:onMouseMove(dx, dy)
    ISScrollingListBox.onMouseMove(self, dx, dy)
    self:updateTaskDrag()
end

function SPLPlannerList:onMouseMoveOutside(dx, dy)
    self.mouseoverselected = -1
    self:updateTaskDrag()
end

function SPLPlannerList:onMouseUp(x, y)
    ISScrollingListBox.onMouseUp(self, x, y)
    if self:isMouseOverScrollBar() then
        self:clearTaskDrag()
        return
    end

    if self.draggingTask and self.dragRow and self.dropIndex then
        local task = self.dragRow.item and self.dragRow.item.task or nil
        local dropIndex = self.dropIndex
        self:clearTaskDrag()
        if task then
            self.ownerPanel:onTaskReordered(task, dropIndex)
        end
        return
    end

    self:clearTaskDrag()
    local contentY = self:getMouseY()
    local rowIndex = self:rowAt(x, contentY)
    local row = self.items[rowIndex]
    if not row or not row.item or row.item.kind ~= "task" then
        return
    end

    local localY = contentY - self:topOfItem(rowIndex) - CARD_GAP / 2
    local task = row.item.task
    local headerHeight = row.headerHeight or TASK_MIN_HEADER_HEIGHT
    if localY >= 0 and localY < headerHeight and x >= CARD_SIDE_PAD and x <= CARD_SIDE_PAD + 66 then
        self.ownerPanel:onTaskIconClicked(task)
        return
    end

    if localY >= headerHeight then
        local subOffset = localY - headerHeight
        for _, subtask in ipairs(task.subtasks or {}) do
            local subtaskHeight = calculateSubtaskHeight(subtask)
            if subOffset < subtaskHeight then
                local inMainLine = subOffset < SUBTASK_BASE_HEIGHT
                if inMainLine and x <= CARD_SIDE_PAD + 48 then
                    self.ownerPanel:onSubtaskToggle(task, subtask)
                elseif inMainLine and x >= self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD - 44 then
                    self.ownerPanel:onSubtaskDelete(task, subtask)
                else
                    self.ownerPanel:onSubtaskEdit(task, subtask)
                end
                return
            end
            subOffset = subOffset - subtaskHeight
        end
    end
end

function SPLPlannerList:onMouseUpOutside(x, y)
    ISScrollingListBox.onMouseUpOutside(self, x, y)
    self:clearTaskDrag()
end

function SPLPlannerList:render()
    ISScrollingListBox.render(self)
    if not self.draggingTask or not self.dragRow or not self.dropIndex then
        return
    end

    local insertY
    if self.dropIndex > #self.items then
        insertY = 0
        for _, row in ipairs(self.items) do
            insertY = insertY + (row.height or self.itemheight)
        end
    else
        insertY = self:topOfItem(self.dropIndex)
    end

    local theme = self.ownerPanel and self.ownerPanel.theme or SPLThemes.get(0)
    local lineX = CARD_SIDE_PAD + 5
    local lineWidth = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2 - 10
    self:drawRect(lineX, insertY - 2, lineWidth, 4, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawRect(lineX - 3, insertY - 4, 4, 8, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawRect(lineX + lineWidth - 1, insertY - 4, 4, 8, 1, theme.accent.r, theme.accent.g, theme.accent.b)

    local ghostHeight = 44
    local ghostY = self:getMouseY() - ghostHeight / 2
    local ghostWidth = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2
    local task = self.dragRow.item.task
    local ghostTitle = getTextManager():WrapText(UIFont.Small, task.title or "", ghostWidth - 28, 1, "...")
    self:drawRect(CARD_SIDE_PAD, ghostY, ghostWidth, ghostHeight, 0.86, theme.cardSelected.r, theme.cardSelected.g, theme.cardSelected.b)
    self:drawRect(CARD_SIDE_PAD, ghostY, 4, ghostHeight, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawRectBorder(CARD_SIDE_PAD, ghostY, ghostWidth, ghostHeight, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawText(ghostTitle, CARD_SIDE_PAD + 16, ghostY + 12, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
end

function SPLPlannerList:new(x, y, width, height, ownerPanel)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.ownerPanel = ownerPanel
    o.itemheight = TASK_MIN_HEADER_HEIGHT + CARD_GAP
    o.dragCandidate = nil
    o.draggingTask = false
    o.dragRow = nil
    o.dropIndex = nil
    return o
end

function SPLThemeRow:render()
    ISButton.render(self)
    local theme = self.rowTheme
    local textHeight = getTextManager():getFontHeight(UIFont.Small)
    local swatchSize = 18
    local swatchY = math.floor((self.height - swatchSize) / 2)
    self:drawRect(10, swatchY, swatchSize, swatchSize, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawRectBorder(10, swatchY, swatchSize, swatchSize, 1, theme.cardBorder.r, theme.cardBorder.g, theme.cardBorder.b)
    self:drawText(
        SPLThemes.getName(theme),
        38,
        math.floor((self.height - textHeight) / 2),
        theme.text.r,
        theme.text.g,
        theme.text.b,
        1,
        UIFont.Small
    )

    if self.menu.ownerPanel.theme.id == theme.id then
        self:drawRect(2, 3, 4, self.height - 6, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    end
end

function SPLThemeRow:new(x, y, width, height, theme, menu)
    local o = ISButton.new(self, x, y, width, height, "", menu, SPLThemeMenu.onThemeSelected)
    o.rowTheme = theme
    o.menu = menu
    o.backgroundColor = copyColor(theme.card)
    o.backgroundColorMouseOver = copyColor(theme.cardHover)
    o.borderColor = copyColor(theme.cardBorder)
    return o
end

function SPLThemeMenu:initialise()
    ISPanel.initialise(self)
end

function SPLThemeMenu:createChildren()
    ISPanel.createChildren(self)
    self.rows = {}
    local rowY = 34
    for _, themeId in ipairs(SPLThemes.ORDER) do
        local theme = SPLThemes.getDefinition(themeId)
        local row = SPLThemeRow:new(
            8,
            rowY,
            self.width - 16,
            THEME_ROW_HEIGHT,
            theme,
            self
        )
        row:initialise()
        row:instantiate()
        self:addChild(row)
        table.insert(self.rows, row)
        rowY = rowY + THEME_ROW_HEIGHT + THEME_ROW_GAP
    end
end

function SPLThemeMenu:onThemeSelected(button)
    self.ownerPanel:applyTheme(button.rowTheme.id, true)
    self:setVisible(false)
end

function SPLThemeMenu:applyTheme(theme)
    self.theme = theme
    self.backgroundColor = copyColor(theme.panel)
    self.borderColor = copyColor(theme.panelBorder)
end

function SPLThemeMenu:prerender()
    ISPanel.prerender(self)
    local theme = self.theme
    self:drawRect(1, 1, self.width - 2, 30, 1, theme.header.r, theme.header.g, theme.header.b)
    self:drawText(
        uiText("SPL_Title_Theme", "Color theme"),
        10,
        8,
        theme.text.r,
        theme.text.g,
        theme.text.b,
        1,
        UIFont.Small
    )
    self:drawRect(8, 31, self.width - 16, 1, 1, theme.headerBorder.r, theme.headerBorder.g, theme.headerBorder.b)
end

function SPLThemeMenu:new(x, y, width, ownerPanel)
    local height = 42 + #SPLThemes.ORDER * THEME_ROW_HEIGHT
        + math.max(0, #SPLThemes.ORDER - 1) * THEME_ROW_GAP
    local o = ISPanel.new(self, x, y, width, height)
    o.ownerPanel = ownerPanel
    o.theme = ownerPanel.theme
    o.background = true
    o.moveWithMouse = false
    o.backgroundColor = copyColor(o.theme.panel)
    o.borderColor = copyColor(o.theme.panelBorder)
    o:setWantMouseEvents(true)
    return o
end

function SPLConfirmDialog:initialise()
    ISPanel.initialise(self)
end

function SPLConfirmDialog:createChildren()
    ISPanel.createChildren(self)

    local buttonY = self.cardY + self.cardHeight - 48
    if self.yesno then
        local gap = 12
        local totalWidth = DIALOG_BUTTON_WIDTH * 2 + gap
        local startX = self.cardX + (self.cardWidth - totalWidth) / 2

        self.cancelButton = ISButton:new(
            startX,
            buttonY,
            DIALOG_BUTTON_WIDTH,
            DIALOG_BUTTON_HEIGHT,
            uiText("SPL_Button_Cancel", "Cancel"),
            self,
            SPLConfirmDialog.onClick
        )
        self.cancelButton.internal = "NO"
        self.cancelButton:initialise()
        self.cancelButton:instantiate()
        styleButton(
            self.cancelButton,
            self.theme.button,
            self.theme.buttonHover,
            self.theme.buttonBorder,
            self.theme.buttonText
        )
        self:addChild(self.cancelButton)

        self.confirmButton = ISButton:new(
            startX + DIALOG_BUTTON_WIDTH + gap,
            buttonY,
            DIALOG_BUTTON_WIDTH,
            DIALOG_BUTTON_HEIGHT,
            uiText("SPL_Button_Confirm", "Confirm"),
            self,
            SPLConfirmDialog.onClick
        )
        self.confirmButton.internal = "YES"
        self.confirmButton:initialise()
        self.confirmButton:instantiate()
        if self.danger then
            styleButton(
                self.confirmButton,
                self.theme.danger,
                self.theme.dangerHover,
                self.theme.dangerBorder,
                self.theme.dangerText
            )
        else
            styleButton(
                self.confirmButton,
                self.theme.accent,
                self.theme.accentHover,
                self.theme.panelBorder,
                self.theme.tabActiveText
            )
        end
        self:addChild(self.confirmButton)
    else
        self.okButton = ISButton:new(
            self.cardX + (self.cardWidth - DIALOG_BUTTON_WIDTH) / 2,
            buttonY,
            DIALOG_BUTTON_WIDTH,
            DIALOG_BUTTON_HEIGHT,
            uiText("UI_Ok", "OK"),
            self,
            SPLConfirmDialog.onClick
        )
        self.okButton.internal = "OK"
        self.okButton:initialise()
        self.okButton:instantiate()
        styleButton(
            self.okButton,
            self.theme.accent,
            self.theme.accentHover,
            self.theme.panelBorder,
            self.theme.tabActiveText
        )
        self:addChild(self.okButton)
    end
end

function SPLConfirmDialog:onClick(button)
    local target = self.target
    local callback = self.callback
    self:setVisible(false)
    self:removeFromUIManager()
    if callback then
        callback(target, button)
    end
end

function SPLConfirmDialog:onMouseDown()
    return true
end

function SPLConfirmDialog:prerender()
    local theme = self.theme
    self:drawRect(0, 0, self.width, self.height, theme.overlay.a, theme.overlay.r, theme.overlay.g, theme.overlay.b)
    self:drawRect(
        self.cardX,
        self.cardY,
        self.cardWidth,
        self.cardHeight,
        theme.dialog.a or 0.99,
        theme.dialog.r,
        theme.dialog.g,
        theme.dialog.b
    )

    local accent = theme.accent
    if self.danger then
        accent = theme.dangerHover
    end
    self:drawRect(self.cardX, self.cardY, 4, self.cardHeight, 1, accent.r, accent.g, accent.b)
    self:drawRectBorder(
        self.cardX,
        self.cardY,
        self.cardWidth,
        self.cardHeight,
        theme.dialogBorder.a or 1,
        theme.dialogBorder.r,
        theme.dialogBorder.g,
        theme.dialogBorder.b
    )

    self:drawText(
        self.titleText,
        self.cardX + 24,
        self.cardY + 18,
        accent.r,
        accent.g,
        accent.b,
        1,
        UIFont.Medium
    )
    self:drawRect(
        self.cardX + 24,
        self.cardY + 48,
        self.cardWidth - 48,
        1,
        theme.divider.a or 0.78,
        theme.divider.r,
        theme.divider.g,
        theme.divider.b
    )
    self:drawText(
        self.wrappedText,
        self.cardX + 24,
        self.cardY + 64,
        theme.text.r,
        theme.text.g,
        theme.text.b,
        1,
        UIFont.Small
    )
end

function SPLConfirmDialog:new(playerNum, message, yesno, target, callback, danger)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local cardWidth = math.min(520, screenWidth - 40)
    local textWidth = cardWidth - 48
    local wrappedText = getTextManager():WrapText(UIFont.Small, message or "", textWidth, 8, "...")
    local textHeight = getTextManager():MeasureStringY(UIFont.Small, wrappedText)
    local cardHeight = math.max(174, 64 + textHeight + 64)
    local o = ISPanel.new(self, 0, 0, screenWidth, screenHeight)
    o.playerNum = playerNum or 0
    o.theme = SPLThemes.get(o.playerNum)
    o.cardWidth = cardWidth
    o.cardHeight = cardHeight
    o.cardX = (screenWidth - cardWidth) / 2
    o.cardY = (screenHeight - cardHeight) / 2
    o.wrappedText = wrappedText
    o.titleText = yesno
        and uiText("SPL_Title_Confirmation", "Confirm action")
        or uiText("SPL_Title_Notice", "Notice")
    o.yesno = yesno == true
    o.target = target
    o.callback = callback
    o.danger = danger == true
    o.background = false
    o.moveWithMouse = false
    o:setWantMouseEvents(true)
    return o
end

function SPLConfirmDialog.open(playerNum, message, yesno, target, callback, danger)
    local dialog = SPLConfirmDialog:new(playerNum, message, yesno, target, callback, danger)
    dialog:initialise()
    dialog:addToUIManager()
    dialog:bringToTop()
    return dialog
end

function SPLMainPanel:initialise()
    ISPanel.initialise(self)
end

function SPLMainPanel:createChildren()
    ISPanel.createChildren(self)

    self.closeButton = ISButton:new(
        self.width - PAD - 26,
        5,
        26,
        26,
        "X",
        self,
        SPLMainPanel.close
    )
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)

    self.themeButton = ISButton:new(
        self.closeButton.x - THEME_BUTTON_SIZE - 4,
        5,
        THEME_BUTTON_SIZE,
        THEME_BUTTON_SIZE,
        "T",
        self,
        SPLMainPanel.onThemeButton
    )
    self.themeButton:initialise()
    self.themeButton:instantiate()
    self.themeButton.tooltip = uiText("SPL_Tooltip_Theme", "Change color theme")
    self:addChild(self.themeButton)

    local tabGap = 4
    local tabY = STATUS_HEIGHT + 5
    local availableWidth = self.width - PAD * 2 - tabGap * (#TAB_ORDER - 1)
    local tabWidth = math.floor(availableWidth / #TAB_ORDER)
    self.tabButtons = {}

    for index, tabId in ipairs(TAB_ORDER) do
        local x = PAD + (index - 1) * (tabWidth + tabGap)
        local width = index == #TAB_ORDER and (self.width - PAD - x) or tabWidth
        local button = ISButton:new(x, tabY, width, TAB_HEIGHT, taskStatusText(tabId), self, SPLMainPanel.onTabClicked)
        button.internal = tabId
        button:initialise()
        button:instantiate()
        self:addChild(button)
        self.tabButtons[tabId] = button
    end

    local listY = tabY + TAB_HEIGHT + 10
    local footerHeight = BUTTON_HEIGHT * 2 + PAD * 3
    self.list = SPLPlannerList:new(PAD, listY, self.width - PAD * 2, self.height - listY - footerHeight, self)
    self.list:initialise()
    self.list:instantiate()
    self.list:setOnMouseDownFunction(self, SPLMainPanel.onSelectionChanged)
    self:addChild(self.list)

    local row1Y = self.list:getBottom() + PAD
    local halfWidth = math.floor((self.width - PAD * 3) / 2)
    self.addButton = self:createFooterButton(PAD, row1Y, halfWidth, uiText("SPL_Button_NewTask", "Create plan"), SPLMainPanel.onAdd)
    self.editButton = self:createFooterButton(PAD * 2 + halfWidth, row1Y, halfWidth, uiText("SPL_Button_Edit", "Edit"), SPLMainPanel.onEdit)

    local row2Y = row1Y + BUTTON_HEIGHT + PAD
    local quarterWidth = math.floor((self.width - PAD * 5) / 4)
    self.subtaskButton = self:createFooterButton(PAD, row2Y, quarterWidth, uiText("SPL_Button_AddSubtask", "Add subtask"), SPLMainPanel.onAddSubtask)
    self.secondaryButton = self:createFooterButton(PAD * 2 + quarterWidth, row2Y, quarterWidth, uiText("SPL_Button_Plan", "Plan"), SPLMainPanel.onSecondaryAction)
    self.primaryButton = self:createFooterButton(PAD * 3 + quarterWidth * 2, row2Y, quarterWidth, uiText("SPL_Button_Complete", "Complete"), SPLMainPanel.onPrimaryAction)
    self.deleteButton = self:createFooterButton(PAD * 4 + quarterWidth * 3, row2Y, self.width - PAD * 5 - quarterWidth * 3, uiText("SPL_Button_DeleteTask", "Delete plan"), SPLMainPanel.onDelete)

    self.resizeWidget = SPLResizeWidget:new(
        self.width - RESIZE_HANDLE_SIZE,
        self.height - RESIZE_HANDLE_SIZE,
        RESIZE_HANDLE_SIZE,
        RESIZE_HANDLE_SIZE,
        self
    )
    self.resizeWidget:initialise()
    self.resizeWidget.resizeFunction = SPLMainPanel.resizeTo
    self:addChild(self.resizeWidget)

    self:layoutChildren(false)
    self:applyTheme(nil, false)
    self:refreshList()
end

function SPLMainPanel:createFooterButton(x, y, width, title, callback)
    local button = ISButton:new(x, y, width, BUTTON_HEIGHT, title, self, callback)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

function SPLMainPanel:reflowListRows()
    if not self.list then
        return
    end

    for _, row in ipairs(self.list.items) do
        local value = row.item
        if value and value.kind == "task" and value.task then
            row.titleText, row.titleHeight, row.headerHeight = calculateTaskLayout(value.task, self.list.width)
            row.height = row.headerHeight + CARD_GAP + TASK_BOTTOM_PAD
            for _, subtask in ipairs(value.task.subtasks or {}) do
                row.height = row.height + calculateSubtaskHeight(subtask)
            end
            row.height = row.height
                + math.max(0, #(value.task.subtasks or {}) - 1) * SUBTASK_SEPARATOR_HEIGHT
        elseif value and value.kind == "tracked" then
            row.height = TRACKING_HEIGHT + CARD_GAP
        end
    end

    local maximumScroll = math.max(0, (self.list:getScrollHeight() or 0) - self.list.height)
    self.list:setYScroll(math.max(-maximumScroll, math.min(0, self.list:getYScroll())))
end

function SPLMainPanel:layoutChildren(reflowRows)
    if not self.closeButton or not self.list then
        return
    end

    self.closeButton:setX(self.width - PAD - self.closeButton.width)
    self.themeButton:setX(self.closeButton.x - THEME_BUTTON_SIZE - 4)

    local tabGap = 4
    local tabY = STATUS_HEIGHT + 5
    local availableWidth = self.width - PAD * 2 - tabGap * (#TAB_ORDER - 1)
    local tabWidth = math.floor(availableWidth / #TAB_ORDER)
    for index, tabId in ipairs(TAB_ORDER) do
        local button = self.tabButtons[tabId]
        local x = PAD + (index - 1) * (tabWidth + tabGap)
        local width = index == #TAB_ORDER and (self.width - PAD - x) or tabWidth
        button:setX(x)
        button:setWidth(width)
    end

    local listY = tabY + TAB_HEIGHT + 10
    local row2Y = self.height - RESIZE_BOTTOM_INSET - BUTTON_HEIGHT
    local row1Y = row2Y - PAD - BUTTON_HEIGHT
    local listBottom = row1Y - PAD
    self.list:setX(PAD)
    self.list:setY(listY)
    self.list:setWidth(self.width - PAD * 2)
    self.list:setHeight(math.max(80, listBottom - listY))

    if self.list.vscroll then
        self.list.vscroll:setX(self.list.width - self.list.vscroll.width - 2)
        self.list.vscroll:setY(0)
        self.list.vscroll:setHeight(self.list.height)
    end

    local halfWidth = math.floor((self.width - PAD * 3) / 2)
    self.addButton:setX(PAD)
    self.addButton:setY(row1Y)
    self.addButton:setWidth(halfWidth)
    self.editButton:setX(PAD * 2 + halfWidth)
    self.editButton:setY(row1Y)
    self.editButton:setWidth(self.width - PAD - self.editButton.x)

    local quarterWidth = math.floor((self.width - PAD * 5) / 4)
    local row2Buttons = {
        self.subtaskButton,
        self.secondaryButton,
        self.primaryButton,
        self.deleteButton,
    }
    for index, button in ipairs(row2Buttons) do
        local x = PAD * index + quarterWidth * (index - 1)
        local width = index == #row2Buttons and (self.width - PAD - x) or quarterWidth
        button:setX(x)
        button:setY(row2Y)
        button:setWidth(width)
    end

    if self.themeMenu then
        self.themeMenu:setX(self.width - PAD - THEME_MENU_WIDTH)
    end
    if self.resizeWidget then
        self.resizeWidget:setX(self.width - RESIZE_HANDLE_SIZE)
        self.resizeWidget:setY(self.height - RESIZE_HANDLE_SIZE)
    end

    if reflowRows ~= false then
        self:reflowListRows()
    end
end

function SPLMainPanel:resizeTo(width, height)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local maximumWidth = math.max(1, screenWidth - self.x)
    local maximumHeight = math.max(1, screenHeight - self.y)
    local minimumWidth = math.min(MIN_PANEL_WIDTH, maximumWidth)
    local minimumHeight = math.min(MIN_PANEL_HEIGHT, maximumHeight)

    width = math.floor(math.max(minimumWidth, math.min(maximumWidth, width)))
    height = math.floor(math.max(minimumHeight, math.min(maximumHeight, height)))
    if width == self.width and height == self.height then
        return
    end

    self:setWidth(width)
    self:setHeight(height)
    self:layoutChildren(true)
end

function SPLMainPanel:onThemeButton()
    if self.themeMenu then
        self.themeMenu:setVisible(not self.themeMenu:getIsVisible())
        return
    end

    self.themeMenu = SPLThemeMenu:new(
        self.width - PAD - THEME_MENU_WIDTH,
        STATUS_HEIGHT + 4,
        THEME_MENU_WIDTH,
        self
    )
    self.themeMenu:initialise()
    self.themeMenu:instantiate()
    self:addChild(self.themeMenu)
end

function SPLMainPanel:applyTheme(themeId, persist)
    if themeId and persist then
        self.theme = SPLThemes.set(self.playerNum, themeId)
    elseif themeId then
        self.theme = SPLThemes.getDefinition(themeId)
    else
        self.theme = SPLThemes.get(self.playerNum)
    end

    local theme = self.theme
    self.backgroundColor = copyColor(theme.panel)
    self.borderColor = copyColor(theme.panelBorder)

    styleButton(
        self.closeButton,
        theme.danger,
        theme.dangerHover,
        theme.dangerBorder,
        theme.dangerText
    )
    styleButton(
        self.themeButton,
        theme.accent,
        theme.accentHover,
        theme.panelBorder,
        theme.tabActiveText
    )

    self.list.theme = theme
    self.list.backgroundColor = copyColor(theme.list)
    self.list.borderColor = copyColor(theme.listBorder)
    self.list.selectionColor = copyColor(theme.cardSelected, 0.82)

    for _, button in ipairs({
        self.addButton,
        self.editButton,
        self.subtaskButton,
        self.secondaryButton,
        self.primaryButton,
    }) do
        styleButton(button, theme.button, theme.buttonHover, theme.buttonBorder, theme.buttonText)
    end
    styleButton(
        self.deleteButton,
        theme.danger,
        theme.dangerHover,
        theme.dangerBorder,
        theme.dangerText
    )

    if self.themeMenu then
        self.themeMenu:applyTheme(theme)
    end

    local data = self:getData()
    if data and self.tabButtons then
        self:updateTabTitles(data)
    end
    if self.list and self.addButton then
        self:updateButtons()
    end
end

function SPLMainPanel:getData()
    return SurvivalPlannerList.getData(self.planner)
end

function SPLMainPanel:getSelectedValue()
    local row = self.list.items[self.list.selected]
    return row and row.item or nil
end

function SPLMainPanel:getSelectedTask()
    local value = self:getSelectedValue()
    return value and value.kind == "task" and value.task or nil
end

function SPLMainPanel:refreshList(selectId)
    local data = self:getData()
    if not data then
        self:close()
        return
    end
    self.inventoryCounts = SurvivalPlannerList.Automation.getCounts(self.playerNum)

    local previous = self:getSelectedValue()
    selectId = selectId or (previous and (previous.id or previous.fullType))
    self.list:clear()
    local selectedIndex = nil

    if self.currentTab == "tracking" then
        for _, tracked in ipairs(data.trackedItems) do
            local value = {
                kind = "tracked",
                fullType = tracked.fullType,
                name = tracked.name,
                id = tracked.fullType,
            }
            local row = self.list:addItem(tracked.name, value)
            row.height = TRACKING_HEIGHT + CARD_GAP
            if selectId == tracked.fullType then
                selectedIndex = #self.list.items
            end
        end
    else
        for _, task in ipairs(data.tasks) do
            if task.status == self.currentTab then
                local row = self.list:addItem(task.title, {kind = "task", task = task, id = task.id})
                row.titleText, row.titleHeight, row.headerHeight = calculateTaskLayout(task, self.list.width)
                row.height = row.headerHeight + CARD_GAP + TASK_BOTTOM_PAD
                for _, subtask in ipairs(task.subtasks or {}) do
                    row.height = row.height + calculateSubtaskHeight(subtask)
                end
                row.height = row.height
                    + math.max(0, #(task.subtasks or {}) - 1) * SUBTASK_SEPARATOR_HEIGHT
                if tonumber(selectId) == tonumber(task.id) then
                    selectedIndex = #self.list.items
                end
            end
        end
    end

    if selectedIndex then
        self.list.selected = selectedIndex
    elseif #self.list.items > 0 then
        self.list.selected = 1
    else
        self.list.selected = -1
    end

    self:updateTabTitles(data)
    self:updateButtons()
end

function SPLMainPanel:updateTabTitles(data)
    local theme = self.theme or SPLThemes.get(self.playerNum)
    local counts = {active = 0, planned = 0, done = 0, tracking = #data.trackedItems}
    for _, task in ipairs(data.tasks) do
        if counts[task.status] ~= nil then
            counts[task.status] = counts[task.status] + 1
        end
    end

    for _, tabId in ipairs(TAB_ORDER) do
        local button = self.tabButtons[tabId]
        button:setTitle(taskStatusText(tabId) .. " (" .. tostring(counts[tabId] or 0) .. ")")
        if tabId == self.currentTab then
            styleButton(
                button,
                theme.tabActive,
                theme.accentHover,
                theme.tabActiveBorder,
                theme.tabActiveText
            )
        else
            styleButton(
                button,
                theme.tab,
                theme.tabHover,
                theme.tabBorder,
                theme.buttonText
            )
        end
    end
end

function SPLMainPanel:updateButtons()
    if not self.addButton then
        return
    end

    local editable = self.editAccess == true
    local selectedTask = self:getSelectedTask()
    local selectedValue = self:getSelectedValue()
    local isTracking = self.currentTab == "tracking"
    local hasSelection = selectedValue ~= nil

    if isTracking then
        self.addButton:setTitle(uiText("SPL_Button_TrackItem", "Track item"))
        self.editButton:setTitle(uiText("SPL_Button_RemoveTracking", "Remove tracking"))
        SPLThemes.setButtonEnabled(self.addButton, editable)
        SPLThemes.setButtonEnabled(self.editButton, editable and hasSelection)
        self.subtaskButton:setVisible(false)
        self.secondaryButton:setVisible(false)
        self.primaryButton:setVisible(false)
        self.deleteButton:setVisible(false)
        return
    end

    self.subtaskButton:setVisible(true)
    self.secondaryButton:setVisible(true)
    self.primaryButton:setVisible(true)
    self.deleteButton:setVisible(true)
    self.addButton:setTitle(
        self.currentTab == SurvivalPlannerList.STATUS_DONE
            and uiText("SPL_Button_ClearDone", "Clear done")
            or uiText("SPL_Button_NewTask", "Create plan")
    )
    SPLThemes.setButtonEnabled(self.addButton, editable and (
        self.currentTab ~= SurvivalPlannerList.STATUS_DONE or #self.list.items > 0
    ))
    self.editButton:setTitle(uiText("SPL_Button_Edit", "Edit"))
    SPLThemes.setButtonEnabled(self.editButton, editable and selectedTask ~= nil)
    SPLThemes.setButtonEnabled(
        self.subtaskButton,
        editable and selectedTask ~= nil and self.currentTab ~= SurvivalPlannerList.STATUS_DONE
    )
    SPLThemes.setButtonEnabled(self.deleteButton, editable and selectedTask ~= nil)

    if self.currentTab == SurvivalPlannerList.STATUS_ACTIVE then
        self.secondaryButton:setTitle(uiText("SPL_Button_Plan", "Move to planned"))
        self.primaryButton:setTitle(uiText("SPL_Button_Complete", "Complete"))
        SPLThemes.setButtonEnabled(self.secondaryButton, editable and selectedTask ~= nil)
        SPLThemes.setButtonEnabled(self.primaryButton, editable and selectedTask ~= nil)
    elseif self.currentTab == SurvivalPlannerList.STATUS_PLANNED then
        self.secondaryButton:setVisible(false)
        self.primaryButton:setTitle(uiText("SPL_Button_Activate", "Make active"))
        SPLThemes.setButtonEnabled(self.primaryButton, editable and selectedTask ~= nil)
    else
        self.secondaryButton:setVisible(false)
        self.primaryButton:setTitle(uiText("SPL_Button_Reopen", "Reopen"))
        SPLThemes.setButtonEnabled(self.primaryButton, editable and selectedTask ~= nil)
        self.subtaskButton:setVisible(false)
    end
end

function SPLMainPanel:onTabClicked(button)
    if self.currentTab == button.internal then
        return
    end
    getSoundManager():playUISound("UIActivateTab")
    self.currentTab = button.internal
    self:refreshList()
end

function SPLMainPanel:onSelectionChanged()
    self:updateButtons()
end

function SPLMainPanel:isTaskReorderEnabled()
    return self.editAccess == true and (
        self.currentTab == SurvivalPlannerList.STATUS_ACTIVE
        or self.currentTab == SurvivalPlannerList.STATUS_PLANNED
    )
end

function SPLMainPanel:onTaskReordered(task, dropIndex)
    if not task or not self:isTaskReorderEnabled() or not self:requireEditAccess() then
        return
    end
    if SurvivalPlannerList.reorderTask(self.planner, task.id, dropIndex) then
        getSoundManager():playUISound("UIActivateButton")
        self:refreshList(task.id)
    end
end

function SPLMainPanel:requireEditAccess()
    local player = getSpecificPlayer(self.playerNum)
    local access, hasWritingTool, hasEraser = SurvivalPlannerList.getEditAccess(player)
    self.editAccess = access
    self.hasWritingTool = hasWritingTool
    self.hasEraser = hasEraser
    self:updateButtons()
    if access then
        return true
    end

    local message
    if not hasWritingTool and not hasEraser then
        message = uiText("SPL_Message_NeedBoth", "You need a writing implement and an eraser to edit this planner.")
    elseif not hasWritingTool then
        message = uiText("SPL_Message_NeedWritingTool", "You need a writing implement to edit this planner.")
    else
        message = uiText("SPL_Message_NeedEraser", "You need an eraser to edit this planner.")
    end
    self:showMessage(message)
    return false
end

function SPLMainPanel:dismissDialog()
    if self.dialog and self.dialog:getIsVisible() then
        self.dialog:setVisible(false)
        self.dialog:removeFromUIManager()
    end
    self.dialog = nil
end

function SPLMainPanel:showMessage(message)
    self:dismissDialog()
    self.dialog = SPLConfirmDialog.open(
        self.playerNum,
        message,
        false,
        self,
        SPLMainPanel.onMessageClosed
    )
end

function SPLMainPanel:onMessageClosed()
    self.dialog = nil
end

function SPLMainPanel:showConfirm(message, action, arg1, arg2, danger)
    self:dismissDialog()
    self.pendingConfirmation = {action = action, arg1 = arg1, arg2 = arg2}
    self.dialog = SPLConfirmDialog.open(
        self.playerNum,
        message,
        true,
        self,
        SPLMainPanel.onConfirmation,
        danger
    )
end

function SPLMainPanel:onConfirmation(button)
    self.dialog = nil
    local pending = self.pendingConfirmation
    self.pendingConfirmation = nil
    if button.internal == "YES" and pending and pending.action then
        pending.action(self, pending.arg1, pending.arg2)
    end
end

function SPLMainPanel:onAdd()
    if not self:requireEditAccess() then
        return
    end
    if self.currentTab == SurvivalPlannerList.STATUS_DONE then
        self:showConfirm(
            uiText("SPL_Confirm_ClearDone", "Delete every completed plan?"),
            SPLMainPanel.doClearDone,
            nil,
            nil,
            true
        )
        return
    end
    if self.currentTab == "tracking" then
        SPLItemPicker.open(
            self.playerNum,
            uiText("SPL_Title_TrackItem", "Choose an item to track"),
            nil,
            self,
            SPLMainPanel.onTrackedItemPicked,
            "tracking"
        )
        return
    end
    SPLTaskEditor.open(self.playerNum, nil, self.currentTab, self, SPLMainPanel.onTaskEditorSave)
end

function SPLMainPanel:onEdit()
    if not self:requireEditAccess() then
        return
    end
    if self.currentTab == "tracking" then
        self:onRemoveTracking()
        return
    end
    local task = self:getSelectedTask()
    if task then
        SPLTaskEditor.open(self.playerNum, task, task.status, self, SPLMainPanel.onTaskEditorSave)
    end
end

function SPLMainPanel:onTaskEditorSave(values)
    if not self:requireEditAccess() then
        return
    end
    local changed
    if values.taskId then
        changed = SurvivalPlannerList.updateTask(self.planner, values.taskId, values)
    else
        local task = SurvivalPlannerList.addTask(self.planner, values)
        changed = task ~= nil
        values.taskId = task and task.id or nil
    end
    if changed then
        self:refreshList(values.taskId)
    end
end

function SPLMainPanel:onTaskIconClicked(task)
    if not task or not self:requireEditAccess() then
        return
    end
    SPLItemPicker.open(
        self.playerNum,
        uiText("SPL_Title_ChooseIcon", "Choose plan icon"),
        task.iconType,
        self,
        SPLMainPanel.onTaskIconPicked,
        task.id,
        "icons"
    )
end

function SPLMainPanel:onTaskIconPicked(entry, taskId)
    if not self:requireEditAccess() then
        return
    end
    if SurvivalPlannerList.setTaskIcon(self.planner, taskId, entry.fullType) then
        self:refreshList(taskId)
    end
end

function SPLMainPanel:onAddSubtask()
    local task = self:getSelectedTask()
    if not task or not self:requireEditAccess() then
        return
    end
    SPLSubtaskEditor.open(
        self.playerNum,
        task.id,
        nil,
        self,
        SPLMainPanel.onSubtaskEditorSave
    )
end

function SPLMainPanel:onSubtaskEdit(task, subtask)
    if not task or not subtask or not self:requireEditAccess() then
        return
    end
    SPLSubtaskEditor.open(
        self.playerNum,
        task.id,
        subtask,
        self,
        SPLMainPanel.onSubtaskEditorSave
    )
end

function SPLMainPanel:onSubtaskEditorSave(values)
    if not self:requireEditAccess() then
        return
    end
    local changed
    if values.subtaskId then
        changed = SurvivalPlannerList.updateSubtask(
            self.planner,
            values.taskId,
            values.subtaskId,
            values
        )
    else
        changed = SurvivalPlannerList.addSubtask(self.planner, values.taskId, values)
    end
    if changed then
        self:refreshList(values.taskId)
    end
end

function SPLMainPanel:onSubtaskToggle(task, subtask)
    if not self:requireEditAccess() then
        return
    end
    if SurvivalPlannerList.toggleSubtask(self.planner, task.id, subtask.id) then
        self:refreshList(task.id)
    end
end

function SPLMainPanel:onSubtaskDelete(task, subtask)
    if not self:requireEditAccess() then
        return
    end
    self:showConfirm(
        uiText("SPL_Confirm_DeleteSubtask", "Delete this subtask?") .. "\n" .. subtask.title,
        SPLMainPanel.doDeleteSubtask,
        task.id,
        subtask.id,
        true
    )
end

function SPLMainPanel:doDeleteSubtask(taskId, subtaskId)
    if SurvivalPlannerList.deleteSubtask(self.planner, taskId, subtaskId) then
        self:refreshList(taskId)
    end
end

function SPLMainPanel:onPrimaryAction()
    local task = self:getSelectedTask()
    if not task or not self:requireEditAccess() then
        return
    end
    local status
    local message
    if self.currentTab == SurvivalPlannerList.STATUS_ACTIVE then
        status = SurvivalPlannerList.STATUS_DONE
        message = uiText("SPL_Confirm_CompleteTask", "Mark this plan as completed?")
    else
        status = SurvivalPlannerList.STATUS_ACTIVE
        message = self.currentTab == SurvivalPlannerList.STATUS_PLANNED
            and uiText("SPL_Confirm_ActivateTask", "Move this plan to Active?")
            or uiText("SPL_Confirm_ReopenTask", "Reopen this completed plan?")
    end
    self:showConfirm(message .. "\n" .. task.title, SPLMainPanel.doSetStatus, task.id, status)
end

function SPLMainPanel:onSecondaryAction()
    local task = self:getSelectedTask()
    if not task or self.currentTab ~= SurvivalPlannerList.STATUS_ACTIVE or not self:requireEditAccess() then
        return
    end
    self:showConfirm(
        uiText("SPL_Confirm_PlanTask", "Move this plan to Planned?") .. "\n" .. task.title,
        SPLMainPanel.doSetStatus,
        task.id,
        SurvivalPlannerList.STATUS_PLANNED
    )
end

function SPLMainPanel:doSetStatus(taskId, status)
    if SurvivalPlannerList.setTaskStatus(self.planner, taskId, status) then
        self:refreshList()
    end
end

function SPLMainPanel:onDelete()
    local task = self:getSelectedTask()
    if not task or not self:requireEditAccess() then
        return
    end
    self:showConfirm(
        uiText("SPL_Confirm_DeleteTask", "Permanently delete this plan?") .. "\n" .. task.title,
        SPLMainPanel.doDeleteTask,
        task.id,
        nil,
        true
    )
end

function SPLMainPanel:doDeleteTask(taskId)
    if SurvivalPlannerList.deleteTask(self.planner, taskId) then
        self:refreshList()
    end
end

function SPLMainPanel:doClearDone()
    if SurvivalPlannerList.clearDone(self.planner) then
        self:refreshList()
    end
end

function SPLMainPanel:onTrackedItemPicked(entry)
    if not self:requireEditAccess() then
        return
    end
    if SurvivalPlannerList.addTrackedItem(self.planner, entry.fullType, entry.name) then
        self:refreshList(entry.fullType)
    else
        self:showMessage(uiText("SPL_Message_AlreadyTracked", "That item is already being tracked."))
    end
end

function SPLMainPanel:onRemoveTracking()
    local value = self:getSelectedValue()
    if not value or value.kind ~= "tracked" or not self:requireEditAccess() then
        return
    end
    self:showConfirm(
        uiText("SPL_Confirm_RemoveTracking", "Stop tracking this item?") .. "\n" .. value.name,
        SPLMainPanel.doRemoveTracking,
        value.fullType,
        nil,
        true
    )
end

function SPLMainPanel:doRemoveTracking(fullType)
    if SurvivalPlannerList.removeTrackedItem(self.planner, fullType) then
        self:refreshList()
    end
end

function SPLMainPanel:updateEditAccess()
    local player = getSpecificPlayer(self.playerNum)
    local snapshot = SurvivalPlannerList.Automation.getSnapshot(self.playerNum)
    if not snapshot and player then
        snapshot = SurvivalPlannerList.Automation.scanPlayer(player)
    end
    local access, hasWritingTool, hasEraser =
        SurvivalPlannerList.Automation.getEditAccess(self.playerNum)
    if access ~= self.editAccess or hasWritingTool ~= self.hasWritingTool or hasEraser ~= self.hasEraser then
        self.editAccess = access
        self.hasWritingTool = hasWritingTool
        self.hasEraser = hasEraser
        self:updateButtons()
    end
end

function SPLMainPanel:prerender()
    self:updateEditAccess()
    self.inventoryCounts = SurvivalPlannerList.Automation.getCounts(self.playerNum)
    ISPanel.prerender(self)

    local theme = self.theme
    self:drawRect(1, 1, self.width - 2, STATUS_HEIGHT - 1, 1, theme.header.r, theme.header.g, theme.header.b)
    self:drawRect(
        1,
        STATUS_HEIGHT,
        self.width - 2,
        1,
        1,
        theme.headerBorder.r,
        theme.headerBorder.g,
        theme.headerBorder.b
    )
    local statusText
    local statusColor = theme.statusEditable
    if self.editAccess then
        statusText = uiText("SPL_Status_Editable", "Writing tool + eraser found — editing enabled")
    else
        statusText = uiText("SPL_Status_ReadOnly", "Read-only — carry a writing tool and an eraser to edit")
        statusColor = theme.statusReadonly
    end
    self:drawTextCentre(
        statusText,
        self.width / 2,
        10,
        statusColor.r,
        statusColor.g,
        statusColor.b,
        1,
        UIFont.Small
    )
end

function SPLMainPanel:render()
    ISPanel.render(self)
end

function SPLMainPanel:close()
    self:dismissDialog()
    self.pendingConfirmation = nil
    savePanelPosition(self)
    SPLMainPanel.instances[self.playerNum + 1] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function SPLMainPanel:new(playerNum, planner)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.min(820, screenWidth - 60)
    local height = math.min(700, screenHeight - 60)
    local x = (screenWidth - width) / 2
    local y = (screenHeight - height) / 2
    local o = ISPanel.new(self, x, y, width, height)
    o.playerNum = playerNum or 0
    o.theme = SPLThemes.get(o.playerNum)
    o.planner = planner
    o.currentTab = SurvivalPlannerList.STATUS_ACTIVE
    o.background = true
    o.moveWithMouse = true
    o.minimumWidth = math.min(MIN_PANEL_WIDTH, math.max(1, screenWidth - 20))
    o.minimumHeight = math.min(MIN_PANEL_HEIGHT, math.max(1, screenHeight - 20))
    o.backgroundColor = copyColor(o.theme.panel)
    o.borderColor = copyColor(o.theme.panelBorder)
    restorePanelPosition(o)
    return o
end

function SPLMainPanel.open(playerNum, planner)
    local existing = SPLMainPanel.instances[(playerNum or 0) + 1]
    if existing then
        existing.planner = planner
        existing:setVisible(true)
        existing:bringToTop()
        existing:refreshList()
        return existing
    end

    local panel = SPLMainPanel:new(playerNum, planner)
    panel:initialise()
    panel:addToUIManager()
    panel:bringToTop()
    SPLMainPanel.instances[(playerNum or 0) + 1] = panel
    getSoundManager():playUISound("UIActivateButton")
    return panel
end

SurvivalPlannerList.openPlannerUI = SPLMainPanel.open

function SPLMainPanel.openTask(playerNum, planner, taskId)
    local data = SurvivalPlannerList.getData(planner)
    local task = data and SurvivalPlannerList.findTask(data, taskId) or nil
    if not task then
        return nil
    end

    local panel = SPLMainPanel.open(playerNum, planner)
    if not panel then
        return nil
    end
    panel.currentTab = task.status
    panel:refreshList(task.id)
    panel:bringToTop()
    return panel
end

SurvivalPlannerList.openPlannerTask = SPLMainPanel.openTask

return SPLMainPanel
