require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"
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

local function styleEntry(entry, theme)
    entry.backgroundColor = SPLThemes.copyColor(theme.input)
    entry.borderColor = SPLThemes.copyColor(theme.inputBorder)
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
    styleEntry(self.titleEntry, self.theme)
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
    self.goalList.theme = self.theme
    self.goalList.backgroundColor = SPLThemes.copyColor(self.theme.list)
    self.goalList.borderColor = SPLThemes.copyColor(self.theme.listBorder)
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
    styleEntry(self.quantityEntry, self.theme)
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
    SPLThemes.setButtonEnabled(self.applyQuantityButton, goal ~= nil)
    SPLThemes.setButtonEnabled(self.removeGoalButton, goal ~= nil)
end

function SPLTaskEditor:onChooseIcon()
    SPLItemPicker.open(
        self.playerNum,
        uiText("SPL_Title_ChooseIcon", "Choose task icon"),
        self.iconType,
        self,
        SPLTaskEditor.onIconPicked,
        "icon",
        "icons"
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
    SPLThemes.setButtonEnabled(self.saveButton, hasTitle)
    SPLThemes.setButtonEnabled(self.autoButton, hasCondition)
    local hasMapTarget = self:getMapTarget() ~= nil
    local canNavigate = hasMapTarget and self.status ~= SurvivalPlannerList.STATUS_DONE
    SPLThemes.setButtonEnabled(self.navigationButton, canNavigate)
    SPLThemes.setButtonEnabled(self.clearMapButton, hasMapTarget)
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
    local theme = self.theme
    self:drawRect(0, 0, self.width, self.height, theme.panel.a or 0.98, theme.panel.r, theme.panel.g, theme.panel.b)
    self:drawRect(0, 0, self.width, HEADER_HEIGHT, 1, theme.header.r, theme.header.g, theme.header.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, theme.panelBorder.r, theme.panelBorder.g, theme.panelBorder.b)
    self:drawTextCentre(self.windowTitle, self.width / 2, 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)

    self:drawText(uiText("SPL_Label_TaskTitle", "Task title"), PAD, 47, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawText(uiText("SPL_Label_Icon", "Icon"), PAD, 112, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawRect(PAD, 137, PREVIEW_SIZE, PREVIEW_SIZE, 0.96, theme.card.r, theme.card.g, theme.card.b)
    self:drawRectBorder(PAD, 137, PREVIEW_SIZE, PREVIEW_SIZE, 1, theme.cardBorder.r, theme.cardBorder.g, theme.cardBorder.b)
    local icon = SurvivalPlannerList.getItemTexture(self.iconType)
    if icon then
        self:drawTextureScaledAspect(icon, PAD + 6, 143, PREVIEW_SIZE - 12, PREVIEW_SIZE - 12, 1, 1, 1, 1)
    end

    self:drawText(uiText("SPL_Label_MapTarget", "Map target"), PAD, 203, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawRect(PAD, 227, self.width - PAD * 2, 108, 0.80, theme.card.r, theme.card.g, theme.card.b)
    self:drawRectBorder(PAD, 227, self.width - PAD * 2, 108, 0.75, theme.cardBorder.r, theme.cardBorder.g, theme.cardBorder.b)
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
    self:drawText(mapTargetText, PAD + 12, 236, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)

    self:drawText(uiText("SPL_Label_ItemGoals", "Item goals"), PAD, 348, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawText(
        uiText("SPL_Label_Quantity", "Quantity"),
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
            uiText("SPL_Label_NoGoals", "No item goals"),
            self.goalList.x + self.goalList.width / 2,
            self.goalList.y + 72,
            theme.subtleText.r,
            theme.subtleText.g,
            theme.subtleText.b,
            1,
            UIFont.Small
        )
    end
    self:drawText(
        uiText("SPL_Hint_AutoTools", "Automatic completion requires a writing tool and an eraser."),
        PAD + 2,
        591,
        theme.subtleText.r,
        theme.subtleText.g,
        theme.subtleText.b,
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
    o.theme = SPLThemes.get(o.playerNum)
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
    o.backgroundColor = SPLThemes.copyColor(o.theme.panel)
    o.borderColor = SPLThemes.copyColor(o.theme.panelBorder)
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
