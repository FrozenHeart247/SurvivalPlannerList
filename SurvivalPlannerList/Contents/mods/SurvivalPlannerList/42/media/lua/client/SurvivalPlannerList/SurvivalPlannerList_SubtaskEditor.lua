require "ISUI/ISPanel"
require "ISUI/ISButton"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"
require "SurvivalPlannerList/SurvivalPlannerList_TextEntry"
require "SurvivalPlannerList/SurvivalPlannerList_ItemPicker"
require "SurvivalPlannerList/SurvivalPlannerList_GoalUI"

SPLSubtaskEditor = ISPanel:derive("SPLSubtaskEditor")

local PAD = 14
local HEADER_HEIGHT = 42
local BUTTON_HEIGHT = 30

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

function SPLSubtaskEditor:initialise()
    ISPanel.initialise(self)
end

function SPLSubtaskEditor:createChildren()
    ISPanel.createChildren(self)

    self.titleEntry = SPLTextEntry:new(
        self.subtask and self.subtask.title or "",
        PAD,
        70,
        self.width - PAD * 2,
        30,
        self.theme
    )
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self.titleEntry:setClearButton(true)
    self:addChild(self.titleEntry)

    local controlsWidth = 184
    local goalListY = 138
    local goalListWidth = self.width - PAD * 2 - controlsWidth - 12
    local goalListHeight = 174

    self.goalList = SPLGoalList:new(PAD, goalListY, goalListWidth, goalListHeight)
    self.goalList:initialise()
    self.goalList:instantiate()
    self.goalList.target = self
    self.goalList.theme = self.theme
    self.goalList.backgroundColor = SPLThemes.copyColor(self.theme.list)
    self.goalList.borderColor = SPLThemes.copyColor(self.theme.listBorder)
    self.goalList.onmousedown = SPLSubtaskEditor.onGoalSelectionChanged
    self:addChild(self.goalList)

    local controlsX = self.goalList:getRight() + 12
    self.addGoalButton = ISButton:new(
        controlsX,
        goalListY,
        controlsWidth,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_AddGoal", "Add item"),
        self,
        SPLSubtaskEditor.onAddGoal
    )
    self.addGoalButton:initialise()
    self.addGoalButton:instantiate()
    SPLGoalUI.styleButton(self.addGoalButton, "primary")
    self:addChild(self.addGoalButton)

    self.quantityEntry = SPLTextEntry:new(
        "1",
        controlsX,
        goalListY + 66,
        controlsWidth,
        BUTTON_HEIGHT,
        self.theme
    )
    self.quantityEntry:initialise()
    self.quantityEntry:instantiate()
    self.quantityEntry:setOnlyNumbers(true)
    self:addChild(self.quantityEntry)

    self.applyQuantityButton = ISButton:new(
        controlsX,
        goalListY + 104,
        controlsWidth,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_ApplyQuantity", "Apply quantity"),
        self,
        SPLSubtaskEditor.onApplyQuantity
    )
    self.applyQuantityButton:initialise()
    self.applyQuantityButton:instantiate()
    SPLGoalUI.styleButton(self.applyQuantityButton, "neutral")
    self:addChild(self.applyQuantityButton)

    self.removeGoalButton = ISButton:new(
        controlsX,
        goalListY + 142,
        controlsWidth,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_RemoveGoal", "Remove item"),
        self,
        SPLSubtaskEditor.onRemoveGoal
    )
    self.removeGoalButton:initialise()
    self.removeGoalButton:instantiate()
    SPLGoalUI.styleButton(self.removeGoalButton, "danger")
    self:addChild(self.removeGoalButton)

    self.autoButton = SPLCheckButton:new(
        PAD,
        326,
        self.width - PAD * 2,
        34,
        uiText("IGUI_SPL_Check_AutoSubtask", "Auto-complete when all item goals are carried"),
        self,
        SPLSubtaskEditor.onToggleAuto,
        self.autoComplete
    )
    self.autoButton:initialise()
    self.autoButton:instantiate()
    self:addChild(self.autoButton)

    local buttonY = self.height - PAD - BUTTON_HEIGHT
    self.saveButton = ISButton:new(
        self.width - PAD - 132,
        buttonY,
        132,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_Save", "Save"),
        self,
        SPLSubtaskEditor.onSave
    )
    self.saveButton:initialise()
    self.saveButton:instantiate()
    SPLGoalUI.styleButton(self.saveButton, "primary")
    self:addChild(self.saveButton)

    self.cancelButton = ISButton:new(
        self.saveButton.x - 120 - 10,
        buttonY,
        120,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_Cancel", "Cancel"),
        self,
        SPLSubtaskEditor.onCancel
    )
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    SPLGoalUI.styleButton(self.cancelButton, "neutral")
    self:addChild(self.cancelButton)

    self:refreshGoalList()
end

function SPLSubtaskEditor:refreshGoalList(selectedType)
    SPLGoalUI.refreshList(self.goalList, self.goals, selectedType)
    self:onGoalSelectionChanged()
end

function SPLSubtaskEditor:onGoalSelectionChanged()
    local goal = SPLGoalUI.getSelectedGoal(self.goalList)
    if goal then
        self.quantityEntry:setText(tostring(goal.quantity or 1))
    end
    self.quantityEntry:setEditable(goal ~= nil)
    SPLThemes.setButtonEnabled(self.applyQuantityButton, goal ~= nil)
    SPLThemes.setButtonEnabled(self.removeGoalButton, goal ~= nil)
end

function SPLSubtaskEditor:onAddGoal()
    SPLItemPicker.open(
        self.playerNum,
        uiText("IGUI_SPL_Title_AddItemGoal", "Add an item goal"),
        nil,
        self,
        SPLSubtaskEditor.onGoalPicked,
        "goal"
    )
end

function SPLSubtaskEditor:onGoalPicked(entry)
    local index = SPLGoalUI.upsertGoal(self.goals, entry)
    self:refreshGoalList(self.goals[index].fullType)
end

function SPLSubtaskEditor:onApplyQuantity()
    local goal = SPLGoalUI.getSelectedGoal(self.goalList)
    if not goal then
        return
    end
    goal.quantity = SPLGoalUI.parseQuantity(self.quantityEntry:getText())
    self.quantityEntry:setText(tostring(goal.quantity))
    self:refreshGoalList(goal.fullType)
end

function SPLSubtaskEditor:onRemoveGoal()
    local goal = SPLGoalUI.getSelectedGoal(self.goalList)
    if not goal then
        return
    end
    local _, index = SPLGoalUI.findGoal(self.goals, goal.fullType)
    if index then
        table.remove(self.goals, index)
        self:refreshGoalList()
    end
end

function SPLSubtaskEditor:onToggleAuto()
    self.autoComplete = not self.autoComplete
    self.autoButton:setChecked(self.autoComplete)
end

function SPLSubtaskEditor:update()
    ISPanel.update(self)
    local hasTitle = SurvivalPlannerList.trim(self.titleEntry:getText()) ~= ""
    local hasGoals = #self.goals > 0
    SPLThemes.setButtonEnabled(self.saveButton, hasTitle)
    SPLThemes.setButtonEnabled(self.autoButton, hasGoals)
    if not hasGoals and self.autoComplete then
        self.autoComplete = false
        self.autoButton:setChecked(false)
    end
end

function SPLSubtaskEditor:onSave()
    if not self.saveButton.enable then
        return
    end
    self:onApplyQuantity()
    local values = {
        taskId = self.taskId,
        subtaskId = self.subtask and self.subtask.id or nil,
        title = SurvivalPlannerList.trim(self.titleEntry:getText()),
        goals = SPLGoalUI.copyGoals(self.goals),
        autoComplete = self.autoComplete,
    }
    local saveTarget = self.saveTarget
    local onSave = self.onSaveCallback
    self:close()
    if onSave then
        onSave(saveTarget, values)
    end
end

function SPLSubtaskEditor:onCancel()
    self:close()
end

function SPLSubtaskEditor:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SPLSubtaskEditor:prerender()
    local theme = self.theme
    self:drawRect(0, 0, self.width, self.height, theme.panel.a or 0.98, theme.panel.r, theme.panel.g, theme.panel.b)
    self:drawRect(0, 0, self.width, HEADER_HEIGHT, 1, theme.header.r, theme.header.g, theme.header.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, theme.panelBorder.r, theme.panelBorder.g, theme.panelBorder.b)
    self:drawTextCentre(self.windowTitle, self.width / 2, 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
    self:drawText(uiText("IGUI_SPL_Label_SubtaskTitle", "Subtask title"), PAD, 47, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawText(uiText("IGUI_SPL_Label_ItemGoals", "Item goals"), PAD, 115, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawText(
        uiText("IGUI_SPL_Label_Quantity", "Quantity"),
        self.quantityEntry.x,
        self.quantityEntry.y - 22,
        theme.mutedText.r,
        theme.mutedText.g,
        theme.mutedText.b,
        1,
        UIFont.Small
    )
    if #self.goals == 0 then
        self:drawTextCentre(
            uiText("IGUI_SPL_Label_NoGoals", "No item goals"),
            self.goalList.x + self.goalList.width / 2,
            self.goalList.y + 76,
            theme.subtleText.r,
            theme.subtleText.g,
            theme.subtleText.b,
            1,
            UIFont.Small
        )
    end
    self:drawText(
        uiText("IGUI_SPL_Hint_AutoTools", "Automatic completion requires a writing tool and an eraser."),
        PAD + 2,
        366,
        theme.subtleText.r,
        theme.subtleText.g,
        theme.subtleText.b,
        1,
        UIFont.Small
    )
end

function SPLSubtaskEditor:new(playerNum, taskId, subtask, saveTarget, onSave)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.min(630, screenWidth - 60)
    local height = math.min(444, screenHeight - 60)
    local o = ISPanel.new(self, (screenWidth - width) / 2, (screenHeight - height) / 2, width, height)
    o.playerNum = playerNum or 0
    o.theme = SPLThemes.get(o.playerNum)
    o.taskId = taskId
    o.subtask = subtask
    o.saveTarget = saveTarget
    o.onSaveCallback = onSave
    o.windowTitle = subtask
        and uiText("IGUI_SPL_Title_EditSubtask", "Edit subtask")
        or uiText("IGUI_SPL_Title_NewSubtask", "New subtask")
    o.goals = SPLGoalUI.copyGoals(subtask and subtask.goals or nil)
    o.autoComplete = subtask and subtask.autoComplete == true or false
    o.backgroundColor = SPLThemes.copyColor(o.theme.panel)
    o.borderColor = SPLThemes.copyColor(o.theme.panelBorder)
    o.moveWithMouse = true
    return o
end

function SPLSubtaskEditor.open(playerNum, taskId, subtask, saveTarget, onSave)
    local editor = SPLSubtaskEditor:new(playerNum, taskId, subtask, saveTarget, onSave)
    editor:initialise()
    editor:addToUIManager()
    editor:bringToTop()
    return editor
end

return SPLSubtaskEditor
