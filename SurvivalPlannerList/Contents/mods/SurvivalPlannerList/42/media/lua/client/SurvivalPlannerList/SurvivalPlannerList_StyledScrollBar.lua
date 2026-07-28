require "ISUI/ISScrollBar"

SPLStyledScrollBar = SPLStyledScrollBar or ISScrollBar:derive("SPLStyledScrollBar")

local SCROLLBAR_WIDTH = 12

function SPLStyledScrollBar:instantiate()
    self.javaObject = UIElement.new(self)
    self.anchorLeft = false
    self.anchorRight = true
    self.anchorBottom = true
    self.x = self.parent.width - SCROLLBAR_WIDTH - 2
    self.y = 0
    self.width = SCROLLBAR_WIDTH
    self.height = self.parent.height
    self.javaObject:setX(self.x)
    self.javaObject:setY(self.y)
    self.javaObject:setHeight(self.height)
    self.javaObject:setWidth(self.width)
    self.javaObject:setAnchorLeft(self.anchorLeft)
    self.javaObject:setAnchorRight(self.anchorRight)
    self.javaObject:setAnchorTop(self.anchorTop)
    self.javaObject:setAnchorBottom(self.anchorBottom)
    self.javaObject:setScrollWithParent(false)
end

function SPLStyledScrollBar:hitTest(x, y)
    if not self:isPointOver(self:getAbsoluteX() + x, self:getAbsoluteY() + y) then
        return nil
    end
    if self:isPointOverThumb(x, y) then
        return "thumb"
    end
    if not self.bary or self.barheight == 0 then
        return nil
    end
    return y < self.bary and "trackUp" or "trackDown"
end

function SPLStyledScrollBar:onMouseMove(dx, dy)
    if not self.scrolling then
        return
    end

    local trackPadding = 6
    local trackHeight = self.height - trackPadding * 2
    local travel = trackHeight - (self.barheight or 0)
    if travel <= 0 then
        return
    end

    self.pos = math.max(0, math.min(1, self.pos + dy / travel))
    local scrollRange = self.parent:getScrollHeight() - self.parent:getScrollAreaHeight()
    self.parent:setYScroll(-(self.pos * math.max(0, scrollRange)))
end

function SPLStyledScrollBar:render()
    local scrollHeight = self.parent:getScrollHeight()
    local areaHeight = self.parent:getScrollAreaHeight()
    if scrollHeight <= areaHeight then
        self.barx = 0
        self.bary = 0
        self.barwidth = 0
        self.barheight = 0
        return
    end

    local trackPadding = 6
    local trackX = 3
    local trackWidth = self.width - 6
    local trackHeight = self.height - trackPadding * 2
    local thumbHeight = math.max(28, math.floor(trackHeight * areaHeight / scrollHeight))
    thumbHeight = math.min(trackHeight, thumbHeight)
    local travel = trackHeight - thumbHeight
    local thumbY = trackPadding + math.floor(travel * self.pos)

    self.barx = trackX
    self.bary = thumbY
    self.barwidth = trackWidth
    self.barheight = thumbHeight

    local hovered = self.scrolling or (
        self:isMouseOver()
        and self:isPointOverThumb(self:getMouseX(), self:getMouseY())
    )

    self:drawRect(1, 0, self.width - 2, self.height, 0.90, 0.075, 0.070, 0.055)
    self:drawRect(trackX + 1, trackPadding, trackWidth - 2, trackHeight, 0.95, 0.13, 0.12, 0.09)

    local r, g, b = 0.42, 0.39, 0.29
    if hovered then
        r, g, b = 0.61, 0.57, 0.37
    end
    if self.scrolling then
        r, g, b = 0.72, 0.67, 0.42
    end
    self:drawRect(trackX, thumbY, trackWidth, thumbHeight, 1, r, g, b)
    self:drawRectBorder(trackX, thumbY, trackWidth, thumbHeight, 1, 0.73, 0.67, 0.43)
    self:drawRectBorder(1, 0, self.width - 2, self.height, 0.92, 0.29, 0.27, 0.21)
end

function SPLStyledScrollBar:new(parent)
    local o = ISScrollBar.new(self, parent, true)
    o.background = false
    return o
end

return SPLStyledScrollBar
