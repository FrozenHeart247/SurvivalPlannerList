require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_StyledScrollBar"
require "SurvivalPlannerList/SurvivalPlannerList_ItemPicker"
require "SurvivalPlannerList/SurvivalPlannerList_TaskEditor"
require "SurvivalPlannerList/SurvivalPlannerList_SubtaskEditor"
require "SurvivalPlannerList/SurvivalPlannerList_Automation"

SPLPlannerList = ISScrollingListBox:derive("SPLPlannerList")
SPLConfirmDialog = ISPanel:derive("SPLConfirmDialog")
SPLMainPanel = ISPanel:derive("SPLMainPanel")
SPLMainPanel.instances = SPLMainPanel.instances or {}

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
local TRACKING_HEIGHT = 68
local CHECKBOX_SIZE = 14
local SCROLLBAR_GUTTER = 18
local DRAG_THRESHOLD = 5
local FONT_HEIGHT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local DIALOG_BUTTON_WIDTH = 132
local DIALOG_BUTTON_HEIGHT = 30

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
    local titleMaxWidth = math.max(120, cardWidth - 72 - 20)
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
    local r, g, b = 0.73, 0.70, 0.55
    if complete then
        r, g, b = 0.52, 0.66, 0.36
    elseif muted then
        r, g, b = 0.55, 0.53, 0.46
    end
    list:drawText(goalName, x + iconSize + 7, y, r, g, b, 1, UIFont.Small)
    list:drawTextRight(progressText, x + maxWidth, y, r, g, b, 1, UIFont.Small)
end

function SPLPlannerList:doDrawItem(y, row, alt)
    local height = row.height or (TASK_MIN_HEADER_HEIGHT + CARD_GAP)
    local data = row.item
    local cardX = CARD_SIDE_PAD
    local cardY = y + CARD_GAP / 2
    local cardWidth = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2
    local cardHeight = height - CARD_GAP
    local selected = self.selected == row.index
    local hovered = self.mouseoverselected == row.index and self:isMouseOver()

    local bgR, bgG, bgB = 0.115, 0.11, 0.09
    local borderR, borderG, borderB = 0.31, 0.29, 0.24
    if selected then
        bgR, bgG, bgB = 0.17, 0.19, 0.13
        borderR, borderG, borderB = 0.42, 0.52, 0.31
    elseif hovered then
        bgR, bgG, bgB = 0.145, 0.135, 0.105
        borderR, borderG, borderB = 0.39, 0.36, 0.28
    end
    self:drawRect(cardX, cardY, cardWidth, cardHeight, 0.98, bgR, bgG, bgB)

    if data.kind == "tracked" then
        local texture = SurvivalPlannerList.getItemTexture(data.fullType)
        self:drawRect(cardX, cardY, 4, cardHeight, 1, 0.43, 0.60, 0.32)
        if texture then
            self:drawTextureScaledAspect(texture, cardX + 16, cardY + 9, 40, 40, 1, 1, 1, 1)
        end
        self:drawText(data.name or data.fullType, cardX + 70, cardY + 9, 0.93, 0.90, 0.78, 1, UIFont.Medium)
        self:drawText(data.fullType, cardX + 70, cardY + 34, 0.57, 0.55, 0.48, 1, UIFont.Small)
    else
        local task = data.task
        local accentR, accentG, accentB = 0.43, 0.60, 0.32
        if task.status == SurvivalPlannerList.STATUS_PLANNED then
            accentR, accentG, accentB = 0.67, 0.52, 0.27
        elseif task.status == SurvivalPlannerList.STATUS_DONE then
            accentR, accentG, accentB = 0.44, 0.47, 0.42
        end
        self:drawRect(cardX, cardY, 4, cardHeight, 1, accentR, accentG, accentB)

        local texture = SurvivalPlannerList.getItemTexture(task.iconType)
        if texture then
            self:drawTextureScaledAspect(texture, cardX + 16, cardY + 11, 42, 42, 1, 1, 1, 1)
        else
            self:drawRectBorder(cardX + 16, cardY + 11, 42, 42, 1, 0.45, 0.40, 0.31)
        end

        local textX = cardX + 72
        local titleText = row.titleText or task.title
        local titleHeight = row.titleHeight or getTextManager():MeasureStringY(UIFont.Medium, titleText)
        local headerHeight = row.headerHeight or TASK_MIN_HEADER_HEIGHT
        self:drawText(titleText, textX, cardY + 8, 0.95, 0.91, 0.78, 1, UIFont.Medium)

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
            self:drawRect(cardX + 16, subY - 5, cardWidth - 30, 1, 0.62, 0.29, 0.28, 0.23)
        end
        for _, subtask in ipairs(task.subtasks or {}) do
            local subtaskHeight = calculateSubtaskHeight(subtask)
            local color = subtask.done
                and {r = 0.47, g = 0.56, b = 0.38}
                or {r = 0.82, g = 0.79, b = 0.68}
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
            self:drawTextRight("X", cardX + cardWidth - 18, textY, 0.72, 0.40, 0.35, 1, UIFont.Small)

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

    self:drawRectBorder(cardX, cardY, cardWidth, cardHeight, 0.92, borderR, borderG, borderB)
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

    local lineX = CARD_SIDE_PAD + 5
    local lineWidth = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2 - 10
    self:drawRect(lineX, insertY - 2, lineWidth, 4, 1, 0.67, 0.73, 0.39)
    self:drawRect(lineX - 3, insertY - 4, 4, 8, 1, 0.67, 0.73, 0.39)
    self:drawRect(lineX + lineWidth - 1, insertY - 4, 4, 8, 1, 0.67, 0.73, 0.39)

    local ghostHeight = 44
    local ghostY = self:getMouseY() - ghostHeight / 2
    local ghostWidth = self.width - SCROLLBAR_GUTTER - CARD_SIDE_PAD * 2
    local task = self.dragRow.item.task
    local ghostTitle = getTextManager():WrapText(UIFont.Small, task.title or "", ghostWidth - 28, 1, "...")
    self:drawRect(CARD_SIDE_PAD, ghostY, ghostWidth, ghostHeight, 0.82, 0.16, 0.18, 0.11)
    self:drawRect(CARD_SIDE_PAD, ghostY, 4, ghostHeight, 1, 0.58, 0.68, 0.34)
    self:drawRectBorder(CARD_SIDE_PAD, ghostY, ghostWidth, ghostHeight, 1, 0.58, 0.68, 0.34)
    self:drawText(ghostTitle, CARD_SIDE_PAD + 16, ghostY + 12, 0.94, 0.91, 0.78, 1, UIFont.Small)
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
        self.cancelButton.backgroundColor = {r = 0.16, g = 0.145, b = 0.115, a = 1}
        self.cancelButton.backgroundColorMouseOver = {r = 0.28, g = 0.24, b = 0.17, a = 1}
        self.cancelButton.borderColor = {r = 0.40, g = 0.36, b = 0.28, a = 1}
        self.cancelButton.textColor = {r = 0.86, g = 0.82, b = 0.71, a = 1}
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
            self.confirmButton.backgroundColor = {r = 0.25, g = 0.075, b = 0.055, a = 1}
            self.confirmButton.backgroundColorMouseOver = {r = 0.55, g = 0.12, b = 0.075, a = 1}
            self.confirmButton.borderColor = {r = 0.62, g = 0.20, b = 0.13, a = 1}
        else
            self.confirmButton.backgroundColor = {r = 0.20, g = 0.24, b = 0.13, a = 1}
            self.confirmButton.backgroundColorMouseOver = {r = 0.34, g = 0.42, b = 0.20, a = 1}
            self.confirmButton.borderColor = {r = 0.46, g = 0.56, b = 0.28, a = 1}
        end
        self.confirmButton.textColor = {r = 0.94, g = 0.90, b = 0.78, a = 1}
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
        self.okButton.backgroundColor = {r = 0.20, g = 0.24, b = 0.13, a = 1}
        self.okButton.backgroundColorMouseOver = {r = 0.34, g = 0.42, b = 0.20, a = 1}
        self.okButton.borderColor = {r = 0.46, g = 0.56, b = 0.28, a = 1}
        self.okButton.textColor = {r = 0.94, g = 0.90, b = 0.78, a = 1}
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
    self:drawRect(0, 0, self.width, self.height, 0.58, 0.015, 0.014, 0.012)
    self:drawRect(
        self.cardX,
        self.cardY,
        self.cardWidth,
        self.cardHeight,
        0.99,
        0.105,
        0.098,
        0.078
    )

    local accentR, accentG, accentB = 0.50, 0.58, 0.31
    if self.danger then
        accentR, accentG, accentB = 0.68, 0.20, 0.13
    end
    self:drawRect(self.cardX, self.cardY, 4, self.cardHeight, 1, accentR, accentG, accentB)
    self:drawRectBorder(
        self.cardX,
        self.cardY,
        self.cardWidth,
        self.cardHeight,
        1,
        0.43,
        0.39,
        0.30
    )

    self:drawText(
        self.titleText,
        self.cardX + 24,
        self.cardY + 18,
        accentR,
        accentG,
        accentB,
        1,
        UIFont.Medium
    )
    self:drawRect(
        self.cardX + 24,
        self.cardY + 48,
        self.cardWidth - 48,
        1,
        0.72,
        0.32,
        0.29,
        0.22
    )
    self:drawText(
        self.wrappedText,
        self.cardX + 24,
        self.cardY + 64,
        0.89,
        0.85,
        0.73,
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
    self.closeButton.backgroundColor = {r = 0.22, g = 0.10, b = 0.08, a = 0.9}
    self.closeButton.backgroundColorMouseOver = {r = 0.58, g = 0.14, b = 0.10, a = 1}
    self.closeButton.borderColor = {r = 0.50, g = 0.25, b = 0.18, a = 1}
    self:addChild(self.closeButton)

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
        button.backgroundColor = {r = 0.18, g = 0.15, b = 0.11, a = 1}
        button.backgroundColorMouseOver = {r = 0.30, g = 0.25, b = 0.16, a = 1}
        self:addChild(button)
        self.tabButtons[tabId] = button
    end

    local listY = tabY + TAB_HEIGHT + 10
    local footerHeight = BUTTON_HEIGHT * 2 + PAD * 3
    self.list = SPLPlannerList:new(PAD, listY, self.width - PAD * 2, self.height - listY - footerHeight, self)
    self.list:initialise()
    self.list:instantiate()
    self.list.backgroundColor = {r = 0.09, g = 0.085, b = 0.07, a = 0.96}
    self.list.borderColor = {r = 0.38, g = 0.34, b = 0.27, a = 1}
    self.list.selectionColor = {r = 0.28, g = 0.34, b = 0.20, a = 0.82}
    self.list:setOnMouseDownFunction(self, SPLMainPanel.onSelectionChanged)
    self:addChild(self.list)

    local row1Y = self.list:getBottom() + PAD
    local halfWidth = math.floor((self.width - PAD * 3) / 2)
    self.addButton = self:createFooterButton(PAD, row1Y, halfWidth, uiText("SPL_Button_NewTask", "Create task"), SPLMainPanel.onAdd)
    self.editButton = self:createFooterButton(PAD * 2 + halfWidth, row1Y, halfWidth, uiText("SPL_Button_Edit", "Edit"), SPLMainPanel.onEdit)

    local row2Y = row1Y + BUTTON_HEIGHT + PAD
    local quarterWidth = math.floor((self.width - PAD * 5) / 4)
    self.subtaskButton = self:createFooterButton(PAD, row2Y, quarterWidth, uiText("SPL_Button_AddSubtask", "Add subtask"), SPLMainPanel.onAddSubtask)
    self.secondaryButton = self:createFooterButton(PAD * 2 + quarterWidth, row2Y, quarterWidth, uiText("SPL_Button_Plan", "Plan"), SPLMainPanel.onSecondaryAction)
    self.primaryButton = self:createFooterButton(PAD * 3 + quarterWidth * 2, row2Y, quarterWidth, uiText("SPL_Button_Complete", "Complete"), SPLMainPanel.onPrimaryAction)
    self.deleteButton = self:createFooterButton(PAD * 4 + quarterWidth * 3, row2Y, self.width - PAD * 5 - quarterWidth * 3, uiText("SPL_Button_DeleteTask", "Delete task"), SPLMainPanel.onDelete)
    self.deleteButton.backgroundColor = {r = 0.22, g = 0.075, b = 0.055, a = 1}
    self.deleteButton.backgroundColorMouseOver = {r = 0.50, g = 0.12, b = 0.075, a = 1}
    self.deleteButton.borderColor = {r = 0.57, g = 0.18, b = 0.12, a = 1}
    self.deleteButton.textColor = {r = 0.92, g = 0.83, b = 0.72, a = 1}

    self:refreshList()
end

function SPLMainPanel:createFooterButton(x, y, width, title, callback)
    local button = ISButton:new(x, y, width, BUTTON_HEIGHT, title, self, callback)
    button:initialise()
    button:instantiate()
    button.backgroundColor = {r = 0.18, g = 0.16, b = 0.12, a = 1}
    button.backgroundColorMouseOver = {r = 0.30, g = 0.25, b = 0.16, a = 1}
    self:addChild(button)
    return button
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
            button.backgroundColor = {r = 0.35, g = 0.28, b = 0.18, a = 1}
            button.borderColor = {r = 0.56, g = 0.50, b = 0.34, a = 1}
        else
            button.backgroundColor = {r = 0.18, g = 0.15, b = 0.11, a = 1}
            button.borderColor = {r = 0.36, g = 0.32, b = 0.27, a = 1}
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
        self.addButton:setEnable(editable)
        self.editButton:setEnable(editable and hasSelection)
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
            or uiText("SPL_Button_NewTask", "Create task")
    )
    self.addButton:setEnable(editable and (
        self.currentTab ~= SurvivalPlannerList.STATUS_DONE or #self.list.items > 0
    ))
    self.editButton:setTitle(uiText("SPL_Button_Edit", "Edit"))
    self.editButton:setEnable(editable and selectedTask ~= nil)
    self.subtaskButton:setEnable(editable and selectedTask ~= nil and self.currentTab ~= SurvivalPlannerList.STATUS_DONE)
    self.deleteButton:setEnable(editable and selectedTask ~= nil)

    if self.currentTab == SurvivalPlannerList.STATUS_ACTIVE then
        self.secondaryButton:setTitle(uiText("SPL_Button_Plan", "Move to planned"))
        self.primaryButton:setTitle(uiText("SPL_Button_Complete", "Complete"))
        self.secondaryButton:setEnable(editable and selectedTask ~= nil)
        self.primaryButton:setEnable(editable and selectedTask ~= nil)
    elseif self.currentTab == SurvivalPlannerList.STATUS_PLANNED then
        self.secondaryButton:setVisible(false)
        self.primaryButton:setTitle(uiText("SPL_Button_Activate", "Make active"))
        self.primaryButton:setEnable(editable and selectedTask ~= nil)
    else
        self.secondaryButton:setVisible(false)
        self.primaryButton:setTitle(uiText("SPL_Button_Reopen", "Reopen"))
        self.primaryButton:setEnable(editable and selectedTask ~= nil)
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
            uiText("SPL_Confirm_ClearDone", "Delete every completed task?"),
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
        uiText("SPL_Title_ChooseIcon", "Choose task icon"),
        task.iconType,
        self,
        SPLMainPanel.onTaskIconPicked,
        task.id
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
        message = uiText("SPL_Confirm_CompleteTask", "Mark this task as completed?")
    else
        status = SurvivalPlannerList.STATUS_ACTIVE
        message = self.currentTab == SurvivalPlannerList.STATUS_PLANNED
            and uiText("SPL_Confirm_ActivateTask", "Move this task to Active?")
            or uiText("SPL_Confirm_ReopenTask", "Reopen this completed task?")
    end
    self:showConfirm(message .. "\n" .. task.title, SPLMainPanel.doSetStatus, task.id, status)
end

function SPLMainPanel:onSecondaryAction()
    local task = self:getSelectedTask()
    if not task or self.currentTab ~= SurvivalPlannerList.STATUS_ACTIVE or not self:requireEditAccess() then
        return
    end
    self:showConfirm(
        uiText("SPL_Confirm_PlanTask", "Move this task to Planned?") .. "\n" .. task.title,
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
        uiText("SPL_Confirm_DeleteTask", "Permanently delete this task?") .. "\n" .. task.title,
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
    local access, hasWritingTool, hasEraser = SurvivalPlannerList.getEditAccess(player)
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

    self:drawRect(1, 1, self.width - 2, STATUS_HEIGHT - 1, 1, 0.14, 0.13, 0.105)
    self:drawRect(1, STATUS_HEIGHT, self.width - 2, 1, 1, 0.34, 0.30, 0.23)
    local statusText
    local r, g, b = 0.55, 0.68, 0.43
    if self.editAccess then
        statusText = uiText("SPL_Status_Editable", "Writing tool + eraser found — editing enabled")
    else
        statusText = uiText("SPL_Status_ReadOnly", "Read-only — carry a writing tool and an eraser to edit")
        r, g, b = 0.78, 0.56, 0.36
    end
    self:drawTextCentre(statusText, self.width / 2, 10, r, g, b, 1, UIFont.Small)
end

function SPLMainPanel:render()
    ISPanel.render(self)
end

function SPLMainPanel:close()
    self:dismissDialog()
    self.pendingConfirmation = nil
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
    o.planner = planner
    o.currentTab = SurvivalPlannerList.STATUS_ACTIVE
    o.background = true
    o.moveWithMouse = true
    o.backgroundColor = {r = 0.115, g = 0.105, b = 0.085, a = 0.98}
    o.borderColor = {r = 0.46, g = 0.41, b = 0.31, a = 1}
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
