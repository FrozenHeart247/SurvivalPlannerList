require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "SurvivalPlannerList/SurvivalPlannerList_Core"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"
require "SurvivalPlannerList/SurvivalPlannerList_TextEntry"
require "SurvivalPlannerList/SurvivalPlannerList_StyledScrollBar"

SPLItemPicker = ISPanel:derive("SPLItemPicker")
SPLItemPickerList = ISScrollingListBox:derive("SPLItemPickerList")

local PAD = 12
local ROW_HEIGHT = 48
local BUTTON_HEIGHT = 28
local SCROLLBAR_GUTTER = 18

local function uiText(key, fallback)
    local value = getText(key)
    if not value or value == key then
        return fallback
    end
    return value
end

local function styleButton(button, primary)
    local theme = button.target.theme
    if primary then
        SPLThemes.styleButton(
            button,
            theme.accent,
            theme.accentHover,
            theme.panelBorder,
            theme.tabActiveText
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

function SPLItemPickerList:addScrollBars()
    self:removeScrollBars()
    self.vscroll = SPLStyledScrollBar:new(self)
    self.vscroll:initialise()
    self:addChild(self.vscroll)
end

function SPLItemPickerList:new(x, y, width, height)
    return ISScrollingListBox.new(self, x, y, width, height)
end

function SPLItemPicker:initialise()
    ISPanel.initialise(self)
end

function SPLItemPicker:createChildren()
    ISPanel.createChildren(self)

    local titleHeight = getTextManager():getFontHeight(UIFont.Medium) + 14
    self.search = SPLTextEntry:new(
        "",
        PAD,
        titleHeight + PAD,
        self.width - PAD * 2,
        28,
        self.theme
    )
    self.search:initialise()
    self.search:instantiate()
    self.search:setClearButton(true)
    self.search.tooltip = self.catalogMode == "icons"
        and uiText("IGUI_SPL_Tooltip_SearchIcons", "Search plan icons and item icons")
        or uiText("IGUI_SPL_Tooltip_SearchItems", "Search by item name or full type")
    self:addChild(self.search)

    local listY = self.search:getBottom() + 8
    local listHeight = self.height - listY - BUTTON_HEIGHT - PAD * 2
    self.list = SPLItemPickerList:new(PAD, listY, self.width - PAD * 2, listHeight)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HEIGHT
    self.list.theme = self.theme
    self.list.backgroundColor = SPLThemes.copyColor(self.theme.list)
    self.list.borderColor = SPLThemes.copyColor(self.theme.listBorder)
    self.list.selectionColor = SPLThemes.copyColor(self.theme.cardSelected)
    self.list.doDrawItem = SPLItemPicker.drawCatalogItem
    self.list:setOnMouseDoubleClick(self, SPLItemPicker.acceptSelection)
    self:addChild(self.list)

    local buttonY = self.height - BUTTON_HEIGHT - PAD
    self.chooseButton = ISButton:new(
        self.width - PAD - 130,
        buttonY,
        130,
        BUTTON_HEIGHT,
        uiText("IGUI_SPL_Button_Choose", "Choose"),
        self,
        SPLItemPicker.onChoose
    )
    self.chooseButton:initialise()
    self.chooseButton:instantiate()
    styleButton(self.chooseButton, true)
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
    styleButton(self.cancelButton, false)
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
    local catalog = self.catalogMode == "icons"
        and SurvivalPlannerList.getIconCatalog()
        or SurvivalPlannerList.getItemCatalog()
    for _, entry in ipairs(catalog) do
        local name = string.lower(entry.name or "")
        local fullType = string.lower(entry.fullType or "")
        local category = entry.isCustomIcon
            and string.lower(uiText("IGUI_SPL_Category_PlannerIcon", "Planner icon"))
            or ""
        if query == ""
            or string.find(name, query, 1, true)
            or string.find(fullType, query, 1, true)
            or string.find(category, query, 1, true) then
            self.list:addItem(entry.name, entry)
            if entry.fullType == (selectedType or self.initialType) then
                selectedIndex = #self.list.items
            end
        end
    end

    if selectedIndex then
        self.list.selected = selectedIndex
        if force and self.catalogMode == "icons" then
            self.list:setYScroll(0)
        else
            self.list:ensureVisible(selectedIndex)
        end
    elseif #self.list.items > 0 then
        self.list.selected = 1
    else
        self.list.selected = -1
    end
    SPLThemes.setButtonEnabled(self.chooseButton, #self.list.items > 0)
end

function SPLItemPicker:update()
    ISPanel.update(self)
    self:refreshCatalog(false)
end

function SPLItemPicker:drawCatalogItem(y, row, alt)
    local theme = self.theme
    local height = row.height or ROW_HEIGHT
    local contentWidth = self.width - SCROLLBAR_GUTTER
    if self.selected == row.index then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.82, theme.cardSelected.r, theme.cardSelected.g, theme.cardSelected.b)
    elseif self.mouseoverselected == row.index and self:isMouseOver() then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.68, theme.cardHover.r, theme.cardHover.g, theme.cardHover.b)
    elseif alt then
        self:drawRect(1, y + 1, contentWidth - 2, height - 2, 0.38, theme.card.r, theme.card.g, theme.card.b)
    end

    local entry = row.item
    if entry.isCustomIcon then
        self:drawRect(1, y + 1, 4, height - 2, 1, theme.accent.r, theme.accent.g, theme.accent.b)
    end
    if entry.texture then
        self:drawTextureScaledAspect(entry.texture, 8, y + 5, 38, 38, 1, 1, 1, 1)
    end
    local textWidth = contentWidth - 62
    local itemName = getTextManager():WrapText(UIFont.Small, entry.name or entry.fullType, textWidth, 1, "...")
    local details = entry.isCustomIcon
        and uiText("IGUI_SPL_Category_PlannerIcon", "Planner icon")
        or (entry.fullType or "")
    local fullType = getTextManager():WrapText(UIFont.Small, details, textWidth, 1, "...")
    self:drawText(itemName, 54, y + 7, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Small)
    self:drawText(fullType, 54, y + 27, theme.mutedText.r, theme.mutedText.g, theme.mutedText.b, 1, UIFont.Small)
    self:drawRectBorder(0, y, contentWidth, height, 0.55, theme.cardBorder.r, theme.cardBorder.g, theme.cardBorder.b)
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
    local theme = self.theme
    self:drawRect(0, 0, self.width, self.height, theme.panel.a or 0.97, theme.panel.r, theme.panel.g, theme.panel.b)
    self:drawRect(0, 0, self.width, 42, 1, theme.header.r, theme.header.g, theme.header.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, theme.panelBorder.r, theme.panelBorder.g, theme.panelBorder.b)
    self:drawTextCentre(self.titleText, self.width / 2, 10, theme.text.r, theme.text.g, theme.text.b, 1, UIFont.Medium)
end

function SPLItemPicker:new(playerNum, titleText, initialType, pickTarget, onPick, pickPurpose, catalogMode)
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local width = math.min(640, screenWidth - 80)
    local height = math.min(620, screenHeight - 80)
    local x = (screenWidth - width) / 2
    local y = (screenHeight - height) / 2
    local o = ISPanel.new(self, x, y, width, height)
    o.playerNum = playerNum or 0
    o.theme = SPLThemes.get(o.playerNum)
    o.titleText = titleText or uiText("IGUI_SPL_Title_ItemPicker", "Choose an item")
    o.initialType = initialType
    o.pickTarget = pickTarget
    o.onPick = onPick
    o.pickPurpose = pickPurpose
    o.catalogMode = catalogMode or "items"
    o.backgroundColor = SPLThemes.copyColor(o.theme.panel)
    o.borderColor = SPLThemes.copyColor(o.theme.panelBorder)
    o.moveWithMouse = true
    return o
end

function SPLItemPicker.open(playerNum, titleText, initialType, pickTarget, onPick, pickPurpose, catalogMode)
    local picker = SPLItemPicker:new(
        playerNum,
        titleText,
        initialType,
        pickTarget,
        onPick,
        pickPurpose,
        catalogMode
    )
    picker:initialise()
    picker:addToUIManager()
    picker:bringToTop()
    return picker
end

return SPLItemPicker
