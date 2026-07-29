require "ISUI/ISTextEntryBox"
require "ISUI/ISToolTip"
require "SurvivalPlannerList/SurvivalPlannerList_Themes"

SPLTextEntry = SPLTextEntry or ISTextEntryBox:derive("SPLTextEntry")

function SPLTextEntry:instantiate()
    ISTextEntryBox.instantiate(self)
    self:setHasFrame(false)
    self:applyTheme(self.theme)
end

function SPLTextEntry:applyTheme(theme)
    self.theme = theme or self.theme or SPLThemes.get(self.playerNum or 0)
    if not self.javaObject then
        return
    end

    local text = self.theme.text
    local placeholder = self.theme.mutedText
    self:setTextRGBA(text.r, text.g, text.b, text.a or 1)
    self:setPlaceholderTextRGBA(
        placeholder.r,
        placeholder.g,
        placeholder.b,
        math.min(placeholder.a or 1, 0.72)
    )
end

function SPLTextEntry:setEditable(editable)
    self.splEditable = editable == true
    if self.javaObject then
        self.javaObject:setEditable(self.splEditable)
    end
end

function SPLTextEntry:showTooltip()
    if self:isMouseOver() and self.tooltip then
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
        end
        if not self.tooltipUI:getIsVisible() then
            if string.contains(self.tooltip, "\n") then
                self.tooltipUI.maxLineWidth = 1000
            else
                self.tooltipUI.maxLineWidth = 300
            end
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
            self.tooltipUI:setAlwaysOnTop(true)
        end
        self.tooltipUI.description = self.tooltip
        self.tooltipUI:setX(self:getMouseX() + 23)
        self.tooltipUI:setY(self:getMouseY() + 23)
        return
    end

    if self.tooltipUI and self.tooltipUI:getIsVisible() then
        self.tooltipUI:setVisible(false)
        self.tooltipUI:removeFromUIManager()
    end
end

function SPLTextEntry:prerender()
    local focused = self.javaObject and self.javaObject:isFocused()
    local hovered = self:isMouseOver()
    self.fade:setFadeIn(hovered or focused)
    self.fade:update()

    local theme = self.theme or SPLThemes.get(self.playerNum or 0)
    local background = theme.input
    local border = theme.inputBorder
    local editable = self.splEditable ~= false

    if focused then
        border = theme.accent
    elseif hovered and editable then
        border = theme.accentHover
    end

    local backgroundAlpha = background.a or 1
    local borderAlpha = border.a or 1
    if not editable then
        backgroundAlpha = math.min(backgroundAlpha, 0.58)
        borderAlpha = math.min(borderAlpha, 0.42)
    end

    self:drawRectStatic(
        0,
        0,
        self.width,
        self.height,
        backgroundAlpha,
        background.r,
        background.g,
        background.b
    )
    self:drawRectBorderStatic(
        0,
        0,
        self.width,
        self.height,
        borderAlpha,
        border.r,
        border.g,
        border.b
    )

    if focused then
        self:drawRect(0, 0, 3, self.height, 1, theme.accent.r, theme.accent.g, theme.accent.b)
        self:drawRectBorderStatic(
            2,
            2,
            self.width - 4,
            self.height - 4,
            0.28,
            theme.accent.r,
            theme.accent.g,
            theme.accent.b
        )
    end

    self:showTooltip()
end

function SPLTextEntry:new(title, x, y, width, height, theme)
    local o = ISTextEntryBox.new(self, title, x, y, width, height)
    o.theme = theme or SPLThemes.get(0)
    o.splEditable = true
    o.backgroundColor = SPLThemes.copyColor(o.theme.input)
    o.borderColor = SPLThemes.copyColor(o.theme.inputBorder)
    return o
end

return SPLTextEntry
