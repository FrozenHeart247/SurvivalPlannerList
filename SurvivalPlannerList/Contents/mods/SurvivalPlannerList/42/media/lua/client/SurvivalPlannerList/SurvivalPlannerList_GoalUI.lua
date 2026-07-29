require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"
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

function SPLGoalUI.getTheme(widget)
    if widget.theme then
        return widget.theme
    end
    if widget.target and widget.target.theme then
        return widget.target.theme
    end
    if widget.parent and widget.parent.theme then
        return widget.parent.theme
    end
    return SPLThemes.get(widget.playerNum or 0)
end

function SPLGoalUI.styleButton(button, style)
    local theme = SPLGoalUI.getTheme(button)
    if style == "primary" then
        SPLThemes.styleButton(
            button,
            theme.accent,
            theme.accentHover,
            theme.panelBorder,
            theme.tabActiveText
        )
    elseif style == "danger" then
        SPLThemes.styleButton(
            button,
            theme.danger,
            theme.dangerHover,
            theme.dangerBorder,
            theme.dangerText
        )
    else
        SPLThemes.styleButton(
            button,
            theme.button,
            theme.buttonHover,
            theme.buttonBorder,
            theme.buttonText
        )
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
    local theme = SPLGoalUI.getTheme(self)
    local goal = row.item
    local height = row.height or ROW_HEIGHT
    local contentWidth = self.width - SCROLLBAR_GUTTER
    if self.selected == row.index then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.86, theme.cardSelected.r, theme.cardSelected.g, theme.cardSelected.b)
    elseif self.mouseoverselected == row.index and self:isMouseOver() then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.70, theme.cardHover.r, theme.cardHover.g, theme.cardHover.b)
    elseif alt then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.38, theme.card.r, theme.card.g, theme.card.b)
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
    self:drawText(name, 56, y + 7, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(fullType, 56, y + 28, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)

    local quantityX = contentWidth - quantityWidth - 8
    self:drawRect(quantityX, y + 11, quantityWidth, 30, 0.96, theme.card.r, theme.card.g, theme.card.b)
    self:drawRectBorder(quantityX, y + 11, quantityWidth, 30, 0.92, theme.accent.r, theme.accent.g, theme.accent.b)
    self:drawTextCentre(
        quantityText,
        quantityX + quantityWidth / 2,
        y + 15,
        theme.accent.r,
        theme.accent.g,
        theme.accent.b,
        1,
        UIFont.Medium
    )
    self:drawRectBorder(0, y, contentWidth, height, 0.60, theme.cardBorder.r, theme.cardBorder.g, theme.cardBorder.b)
    return y + height
end

function SPLGoalList:new(x, y, width, height)
    local o = ISScrollingListBox.new(self, x, y, width, height)
    o.itemheight = ROW_HEIGHT
    return o
end

function SPLCheckButton:setChecked(checked)
    self.checked = checked == true
    local theme = SPLGoalUI.getTheme(self)
    if self.checked then
        SPLThemes.styleButton(
            self,
            theme.cardSelected,
            theme.cardHover,
            theme.accent,
            theme.text
        )
    else
        SPLGoalUI.styleButton(self, "neutral")
    end
end

function SPLCheckButton:render()
    local theme = SPLGoalUI.getTheme(self)
    local boxSize = 14
    local boxX = 12
    local boxY = math.floor((self.height - boxSize) / 2)
    local checkColor = theme.mutedText
    if self.checked then
        checkColor = theme.accent
    end
    self:drawRectBorder(boxX, boxY, boxSize, boxSize, 1, checkColor.r, checkColor.g, checkColor.b)
    if self.checked then
        self:drawRect(boxX + 3, boxY + 3, boxSize - 6, boxSize - 6, 1, checkColor.r, checkColor.g, checkColor.b)
    end
    local textY = math.floor((self.height - getTextManager():getFontHeight(UIFont.Small)) / 2)
    self:drawText(self.labelText, boxX + boxSize + 10, textY, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
end

function SPLCheckButton:new(x, y, width, height, labelText, target, callback, checked)
    local o = ISButton.new(self, x, y, width, height, "", target, callback)
    o.labelText = labelText or uiText("SPL_AutoComplete", "Auto-complete")
    o.checked = checked == true
    o:setChecked(o.checked)
    return o
end

return SPLGoalUI
