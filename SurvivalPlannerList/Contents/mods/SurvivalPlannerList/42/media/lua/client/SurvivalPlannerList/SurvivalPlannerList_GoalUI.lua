require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_StyledScrollBar"

SPLGoalUI = SPLGoalUI or {}
SPLGoalList = ISScrollingListBox:derive("SPLGoalList")
SPLCheckButton = ISButton:derive("SPLCheckButton")

local ROW_HEIGHT = 52
local SCROLLBAR_GUTTER = 18

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

function SPLGoalUI.styleButton(button, style)
    button.textColor = {r = 0.92, g = 0.88, b = 0.76, a = 1}
    if style == "primary" then
        button.backgroundColor = {r = 0.16, g = 0.25, b = 0.105, a = 1}
        button.backgroundColorMouseOver = {r = 0.29, g = 0.43, b = 0.16, a = 1}
        button.borderColor = {r = 0.42, g = 0.57, b = 0.25, a = 1}
    elseif style == "danger" then
        button.backgroundColor = {r = 0.22, g = 0.075, b = 0.055, a = 1}
        button.backgroundColorMouseOver = {r = 0.50, g = 0.12, b = 0.075, a = 1}
        button.borderColor = {r = 0.57, g = 0.18, b = 0.12, a = 1}
    else
        button.backgroundColor = {r = 0.18, g = 0.16, b = 0.12, a = 1}
        button.backgroundColorMouseOver = {r = 0.30, g = 0.25, b = 0.16, a = 1}
        button.borderColor = {r = 0.40, g = 0.36, b = 0.28, a = 1}
    end
end

function SPLGoalUI.copyGoals(goals)
    return SurvivalPlannerList.copyGoals(goals)
end

function SPLGoalUI.parseQuantity(value)
    return math.max(1, math.min(9999, math.floor(tonumber(value) or 1)))
end

function SPLGoalUI.getSelectedGoal(list)
    local row = list and list.items[list.selected] or nil
    return row and row.item or nil
end

function SPLGoalUI.findGoal(goals, fullType)
    for index, goal in ipairs(goals or {}) do
        if goal.fullType == fullType then
            return goal, index
        end
    end
    return nil, nil
end

function SPLGoalUI.upsertGoal(goals, entry)
    local existing, index = SPLGoalUI.findGoal(goals, entry.fullType)
    if existing then
        existing.name = entry.name or existing.name
        return index
    end
    table.insert(goals, {
        kind = "item",
        fullType = entry.fullType,
        name = entry.name or entry.fullType,
        quantity = 1,
    })
    return #goals
end

function SPLGoalUI.refreshList(list, goals, selectedType)
    selectedType = selectedType or (SPLGoalUI.getSelectedGoal(list) and SPLGoalUI.getSelectedGoal(list).fullType)
    list:clear()
    local selectedIndex = nil
    for _, goal in ipairs(goals or {}) do
        list:addItem(goal.name or goal.fullType, goal)
        if goal.fullType == selectedType then
            selectedIndex = #list.items
        end
    end
    if selectedIndex then
        list.selected = selectedIndex
    elseif #list.items > 0 then
        list.selected = 1
    else
        list.selected = -1
    end
end

function SPLGoalList:addScrollBars()
    self:removeScrollBars()
    self.vscroll = SPLStyledScrollBar:new(self)
    self.vscroll:initialise()
    self:addChild(self.vscroll)
end

function SPLGoalList:doDrawItem(y, row, alt)
    local goal = row.item
    local height = row.height or ROW_HEIGHT
    local contentWidth = self.width - SCROLLBAR_GUTTER
    if self.selected == row.index then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.86, 0.22, 0.28, 0.15)
    elseif self.mouseoverselected == row.index and self:isMouseOver() then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.48, 0.20, 0.18, 0.13)
    elseif alt then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.30, 0.13, 0.12, 0.10)
    end

    local texture = SurvivalPlannerList.getItemTexture(goal.fullType)
    if texture then
        self:drawTextureScaledAspect(texture, 9, y + 7, 38, 38, 1, 1, 1, 1)
    end

    local quantityText = "x" .. tostring(goal.quantity or 1)
    local quantityWidth = getTextManager():MeasureStringX(UIFont.Medium, quantityText) + 18
    local textWidth = contentWidth - 64 - quantityWidth
    local name = getTextManager():WrapText(UIFont.Small, goal.name or goal.fullType, textWidth, 1, "...")
    local fullType = getTextManager():WrapText(UIFont.Small, goal.fullType or "", textWidth, 1, "...")
    self:drawText(name, 56, y + 7, 0.93, 0.90, 0.78, 1, UIFont.Small)
    self:drawText(fullType, 56, y + 28, 0.56, 0.54, 0.47, 1, UIFont.Small)

    local quantityX = contentWidth - quantityWidth - 8
    self:drawRect(quantityX, y + 11, quantityWidth, 30, 0.96, 0.15, 0.17, 0.10)
    self:drawRectBorder(quantityX, y + 11, quantityWidth, 30, 0.92, 0.42, 0.50, 0.27)
    self:drawTextCentre(
        quantityText,
        quantityX + quantityWidth / 2,
        y + 15,
        0.79,
        0.82,
        0.58,
        1,
        UIFont.Medium
    )
    self:drawRectBorder(0, y, contentWidth, height, 0.60, 0.35, 0.32, 0.27)
    return y + height
end

function SPLGoalList:new(x, y, width, height)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.itemheight = ROW_HEIGHT
    o.backgroundColor = {r = 0.075, g = 0.070, b = 0.055, a = 0.98}
    o.borderColor = {r = 0.38, g = 0.34, b = 0.27, a = 1}
    return o
end

function SPLCheckButton:setChecked(checked)
    self.checked = checked == true
    if self.checked then
        self.backgroundColor = {r = 0.17, g = 0.23, b = 0.11, a = 1}
        self.backgroundColorMouseOver = {r = 0.28, g = 0.38, b = 0.15, a = 1}
        self.borderColor = {r = 0.43, g = 0.55, b = 0.27, a = 1}
    else
        SPLGoalUI.styleButton(self, "neutral")
    end
end

function SPLCheckButton:render()
    local boxSize = 14
    local boxX = 12
    local boxY = math.floor((self.height - boxSize) / 2)
    local r, g, b = 0.68, 0.65, 0.54
    if self.checked then
        r, g, b = 0.61, 0.72, 0.38
    end
    self:drawRectBorder(boxX, boxY, boxSize, boxSize, 1, r, g, b)
    if self.checked then
        self:drawRect(boxX + 3, boxY + 3, boxSize - 6, boxSize - 6, 1, r, g, b)
    end
    local textY = math.floor((self.height - getTextManager():getFontHeight(UIFont.Small)) / 2)
    self:drawText(self.labelText, boxX + boxSize + 10, textY, 0.91, 0.87, 0.75, 1, UIFont.Small)
end

function SPLCheckButton:new(x, y, width, height, labelText, target, callback, checked)
    local o = ISButton.new(self, x, y, width, height, "", target, callback)
    o.labelText = labelText or uiText("SPL_AutoComplete", "Auto-complete")
    o.checked = checked == true
    o:setChecked(o.checked)
    return o
end

return SPLGoalUI
