-- Sizes for the player and window
local player = { x = 400, y = 300, speed = 200, size = 50 }
local windowWidth, windowHeight = love.window.getDesktopDimensions()

-- Example on how project can be split into multiple files
local Button = require("button")
local button = Button:new(350, 500, 100, 50, "Click Me")
-- Define sound asset
local clickSound  = love.audio.newSource("assets/sounds/click.mp3", "static")

-- Make the window fixed size
function love.load()
    love.window.setMode(windowWidth, windowHeight, { fullscreen = true, resizable = false }) 
    love.window.setTitle("Love 2D test") 
end

-- Moving with WASD
function love.update(dt)
    if love.keyboard.isDown("w") then
        player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("a") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("s") then
        player.y = player.y + player.speed * dt
    end
    if love.keyboard.isDown("d") then
        player.x = player.x + player.speed * dt
    end
end

-- Listener to check for left mouse clicks
function love.mousepressed(x, y, buttonType)
    if buttonType == 1 then 
        button:handleClick(x, y)
    end
end

-- Assign button click behavior
button.onClick = function()
    local soundInstance = love.audio.newSource("assets/sounds/click.mp3", "static")
    love.audio.play(soundInstance)
end

-- Draw our components to the window
function love.draw()
    love.graphics.print("Hello, World!", windowWidth / 2 - 50, windowHeight / 2 - 50)
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size)
    button:draw()
end

-- Run with love {path} (or love . if you're already in the directory)
