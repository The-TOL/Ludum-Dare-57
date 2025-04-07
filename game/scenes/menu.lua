-- Dependecies
local Button = require("scripts/button")

local Menu = {}

function Menu:new(windowWidth, windowHeight, onStart, onQuit)
    -- Define a start and quit button with onClick functions
    local obj = {
        background = love.graphics.newImage("assets/visual/menu_background.png"),
        title = love.graphics.newImage("assets/visual/menu_title.png"),
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

    -- Draw background
    local scaleX = love.graphics.getWidth() / self.background:getWidth()
    local scaleY = love.graphics.getHeight() / self.background:getHeight()
    love.graphics.draw(self.background, 0, 0, 0, scaleX, scaleY)
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw title
    local titleWidth = self.title:getWidth()
    local titleHeight = self.title:getHeight()
    local titleScale = 1.2 
    love.graphics.draw(
        self.title, 
        (love.graphics.getWidth() - titleWidth * titleScale) / 2,
        love.graphics.getHeight() * 0.03, 
        0,
        titleScale,
        titleScale
    )
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
