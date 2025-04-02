-- Sizes for the player and window
local player = { x = 400, y = 300, speed = 200, size = 50 }
local windowWidth, windowHeight = 800, 600

-- Make the window resizable 
function love.load()
    love.window.setMode(windowWidth, windowHeight, { resizable = true })
    love.window.setTitle("Love 2D test") 
end

-- Prevent the positions of assets changing when the screen size changes
function love.resize(w, h)
    local scaleX = w / windowWidth
    local scaleY = h / windowHeight
    player.x = player.x * scaleX
    player.y = player.y * scaleY
    windowWidth, windowHeight = w, h
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

-- Draw hello world and the player to the window
function love.draw()
    love.graphics.print("Hello, World!", windowWidth / 2 - 50, windowHeight / 2 - 50)
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size)
end

-- Run with love {path} (or love . if you're already in the directory)
