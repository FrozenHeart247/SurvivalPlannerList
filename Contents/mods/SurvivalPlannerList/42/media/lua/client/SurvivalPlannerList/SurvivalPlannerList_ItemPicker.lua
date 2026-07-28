require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"

SPLItemPicker = ISPanel:derive("SPLItemPicker")

local PAD = 12
local ROW_HEIGHT = 48
local BUTTON_HEIGHT = 28

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

function SPLItemPicker:initialise()
    ISPanel.initialise(self)
end

function SPLItemPicker:createChildren()
    ISPanel.createChildren(self)

    local titleHeight = getTextManager():getFontHeight(UIFont.Medium) + 14
    self.search = ISTextEntryBox:new("", PAD, titleHeight + PAD, self.width - PAD * 2, 28)
    self.search:initialise()
    self.search:instantiate()
    self.search:setClearButton(true)
    self.search.tooltip = uiText("SPL_Tooltip_SearchItems", "Search by item name or full type")
    self:addChild(self.search)

    local listY = self.search:getBottom() + 8
    local listHeight = self.height - listY - BUTTON_HEIGHT - PAD * 2
    self.list = ISScrollingListBox:new(PAD, listY, self.width - PAD * 2, listHeight)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HEIGHT
    self.list.backgroundColor = {r = 0.09, g = 0.085, b = 0.07, a = 0.96}
    self.list.borderColor = {r = 0.38, g = 0.34, b = 0.27, a = 1}
    self.list.selectionColor = {r = 0.28, g = 0.34, b = 0.20, a = 0.85}
    self.list.doDrawItem = SPLItemPicker.drawCatalogItem
    self.list:setOnMouseDoubleClick(self, SPLItemPicker.acceptSelection)
    self:addChild(self.list)

    local buttonY = self.height - BUTTON_HEIGHT - PAD
    self.chooseButton = ISButton:new(
        self.width - PAD - 130,
        buttonY,
        130,
        BUTTON_HEIGHT,
        uiText("SPL_Button_Choose", "Choose"),
        self,
        SPLItemPicker.onChoose
    )
    self.chooseButton:initialise()
    self.chooseButton:instantiate()
    self.chooseButton:enableAcceptColor()
    self:addChild(self.chooseButton)

    self.cancelButton = ISButton:new(
        self.chooseButton.x - 110 - 8,
        buttonY,
        110,
        BUTTON_HEIGHT,
        uiText("UI_Cancel", "Cancel"),
        self,
        SPLItemPicker.onCancel
    )
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    self.cancelButton:enableCancelColor()
    self:addChild(self.cancelButton)

    self:refreshCatalog(true)
end

function SPLItemPicker:refreshCatalog(force)
    local query = string.lower(SurvivalPlannerList.trim(self.search and self.search:getText() or ""))
    if not force and query == self.lastQuery then
        return
    end
    self.lastQuery = query

    local selectedType = nil
    if self.list.items[self.list.selected] then
        selectedType = self.list.items[self.list.selected].item.fullType
    end

    self.list:clear()
    local selectedIndex = nil
    for _, entry in ipairs(SurvivalPlannerList.getItemCatalog()) do
        local name = string.lower(entry.name or "")
        local fullType = string.lower(entry.fullType or "")
        if query == "" or string.find(name, query, 1, true) or string.find(fullType, query, 1, true) then
            self.list:addItem(entry.name, entry)
            if entry.fullType == (selectedType or self.initialType) then
                selectedIndex = #self.list.items
            end
        end
    end

    if selectedIndex then
        self.list.selected = selectedIndex
        self.list:ensureVisible(selectedIndex)
    elseif #self.list.items > 0 then
        self.list.selected = 1
    else
        self.list.selected = -1
    end
    self.chooseButton:setEnable(#self.list.items > 0)
end

function SPLItemPicker:update()
    ISPanel.update(self)
    self:refreshCatalog(false)
end

function SPLItemPicker:drawCatalogItem(y, row, alt)
    local height = row.height or ROW_HEIGHT
    if self.selected == row.index then
        self:drawRect(1, y + 1, self.width - 2, height - 2, 0.82, 0.24, 0.31, 0.17)
    elseif self.mouseoverselected == row.index and self:isMouseOver() then
        self:drawRect(1, y + 1, self.width - 2, height - 2, 0.42, 0.22, 0.20, 0.14)
    elseif alt then
        self:drawRect(1, y + 1, self.width - 2, height - 2, 0.32, 0.13, 0.12, 0.10)
    end

    local entry = row.item
    if entry.texture then
        self:drawTextureScaledAspect(entry.texture, 8, y + 5, 38, 38, 1, 1, 1, 1)
    end
    self:drawText(entry.name or entry.fullType, 54, y + 7, 0.93, 0.90, 0.78, 1, UIFont.Small)
    self:drawText(entry.fullType or "", 54, y + 27, 0.57, 0.55, 0.48, 1, UIFont.Small)
    self:drawRectBorder(0, y, self.width, height, 0.55, 0.35, 0.32, 0.27)
    return y + height
end

function SPLItemPicker:getSelectedEntry()
    local row = self.list.items[self.list.selected]
    return row and row.item or nil
end

function SPLItemPicker:acceptSelection(entry)
    entry = entry or self:getSelectedEntry()
    if not entry then
        return
    end
    getSoundManager():playUISound("UIActivateButton")
    local onPick = self.onPick
    local pickTarget = self.pickTarget
    local pickPurpose = self.pickPurpose
    self:close()
    if onPick then
        onPick(pickTarget, entry, pickPurpose)
    end
end

function SPLItemPicker:onChoose()
    self:acceptSelection()
end

function SPLItemPicker:onCancel()
    self:close()
end

function SPLItemPicker:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

function SPLItemPicker:prerender()
    self:drawRect(0, 0, self.width, self.height, 0.97, 0.115, 0.105, 0.085)
    self:drawRect(0, 0, self.width, 42, 1, 0.22, 0.20, 0.15)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.46, 0.41, 0.31)
    self:drawTextCentre(self.titleText, self.width / 2, 10, 0.93, 0.90, 0.78, 1, UIFont.Medium)
end

function SPLItemPicker:new(playerNum, titleText, initialType, pickTarget, onPick, pickPurpose)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.min(640, screenWidth - 80)
    local height = math.min(620, screenHeight - 80)
    local x = (screenWidth - width) / 2
    local y = (screenHeight - height) / 2
    local o = ISPanel.new(self, x, y, width, height)
    o.playerNum = playerNum or 0
    o.titleText = titleText or uiText("SPL_Title_ItemPicker", "Choose an item")
    o.initialType = initialType
    o.pickTarget = pickTarget
    o.onPick = onPick
    o.pickPurpose = pickPurpose
    o.backgroundColor = {r = 0.115, g = 0.105, b = 0.085, a = 0.97}
    o.borderColor = {r = 0.46, g = 0.41, b = 0.31, a = 1}
    o.moveWithMouse = true
    return o
end

function SPLItemPicker.open(playerNum, titleText, initialType, pickTarget, onPick, pickPurpose)
    local picker = SPLItemPicker:new(playerNum, titleText, initialType, pickTarget, onPick, pickPurpose)
    picker:initialise()
    picker:addToUIManager()
    picker:bringToTop()
    return picker
end

return SPLItemPicker
