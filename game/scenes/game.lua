local Button = require("libraries/button")
local DeathScreen = require("scenes/death_screen")

local Game = {}

function Game:new(windowWidth, windowHeight, onMainMenu)
    -- Define the player and background
    local obj = {
        player = { 
            x = 400, 
            y = 100, 
            spawnX = 400,
            spawnY = 100,
            speed = 200, 
            size = 50, 
            velocityY = 0, 
            gravity = 500, 
            isJumping = false, 
            isDead = false 
        },
        -- (Currently a placeholder)
        caveBackground = love.graphics.newImage("assets/visual/cave_background.png"),
        windowWidth = windowWidth,
        windowHeight = windowHeight,
    }

    -- Define deathscreen
    obj.deathScreen = DeathScreen:new(
        windowWidth, 
        windowHeight,
        function() 
            obj:respawnPlayer() 
        end,
        onMainMenu
    )

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Respawning player to initial starting position
function Game:respawnPlayer()
    local player = self.player
    player.x = player.spawnX
    player.y = player.spawnY
    player.velocityY = 0
    player.isJumping = false
    player.isDead = false
end

function Game:update(dt)
    if not self.player.isDead then
        local player = self.player

        -- Apply gravity
        player.velocityY = player.velocityY + player.gravity * dt
        player.y = player.y + player.velocityY * dt

        -- Prevent player from going beyond window borders
        if player.y + player.size > self.windowHeight then
            player.y = self.windowHeight - player.size
            player.velocityY = 0
            player.isJumping = false
        end

        if player.x < 0 then player.x = 0 end
        if player.x + player.size > self.windowWidth then player.x = self.windowWidth - player.size end

        -- Left/Right movement
        if love.keyboard.isDown("a") then
            player.x = player.x - player.speed * dt
        end
        if love.keyboard.isDown("d") then
            player.x = player.x + player.speed * dt
        end
    end
end

-- Click listener death screen
function Game:mousepressed(x, y, button)
    if self.player.isDead then
        self.deathScreen:mousepressed(x, y, button)
    end
end

-- Jump on spacebar press (and die on Y press, this is for debugging)
function Game:keypressed(key)
    local player = self.player
    if key == "y" then
        player.isDead = true
    end
    if key == "space" and not player.isJumping and not player.isDead then
        player.velocityY = -300
        player.isJumping = true
    end
end


function Game:draw()
    -- Draw the player and background
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.caveBackground, 0, 0, 0, self.windowWidth / self.caveBackground:getWidth(), self.windowHeight / self.caveBackground:getHeight())
    love.graphics.rectangle("fill", self.player.x, self.player.y, self.player.size, self.player.size)
    
    -- Draw death screen overlay if dead
    if self.player.isDead then
        self.deathScreen:draw()
    end
end

return Game
