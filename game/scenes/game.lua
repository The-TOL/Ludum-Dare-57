local Game = {}

function Game:new(windowWidth, windowHeight)
    -- Define the player and background
    local obj = {
        player = { x = 400, y = 100, speed = 200, size = 50, velocityY = 0, gravity = 500, isJumping = false },
        -- (Currently a placeholder)
        caveBackground = love.graphics.newImage("assets/visual/cave_background.png"),
        windowWidth = windowWidth,
        windowHeight = windowHeight
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Game:update(dt)
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

-- Jump on spacebar press
function Game:keypressed(key)
    local player = self.player
    if key == "space" and not player.isJumping then
        player.velocityY = -300
        player.isJumping = true
    end
end

-- Draw the player and background
function Game:draw()
    love.graphics.draw(self.caveBackground, 0, 0, 0, self.windowWidth / self.caveBackground:getWidth(), self.windowHeight / self.caveBackground:getHeight())
    love.graphics.rectangle("fill", self.player.x, self.player.y, self.player.size, self.player.size)
end

return Game
