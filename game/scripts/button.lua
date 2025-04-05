local Button = {}

-- Define all variables of object
function Button:new(x, y, width, height, text)
    local obj = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        onClick = nil
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Define form of button
function Button:draw()
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.printf(self.text, self.x, self.y + self.height / 4, self.width, "center")
end

-- Check if button is clicked
function Button:isClicked(mx, my)
    return mx >= self.x and mx <= self.x + self.width and my >= self.y and my <= self.y + self.height
end

-- Define click event
function Button:handleClick(mx, my)
    if self:isClicked(mx, my) and self.onClick then
        self.onClick()
    end
end

return Button
