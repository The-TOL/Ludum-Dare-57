-- Dependencies
local Game = require("scenes/game")
local Menu = require("scenes/menu")

-- Game state, will be used to switch between scenes
local state = "menu"
local menuScene = nil
local gameScene = nil

-- Define window size
local windowWidth, windowHeight = love.window.getDesktopDimensions()

function love.load()
    -- Load window
    love.window.setMode(windowWidth, windowHeight, { resizable = false })
    love.window.setTitle("LD57")

    -- Make and define variables for the menu scene
    menuScene = Menu:new(windowWidth, windowHeight, 
        function()
            state = "game"
            gameScene = Game:new(windowWidth, windowHeight, function()
                state = "menu"
            end)
        end, 
        function()
            love.event.quit()
        end
    )
end

-- Click listener for the menu scene
function love.mousepressed(x, y, buttonType)
    if state == "menu" then
        menuScene:mousepressed(x, y, buttonType)
    elseif state == "game" then
        gameScene:mousepressed(x, y, buttonType)
    end
end

-- Update functions for the game scene
function love.update(dt)
    if state == "game" then
        gameScene:update(dt)
    end
end

-- Key press functions for the game scene
function love.keypressed(key)
    if state == "game" then
        gameScene:keypressed(key)
    end
end

-- Draw the menu and game scene to the window
function love.draw()
    if state == "menu" then
        menuScene:draw()
    elseif state == "game" then
        gameScene:draw()
    end
end
