require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_ItemPicker"
require "SurvivalPlannerList/SurvivalPlannerList_GoalUI"
require "SurvivalPlannerList/SurvivalPlannerList_MapIntegration"

SPLTaskEditor = ISPanel:derive("SPLTaskEditor")

local PAD = 14
local HEADER_HEIGHT = 42
local BUTTON_HEIGHT = 30
local PREVIEW_SIZE = 58

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function styleEntry(entry)
    entry.backgroundColor = {r = 0.055, g = 0.052, b = 0.043, a = 1}
    entry.borderColor = {r = 0.40, g = 0.36, b = 0.28, a = 1}
end

function SPLTaskEditor:initialise()
    ISPanel.initialise(self)
end

function SPLTaskEditor:createChildren()
    ISPanel.createChildren(self)

    self.titleEntry = ISTextEntryBox:new(self.task and self.task.title or "", PAD, 70, self.width - PAD * 2, 30)
    self.titleEntry:initialise()
    self.titleEntry:instantiate()
    self.titleEntry:setClearButton(true)
    styleEntry(self.titleEntry)
    self:addChild(self.titleEntry)

    self.iconButton = ISButton:new(
        PAD + PREVIEW_SIZE + 12,
        145,
        180,
        BUTTON_HEIGHT,
        uiText("SPL_Button_ChooseIcon", "Choose icon"),
        self,
        SPLTaskEditor.onChooseIcon
    )
    self.iconButton:initialise()
    self.iconButton:instantiate()
    SPLGoalUI.styleButton(self.iconButton, "neutral")
    self:addChild(self.iconButton)

    local mapPanelY = 227
    local mapPanelHeight = 108
    local mapButtonY = mapPanelY + 35
    local mapButtonGap = 10
    local mapButtonWidth = math.floor((self.width - PAD * 2 - mapButtonGap * 2) / 3)

    self.chooseMapButton = ISButton:new(
        PAD,
        mapButtonY,
        mapButtonWidth,
        BUTTON_HEIGHT,
        uiText("SPL_Button_ChooseMapTarget", "Choose on map"),
        self,
        SPLTaskEditor.onChooseMapTarget
    )
    self.chooseMapButton:initialise()
    self.chooseMapButton:instantiate()
    SPLGoalUI.styleButton(self.chooseMapButton, "primary")
    self:addChild(self.chooseMapButton)

    self.currentPositionButton = ISButton:new(
        self.chooseMapButton:getRight() + mapButtonGap,
        mapButtonY,
        mapButtonWidth,
        BUTTON_HEIGHT,
        uiText("SPL_Button_CurrentPosition", "Use current position"),
        self,
        SPLTaskEditor.onUseCurrentPosition
    )
    self.currentPositionButton:initialise()
    self.currentPositionButton:instantiate()
    SPLGoalUI.styleButton(self.currentPositionButton, "neutral")
    self:addChild(self.currentPositionButton)

    self.clearMapButton = ISButton:new(
        self.currentPositionButton:getRight() + mapButtonGap,
        mapButtonY,
        mapButtonWidth,
        BUTTON_HEIGHT,
        uiText("SPL_Button_ClearMapTarget", "Clear target"),
        self,
        SPLTaskEditor.onClearMapTarget
    )
    self.clearMapButton:initialise()
    self.clearMapButton:instantiate()
    SPLGoalUI.styleButton(self.clearMapButton, "danger")
    self:addChild(self.clearMapButton)

    self.navigationButton = SPLCheckButton:new(
        PAD,
        mapPanelY + 72,
        self.width - PAD * 2,
        30,
        uiText("SPL_Check_TrackTask", "Show map marker and direction indicator"),
        self,
        SPLTaskEditor.onToggleNavigation,
        self.navigationEnabled
    )
    self.navigationButton:initialise()
    self.navigationButton:instantiate()
    self:addChild(self.navigationButton)

    local controlsWidth = 190
    local goalListX = PAD
    local goalListY = 371
    local goalListWidth = self.width - PAD * 2 - controlsWidth - 12
    local goalListHeight = 168

    self.goalList = SPLGoalList:new(goalListX, goalListY, goalListWidth, goalListHeight)
    self.goalList:initialise()
    self.goalList:instantiate()
    self.goalList.target = self
    self.goalList.onmousedown = SPLTaskEditor.onGoalSelectionChanged
    self:addChild(self.goalList)

    local controlsX = self.goalList:getRight() + 12
    self.addGoalButton = ISButton:new(
        controlsX,
        goalListY,
        controlsWidth,
        BUTTON_HEIGHT,
        uiText("SPL_Button_AddGoal", "Add item"),
        self,
        SPLTaskEditor.onAddGoal
    )
    self.addGoalButton:initialise()
    self.addGoalButton:instantiate()
    SPLGoalUI.styleButton(self.addGoalButton, "primary")
    self:addChild(self.addGoalButton)

    self.quantityEntry = ISTextEntryBox:new("1", controlsX, goalListY + 66, controlsWidth, BUTTON_HEIGHT)
    self.quantityEntry:initialise()
    self.quantityEntry:instantiate()
    self.quantityEntry:setOnlyNumbers(true)
    styleEntry(self.quantityEntry)
    self:addChild(self.quantityEntry)

    self.applyQuantityButton = ISButton:new(
        controlsX,
        goalListY + 104,
        controlsWidth,
        BUTTON_HEIGHT,
        uiText("SPL_Button_ApplyQuantity", "Apply quantity"),
        self,
        SPLTaskEditor.onApplyQuantity
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
        uiText("SPL_Button_RemoveGoal", "Remove item"),
        self,
        SPLTaskEditor.onRemoveGoal
    )
    self.removeGoalButton:initialise()
    self.removeGoalButton:instantiate()
    SPLGoalUI.styleButton(self.removeGoalButton, "danger")
    self:addChild(self.removeGoalButton)

    self.autoButton = SPLCheckButton:new(
        PAD,
        551,
        self.width - PAD * 2,
        34,
        uiText("SPL_Check_AutoTask", "Auto-complete when all goals and subtasks are complete"),
        self,
        SPLTaskEditor.onToggleAuto,
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
        uiText("SPL_Button_Save", "Save"),
        self,
        SPLTaskEditor.onSave
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
        uiText("SPL_Button_Cancel", "Cancel"),
        self,
        SPLTaskEditor.onCancel
    )
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    SPLGoalUI.styleButton(self.cancelButton, "neutral")
    self:addChild(self.cancelButton)

    self:refreshGoalList()
end

function SPLTaskEditor:refreshGoalList(selectedType)
    SPLGoalUI.refreshList(self.goalList, self.goals, selectedType)
    self:onGoalSelectionChanged()
end

function SPLTaskEditor:onGoalSelectionChanged()
    local goal = SPLGoalUI.getSelectedGoal(self.goalList)
    if goal then
        self.quantityEntry:setText(tostring(goal.quantity or 1))
    end
    self.quantityEntry:setEditable(goal ~= nil)
    self.applyQuantityButton:setEnable(goal ~= nil)
    self.removeGoalButton:setEnable(goal ~= nil)
end

function SPLTaskEditor:onChooseIcon()
    SPLItemPicker.open(
        self.playerNum,
        uiText("SPL_Title_ChooseIcon", "Choose task icon"),
        self.iconType,
        self,
        SPLTaskEditor.onIconPicked,
        "icon"
    )
end

function SPLTaskEditor:onIconPicked(entry)
    self.iconType = entry.fullType
end

function SPLTaskEditor:getMapTarget()
    if type(self.mapTargets) ~= "table" then
        return nil
    end
    return self.mapTargets[1]
end

function SPLTaskEditor:onChooseMapTarget()
    local editor = self
    local opened = SPLMapIntegration.beginPlacement(
        self.playerNum,
        self:getMapTarget(),
        function(target)
            if target then
                if SurvivalPlannerList.trim(target.name) == "" then
                    target.name = uiText("SPL_Map_Target", "Map target")
                end
                editor.mapTargets = {target}
                editor.trackedTargetId = target.id
            end
            editor:setVisible(true)
            editor:bringToTop()
        end
    )
    if opened then
        self:setVisible(false)
    end
end

function SPLTaskEditor:onUseCurrentPosition()
    local player = getSpecificPlayer(self.playerNum)
    if not player then
        return
    end
    local current = self:getMapTarget() or {}
    local target = {
        id = current.id,
        name = uiText("SPL_Map_CurrentPosition", "Current position"),
        x = player:getX(),
        y = player:getY(),
        z = math.floor(player:getZ()),
        radius = current.radius or 15,
    }
    self.mapTargets = {target}
    self.trackedTargetId = target.id
end

function SPLTaskEditor:onClearMapTarget()
    self.mapTargets = {}
    self.trackedTargetId = nil
    self.navigationEnabled = false
    self.navigationButton:setChecked(false)
end

function SPLTaskEditor:onToggleNavigation()
    if not self:getMapTarget() or self.status == SurvivalPlannerList.STATUS_DONE then
        return
    end
    self.navigationEnabled = not self.navigationEnabled
    self.navigationButton:setChecked(self.navigationEnabled)
end

function SPLTaskEditor:onAddGoal()
    SPLItemPicker.open(
        self.playerNum,
        uiText("SPL_Title_AddItemGoal", "Add an item goal"),
        nil,
        self,
        SPLTaskEditor.onGoalPicked,
        "goal"
    )
end

function SPLTaskEditor:onGoalPicked(entry)
    local index = SPLGoalUI.upsertGoal(self.goals, entry)
    self:refreshGoalList(self.goals[index].fullType)
end

function SPLTaskEditor:onApplyQuantity()
    local goal = SPLGoalUI.getSelectedGoal(self.goalList)
    if not goal then
        return
    end
    goal.quantity = SPLGoalUI.parseQuantity(self.quantityEntry:getText())
    self.quantityEntry:setText(tostring(goal.quantity))
    self:refreshGoalList(goal.fullType)
end

function SPLTaskEditor:onRemoveGoal()
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

function SPLTaskEditor:onToggleAuto()
    self.autoComplete = not self.autoComplete
    self.autoButton:setChecked(self.autoComplete)
end

function SPLTaskEditor:update()
    ISPanel.update(self)
    local hasTitle = SurvivalPlannerList.trim(self.titleEntry:getText()) ~= ""
    local hasCondition = #self.goals > 0 or self.hasSubtasks
    self.saveButton:setEnable(hasTitle)
    self.autoButton:setEnable(hasCondition)
    local hasMapTarget = self:getMapTarget() ~= nil
    local canNavigate = hasMapTarget and self.status ~= SurvivalPlannerList.STATUS_DONE
    self.navigationButton:setEnable(canNavigate)
    self.clearMapButton:setEnable(hasMapTarget)
    if not canNavigate and self.navigationEnabled then
        self.navigationEnabled = false
        self.navigationButton:setChecked(false)
    end
    if not hasCondition and self.autoComplete then
        self.autoComplete = false
        self.autoButton:setChecked(false)
    end
end

function SPLTaskEditor:onSave()
    if not self.saveButton.enable then
        return
    end
    self:onApplyQuantity()
    local values = {
        taskId = self.task and self.task.id or nil,
        title = SurvivalPlannerList.trim(self.titleEntry:getText()),
        iconType = self.iconType,
        goals = SPLGoalUI.copyGoals(self.goals),
        mapTargets = SurvivalPlannerList.copyMapTargets(self.mapTargets),
        trackedTargetId = self.trackedTargetId,
        navigationEnabled = self.navigationEnabled,
        autoComplete = self.autoComplete,
        status = self.status,
    }
    local saveTarget = self.saveTarget
    local onSave = self.onSaveCallback
    self:close()
    if onSave then
        onSave(saveTarget, values)
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
    self:drawRect(0, 0, self.width, HEADER_HEIGHT, 1, 0.22, 0.20, 0.15)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.46, 0.41, 0.31)
    self:drawTextCentre(self.windowTitle, self.width / 2, 10, 0.93, 0.90, 0.78, 1, UIFont.Medium)

    self:drawText(uiText("SPL_Label_TaskTitle", "Task title"), PAD, 47, 0.78, 0.75, 0.65, 1, UIFont.Small)
    self:drawText(uiText("SPL_Label_Icon", "Icon"), PAD, 112, 0.78, 0.75, 0.65, 1, UIFont.Small)
    self:drawRect(PAD, 137, PREVIEW_SIZE, PREVIEW_SIZE, 0.96, 0.075, 0.07, 0.055)
    self:drawRectBorder(PAD, 137, PREVIEW_SIZE, PREVIEW_SIZE, 1, 0.40, 0.36, 0.28)
    local icon = SurvivalPlannerList.getItemTexture(self.iconType)
    if icon then
        self:drawTextureScaledAspect(icon, PAD + 6, 143, PREVIEW_SIZE - 12, PREVIEW_SIZE - 12, 1, 1, 1, 1)
    end

    self:drawText(uiText("SPL_Label_MapTarget", "Map target"), PAD, 203, 0.78, 0.75, 0.65, 1, UIFont.Small)
    self:drawRect(PAD, 227, self.width - PAD * 2, 108, 0.80, 0.075, 0.070, 0.055)
    self:drawRectBorder(PAD, 227, self.width - PAD * 2, 108, 0.75, 0.38, 0.34, 0.27)
    local mapTarget = self:getMapTarget()
    local mapTargetText = uiText("SPL_Label_NoMapTarget", "No map target selected")
    if mapTarget then
        mapTargetText = string.format(
            "%s   X: %d   Y: %d",
            mapTarget.name or uiText("SPL_Map_Target", "Map target"),
            math.floor(mapTarget.x),
            math.floor(mapTarget.y)
        )
    end
    self:drawText(mapTargetText, PAD + 12, 236, 0.84, 0.82, 0.70, 1, UIFont.Small)

    self:drawText(uiText("SPL_Label_ItemGoals", "Item goals"), PAD, 348, 0.78, 0.75, 0.65, 1, UIFont.Small)
    self:drawText(
        uiText("SPL_Label_Quantity", "Quantity"),
        self.quantityEntry.x,
        self.quantityEntry.y - 22,
        0.78,
        0.75,
        0.65,
        1,
        UIFont.Small
    )
    if #self.goals == 0 then
        self:drawTextCentre(
            uiText("SPL_Label_NoGoals", "No item goals"),
            self.goalList.x + self.goalList.width / 2,
            self.goalList.y + 72,
            0.48,
            0.46,
            0.40,
            1,
            UIFont.Small
        )
    end
    self:drawText(
        uiText("SPL_Hint_AutoTools", "Automatic completion requires a writing tool and an eraser."),
        PAD + 2,
        591,
        0.58,
        0.57,
        0.49,
        1,
        UIFont.Small
    )
end

function SPLTaskEditor:new(playerNum, task, status, saveTarget, onSave)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.min(700, screenWidth - 60)
    local height = math.min(660, screenHeight - 60)
    local o = ISPanel.new(self, (screenWidth - width) / 2, (screenHeight - height) / 2, width, height)
    o.playerNum = playerNum or 0
    o.task = task
    o.status = status or SurvivalPlannerList.STATUS_ACTIVE
    o.saveTarget = saveTarget
    o.onSaveCallback = onSave
    o.windowTitle = task
        and uiText("SPL_Title_EditTask", "Edit task")
        or uiText("SPL_Title_NewTask", "New task")
    o.iconType = task and task.iconType or SurvivalPlannerList.DEFAULT_ICON
    o.goals = SPLGoalUI.copyGoals(task and task.goals or nil)
    o.mapTargets = SurvivalPlannerList.copyMapTargets(task and task.mapTargets or nil)
    o.trackedTargetId = task and task.trackedTargetId or nil
    o.navigationEnabled = task and task.navigationEnabled == true or false
    o.autoComplete = task and task.autoComplete == true or false
    o.hasSubtasks = task and #(task.subtasks or {}) > 0 or false
    o.backgroundColor = {r = 0.115, g = 0.105, b = 0.085, a = 0.98}
    o.borderColor = {r = 0.46, g = 0.41, b = 0.31, a = 1}
    o.moveWithMouse = true
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
