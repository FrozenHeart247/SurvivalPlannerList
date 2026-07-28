require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_ItemPicker"

SPLTaskEditor = ISPanel:derive("SPLTaskEditor")

local PAD = 14
local BUTTON_HEIGHT = 30

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

function SPLTaskEditor:initialise()
    ISPanel.initialise(self)
end

function SPLTaskEditor:createChildren()
    ISPanel.createChildren(self)

    local y = 58
    self.titleEntry = ISTextEntryBox:new(self.values.title or "", PAD, y, self.width - PAD * 2, 30)
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self.titleEntry:setClearButton(true)
    self:addChild(self.titleEntry)

    y = self.titleEntry:getBottom() + 38
    self.iconButton = ISButton:new(PAD, y, 190, 54, uiText("SPL_Button_ChooseIcon", "Choose icon"), self, SPLTaskEditor.onChooseIcon)
    self.iconButton:initialise()
    self.iconButton:instantiate()
    self.iconButton.backgroundColor = {r = 0.18, g = 0.16, b = 0.12, a = 1}
    self.iconButton.backgroundColorMouseOver = {r = 0.30, g = 0.25, b = 0.16, a = 1}
    self:addChild(self.iconButton)

    self.targetButton = ISButton:new(
        self.iconButton:getRight() + 12,
        y,
        self.width - self.iconButton:getRight() - PAD - 12,
        54,
        uiText("SPL_Button_LinkItem", "Link item"),
        self,
        SPLTaskEditor.onChooseTarget
    )
    self.targetButton:initialise()
    self.targetButton:instantiate()
    self.targetButton.backgroundColor = {r = 0.18, g = 0.16, b = 0.12, a = 1}
    self.targetButton.backgroundColorMouseOver = {r = 0.30, g = 0.25, b = 0.16, a = 1}
    self:addChild(self.targetButton)

    y = self.iconButton:getBottom() + 10
    self.clearTargetButton = ISButton:new(
        self.targetButton.x,
        y,
        self.targetButton.width,
        26,
        uiText("SPL_Button_ClearLink", "Remove linked item"),
        self,
        SPLTaskEditor.onClearTarget
    )
    self.clearTargetButton:initialise()
    self.clearTargetButton:instantiate()
    self:addChild(self.clearTargetButton)

    local buttonY = self.height - BUTTON_HEIGHT - PAD
    self.saveButton = ISButton:new(
        self.width - PAD - 130,
        buttonY,
        130,
        BUTTON_HEIGHT,
        uiText("UI_Save", "Save"),
        self,
        SPLTaskEditor.onSaveClicked
    )
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self.saveButton:enableAcceptColor()
    self:addChild(self.saveButton)

    self.cancelButton = ISButton:new(
        self.saveButton.x - 110 - 8,
        buttonY,
        110,
        BUTTON_HEIGHT,
        uiText("UI_Cancel", "Cancel"),
        self,
        SPLTaskEditor.onCancel
    )
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    self.cancelButton:enableCancelColor()
    self:addChild(self.cancelButton)

    self:updateItemButtons()
end

function SPLTaskEditor:updateItemButtons()
    local iconEntry = SurvivalPlannerList.getCatalogEntry(self.values.iconType)
    local iconTexture = iconEntry and iconEntry.texture or nil
    self.iconButton:setImage(iconTexture)
    if iconTexture then
        self.iconButton:forceImageSize(38, 38)
        self.iconButton:setTooltip(uiText("SPL_Tooltip_ChangeIcon", "Change task icon"))
    end

    if self.values.targetType then
        local targetName = self.values.targetName or SurvivalPlannerList.getItemName(self.values.targetType)
        self.targetButton:setTitle(targetName)
        self.targetButton:setImage(SurvivalPlannerList.getItemTexture(self.values.targetType))
        self.targetButton:forceImageSize(32, 32)
        self.targetButton:setTooltip(self.values.targetType)
        self.clearTargetButton:setVisible(true)
    else
        self.targetButton:setTitle(uiText("SPL_Button_LinkItem", "Link item"))
        self.targetButton:setImage(nil)
        self.targetButton:setTooltip(uiText("SPL_Tooltip_LinkItem", "Alert and highlight when this item is seen"))
        self.clearTargetButton:setVisible(false)
    end
end

function SPLTaskEditor:onChooseIcon()
    SPLItemPicker.open(
        self.playerNum,
        uiText("SPL_Title_ChooseIcon", "Choose task icon"),
        self.values.iconType,
        self,
        SPLTaskEditor.onItemPicked,
        "icon"
    )
end

function SPLTaskEditor:onChooseTarget()
    SPLItemPicker.open(
        self.playerNum,
        uiText("SPL_Title_LinkItem", "Link an item goal"),
        self.values.targetType,
        self,
        SPLTaskEditor.onItemPicked,
        "target"
    )
end

function SPLTaskEditor:onItemPicked(entry, purpose)
    if purpose == "icon" then
        self.values.iconType = entry.fullType
    else
        self.values.targetType = entry.fullType
        self.values.targetName = entry.name
    end
    self:updateItemButtons()
    getSoundManager():playUISound("UISelectListItem")
end

function SPLTaskEditor:onClearTarget()
    self.values.targetType = nil
    self.values.targetName = nil
    self:updateItemButtons()
end

function SPLTaskEditor:update()
    ISPanel.update(self)
    local title = SurvivalPlannerList.trim(self.titleEntry:getText())
    self.saveButton:setEnable(title ~= "")
end

function SPLTaskEditor:onSaveClicked()
    local title = SurvivalPlannerList.trim(self.titleEntry:getText())
    if title == "" then
        return
    end
    self.values.title = title
    getSoundManager():playUISound("UIActivateButton")
    local onSave = self.onSave
    local saveTarget = self.saveTarget
    local values = self.values
    self:close()
    if onSave then
        onSave(saveTarget, values, self)
    end
end

function SPLTaskEditor:onCancel()
    self:close()
end

function SPLTaskEditor:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SPLTaskEditor:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.98, 0.115, 0.105, 0.085)
    self:drawRect(0, 0, self.width, 42, 1, 0.22, 0.20, 0.15)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.46, 0.41, 0.31)
    self:drawTextCentre(self.titleText, self.width / 2, 10, 0.93, 0.90, 0.78, 1, UIFont.Medium)
    self:drawText(uiText("SPL_Label_TaskTitle", "Task title"), PAD, 42, 0.76, 0.72, 0.61, 1, UIFont.Small)
    self:drawText(uiText("SPL_Label_Icon", "Icon"), PAD, self.iconButton.y - 20, 0.76, 0.72, 0.61, 1, UIFont.Small)
    self:drawText(uiText("SPL_Label_ItemGoal", "Item goal"), self.targetButton.x, self.targetButton.y - 20, 0.76, 0.72, 0.61, 1, UIFont.Small)
end

function SPLTaskEditor:new(playerNum, task, status, saveTarget, onSave)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.min(590, screenWidth - 80)
    local height = 310
    local x = (screenWidth - width) / 2
    local y = (screenHeight - height) / 2
    local o = ISPanel.new(self, x, y, width, height)
    o.playerNum = playerNum or 0
    o.taskId = task and task.id or nil
    o.status = status or SurvivalPlannerList.STATUS_ACTIVE
    o.titleText = task
        and uiText("SPL_Title_EditTask", "Edit task")
        or uiText("SPL_Title_NewTask", "New task")
    o.values = {
        title = task and task.title or "",
        iconType = task and task.iconType or SurvivalPlannerList.DEFAULT_ICON,
        targetType = task and task.targetType or nil,
        targetName = task and task.targetName or nil,
        status = status or (task and task.status) or SurvivalPlannerList.STATUS_ACTIVE,
        taskId = task and task.id or nil,
    }
    o.saveTarget = saveTarget
    o.onSave = onSave
    o.backgroundColor = {r = 0.115, g = 0.105, b = 0.085, a = 0.98}
    o.borderColor = {r = 0.46, g = 0.41, b = 0.31, a = 1}
    return o
end

function SPLTaskEditor.open(playerNum, task, status, saveTarget, onSave)
    local editor = SPLTaskEditor:new(playerNum, task, status, saveTarget, onSave)
    editor:initialise()
    editor:addToUIManager()
    editor:bringToTop()
    return editor
end

return SPLTaskEditor
