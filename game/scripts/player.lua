local Oxygen = require("scripts/oxygen")

local Player = {}

function Player:new(x, y)
    -- Define all variables for the player
    local obj = {
        sprite = love.graphics.newImage("assets/visual/caver.png"),
        x = x,
        y = y,
        speed = 200,
        size = 130,
        velocityY = 0,
        gravity = 500,
        isJumping = false,
        isDead = false,
        facingLeft = false,
        oxygen = Oxygen:new(100, 10) 
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Player:update(dt, windowWidth)
    -- Kill player if oxygen depleted
    if not self.isDead then
        self.oxygen:update(dt)
        if self.oxygen.isDepleted then
            self.isDead = true
        end

        -- Apply gravity
        self.velocityY = self.velocityY + self.gravity * dt
        self.y = self.y + self.velocityY * dt

        -- Window borders
        if self.x < 0 then self.x = 0 end
        if self.x + self.size > windowWidth then self.x = windowWidth - self.size end

        -- Left/Right movement with facing direction
        if love.keyboard.isDown("a") then
            self.x = self.x - self.speed * dt
            self.facingLeft = false
        end
        if love.keyboard.isDown("d") then
            self.x = self.x + self.speed * dt
            self.facingLeft = true
        end
    end
end

-- Draw player to sreen
function Player:draw(cameraY)
    local scaleX = self.size / self.sprite:getWidth()
    if self.facingLeft then scaleX = -scaleX end
    
    love.graphics.draw(
        self.sprite,
        self.x + (self.facingLeft and self.size or 0),
        self.y - cameraY,
        0,
        scaleX,
        self.size / self.sprite:getHeight()
    )
end

return Player
