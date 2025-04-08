local Button = require("scripts/button")

local DeathScreen = {}

function DeathScreen:new(windowWidth, windowHeight, onRetry, onMainMenu)
    -- Define retry and to menu buttons
    local obj = {
        windowWidth = windowWidth,
        windowHeight = windowHeight,
        retryButton = Button:new((windowWidth - 200) / 2, (windowHeight / 2) + 20, 200, 50, "Retry"),
        menuButton = Button:new((windowWidth - 200) / 2, (windowHeight / 2) + 100, 200, 50, "Main Menu")
    }
    
    obj.retryButton.onClick = onRetry
    obj.menuButton.onClick = onMainMenu

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Click listener
function DeathScreen:mousepressed(x, y, button)
    self.retryButton:handleClick(x, y)
    self.menuButton:handleClick(x, y)
end

function DeathScreen:draw()
    -- Darken background and draw the text and buttons
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, self.windowWidth, self.windowHeight)
    
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.printf("You are dead", 0, self.windowHeight / 2 - 100, self.windowWidth, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
    self.retryButton:draw()
    self.menuButton:draw()
end

return DeathScreen