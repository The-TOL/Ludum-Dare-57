local Oxygen = require("scripts/oxygen")

local Player = {}

function Player:new(x, y)
    -- Define all variables for the player
    local obj = {
        spriteSheet = love.graphics.newImage("assets/visual/cavermove.png"),
        frameWidth = nil, 
        currentFrame = 1,
        animationTimer = 0,
        frameDuration = 0.13, 
        numFrames = 8,
        isMoving = false,
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
    
    obj.frameWidth = obj.spriteSheet:getWidth() / obj.numFrames
    
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

        -- Track if player is moving for animation
        self.isMoving = false

        -- Left/Right movement with facing direction
        if love.keyboard.isDown("a") then
            self.x = self.x - self.speed * dt
            self.facingLeft = true
            self.isMoving = true
        end
        if love.keyboard.isDown("d") then
            self.x = self.x + self.speed * dt
            self.facingLeft = false
            self.isMoving = true
        end

        -- Update animation
        if self.isMoving then
            self.animationTimer = self.animationTimer + dt
            if self.animationTimer >= self.frameDuration then
                self.animationTimer = self.animationTimer - self.frameDuration
                self.currentFrame = self.currentFrame % self.numFrames + 1
            end
        else
            self.currentFrame = 3
        end
    end
end

-- Draw player to screen
function Player:draw(cameraY)
    local scaleX = self.size / self.frameWidth
    if self.facingLeft then scaleX = -scaleX end
    
    -- Calculate the quad for the current frame
    local quad = love.graphics.newQuad(
        (self.currentFrame - 1) * self.frameWidth,
        0,
        self.frameWidth,
        self.spriteSheet:getHeight(),
        self.spriteSheet:getWidth(),
        self.spriteSheet:getHeight()
    )
    
    love.graphics.draw(
        self.spriteSheet,
        quad,
        self.x + (self.facingLeft and self.size or 0),
        self.y - cameraY,
        0,
        scaleX,
        self.size / self.spriteSheet:getHeight()
    )
end

return Player
