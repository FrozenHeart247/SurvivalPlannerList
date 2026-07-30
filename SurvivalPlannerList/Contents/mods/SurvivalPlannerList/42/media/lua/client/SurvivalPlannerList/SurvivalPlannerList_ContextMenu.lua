require "ISUI/ISInventoryPane"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_MainPanel"
require "SurvivalPlannerList/SurvivalPlannerList_QuickButton"
require "SurvivalPlannerList/SurvivalPlannerList_NavigationManager"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"
require "SurvivalPlannerList/SurvivalPlannerList_TextEntry"

SPLRenamePlannerDialog = SPLRenamePlannerDialog or ISPanel:derive("SPLRenamePlannerDialog")

local RENAME_MAX_LENGTH = 28
local DIALOG_WIDTH = 440
local DIALOG_HEIGHT = 174
local DIALOG_PAD = 14
local BUTTON_HEIGHT = 30

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function openPlanner(planner, playerNum)
    if not planner or not SurvivalPlannerList.isPlanner(planner) then
        return
    end
    SurvivalPlannerList.openPlannerUI(playerNum, planner)
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

function SPLRenamePlannerDialog:initialise()
    ISPanel.initialise(self)
end

function SPLRenamePlannerDialog:createChildren()
    ISPanel.createChildren(self)

    self.nameEntry = SPLTextEntry:new(
        self.planner:getDisplayName(),
        DIALOG_PAD,
        67,
        self.width - DIALOG_PAD * 2,
        30,
        self.theme
    )
    self.nameEntry.playerNum = self.playerNum
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self.nameEntry:setMaxTextLength(RENAME_MAX_LENGTH)
    local dialog = self
    self.nameEntry.onTextChange = function()
        dialog:updateSaveButton()
    end
    self.nameEntry.onCommandEntered = function()
        dialog:onSave()
    end
    self:addChild(self.nameEntry)

    local buttonY = self.height - DIALOG_PAD - BUTTON_HEIGHT
    local buttonWidth = math.floor((self.width - DIALOG_PAD * 3) / 2)
    self.cancelButton = ISButton:new(
        DIALOG_PAD,
        buttonY,
        buttonWidth,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_Cancel", "Cancel"),
        self,
        SPLRenamePlannerDialog.close
    )
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    self:addChild(self.cancelButton)

    self.saveButton = ISButton:new(
        DIALOG_PAD * 2 + buttonWidth,
        buttonY,
        self.width - DIALOG_PAD * 3 - buttonWidth,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_Save", "Save"),
        self,
        SPLRenamePlannerDialog.onSave
    )
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self:addChild(self.saveButton)

    SPLThemes.styleButton(
        self.cancelButton,
        self.theme.button,
        self.theme.buttonHover,
        self.theme.buttonBorder,
        self.theme.buttonText
    )
    SPLThemes.styleButton(
        self.saveButton,
        self.theme.accent,
        self.theme.accentHover,
        self.theme.panelBorder,
        self.theme.tabActiveText
    )
    self:updateSaveButton()
end

function SPLRenamePlannerDialog:updateSaveButton()
    if not self.saveButton or not self.nameEntry then
        return
    end
    SPLThemes.setButtonEnabled(
        self.saveButton,
        SurvivalPlannerList.trim(self.nameEntry:getText()) ~= ""
    )
end

function SPLRenamePlannerDialog:onSave()
    local name = SurvivalPlannerList.trim(self.nameEntry:getText())
    if name == "" or not SurvivalPlannerList.isPlanner(self.planner) then
        return
    end

    self.planner:setName(name)
    self.planner:setCustomName(true)
    self:close()
end

function SPLRenamePlannerDialog:prerender()
    ISPanel.prerender(self)
    local theme = self.theme
    self:drawRect(1, 1, self.width - 2, 42, 1, theme.header.r, theme.header.g, theme.header.b)
    self:drawRect(
        1,
        42,
        self.width - 2,
        1,
        1,
        theme.headerBorder.r,
        theme.headerBorder.g,
        theme.headerBorder.b
    )
    self:drawTextCentre(
        uiText("IGUI_SPL_Title_RenamePlanner", "Rename planner"),
        self.width / 2,
        12,
        theme.text.r,
        theme.text.g,
        theme.text.b,
        1,
        UIFont.Medium
    )
    self:drawText(
        uiText("IGUI_SPL_Label_PlannerName", "Planner name"),
        DIALOG_PAD,
        49,
        theme.mutedText.r,
        theme.mutedText.g,
        theme.mutedText.b,
        1,
        UIFont.Small
    )
end

function SPLRenamePlannerDialog:close()
    if self.nameEntry and self.nameEntry.javaObject then
        self.nameEntry:unfocus()
    end
    if SPLRenamePlannerDialog.instance == self then
        SPLRenamePlannerDialog.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

function SPLRenamePlannerDialog:new(playerNum, planner)
    local left, top, screenWidth, screenHeight = playerScreenBounds(playerNum)
    local width = math.min(DIALOG_WIDTH, screenWidth - 40)
    local height = math.min(DIALOG_HEIGHT, screenHeight - 40)
    local x = left + math.floor((screenWidth - width) / 2)
    local y = top + math.floor((screenHeight - height) / 2)
    local o = ISPanel.new(self, x, y, width, height)
    o.playerNum = playerNum or 0
    o.planner = planner
    o.theme = SPLThemes.get(o.playerNum)
    o.background = true
    o.moveWithMouse = true
    o.backgroundColor = SPLThemes.copyColor(o.theme.panel)
    o.borderColor = SPLThemes.copyColor(o.theme.panelBorder)
    return o
end

function SPLRenamePlannerDialog.open(planner, playerNum)
    if not SurvivalPlannerList.isPlanner(planner) then
        return
    end
    if SPLRenamePlannerDialog.instance then
        SPLRenamePlannerDialog.instance:close()
    end

    local dialog = SPLRenamePlannerDialog:new(playerNum, planner)
    dialog:initialise()
    dialog:addToUIManager()
    dialog:bringToTop()
    dialog.nameEntry:focus()
    dialog.nameEntry:selectAll()
    SPLRenamePlannerDialog.instance = dialog
end

local function addPlannerContextOption(playerNum, context, items)
    local actualItems = ISInventoryPane.getActualItems(items)
    for _, item in ipairs(actualItems) do
        if SurvivalPlannerList.isPlanner(item) then
            local option = context:addOption(
                uiText("ContextMenu_SurvivalPlannerList_Open", "Open Survival Planner"),
                item,
                openPlanner,
                playerNum
            )
            option.iconTexture = item:getTexture()

            local renameOption = context:addOption(
                uiText("ContextMenu_SurvivalPlannerList_Rename", "Rename planner"),
                item,
                SPLRenamePlannerDialog.open,
                playerNum
            )
            renameOption.iconTexture = item:getTexture()
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(addPlannerContextOption)

return SurvivalPlannerList
