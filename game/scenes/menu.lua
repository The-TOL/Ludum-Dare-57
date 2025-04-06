-- Dependecies
local Button = require("scripts/button")

local Menu = {}

function Menu:new(windowWidth, windowHeight, onStart, onQuit)
    -- Define a start and quit button with onClick functions
    local obj = {
        startButton = Button:new((windowWidth - 200) / 2, (windowHeight / 2) - 60, 200, 50, "Start"),
        quitButton = Button:new((windowWidth - 200) / 2, (windowHeight / 2) + 20, 200, 50, "Quit"),
        onStart = onStart,
        onQuit = onQuit
    }

    -- Assign button behaviors
    obj.startButton.onClick = obj.onStart
    obj.quitButton.onClick = obj.onQuit

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Draw menu with buttons
function Menu:draw()
    love.graphics.print("I am the game... ahhh....", (love.graphics.getWidth() / 2) - 50, (love.graphics.getHeight() / 2) - 120)
    self.startButton:draw()
    self.quitButton:draw()
end

-- Check if left mouse click was on one of the buttons 
function Menu:mousepressed(x, y, buttonType)
    if buttonType == 1 then
        self.startButton:handleClick(x, y)
        self.quitButton:handleClick(x, y)
    end
end

return Menu
