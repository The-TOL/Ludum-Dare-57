local Oxygen = require("scripts/oxygen")
local worldGenerator = require("scenes.world_generator")

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
        speed = 350,
        size = 130,
        velocityY = 0,
        gravity = 500,
        isJumping = false,
        isDead = false,
        facingLeft = false,
        oxygen = Oxygen:new(100, 10),
        collisionBox = {
            offsetX = 35,
            offsetY = 20,
            width = 60,
            height = 100
        },
        isInShack = false,
        nearShack = false
    }
    
    obj.frameWidth = obj.spriteSheet:getWidth() / obj.numFrames
    
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Player:getCollisionBox()
    return {
        x = self.x + self.collisionBox.offsetX,
        y = self.y + self.collisionBox.offsetY,
        width = self.collisionBox.width,
        height = self.collisionBox.height
    }
end

function Player:checkCollision(world)
    -- Get current collision box
    local box = self:getCollisionBox()
    
    -- Check collision with world
    return worldGenerator.checkCollision(world, box.x, box.y, box.width, box.height)
end

function Player:update(dt, world, windowWidth)
    if not self.isDead then
        -- Check if player is in shack to refill oxygen
        local playerX = self.x + self.collisionBox.offsetX + self.collisionBox.width/2
        local playerY = self.y + self.collisionBox.offsetY + self.collisionBox.height/2

        -- Check multiple tiles around and below the shack for collision
        local tileRange = 8
        local centerTileX = math.floor(playerX / world.tileSize) + 1
        local centerTileY = math.floor(playerY / world.tileSize) + 1
        
        local nearShack = false
        for checkY = centerTileY - tileRange, centerTileY + tileRange do
            for checkX = centerTileX - tileRange, centerTileX + tileRange do
                if checkY >= 1 and checkY <= world.mapHeight and 
                   checkX >= 1 and checkX <= world.mapWidth then
                    if world.mapData[checkY][checkX] == world.SHACK then
                        nearShack = true
                        break
                    end
                end
            end
            if nearShack then break end
        end

        self.nearShack = nearShack
        self.oxygen.isRefilling = self.isInShack
        
        self.oxygen:update(dt)
        if self.oxygen.isDepleted then
            self.isDead = true
        end

        -- Only process movement when not in shack
        if not self.isInShack then
            -- Store previous positions
            local prevX, prevY = self.x, self.y

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

            -- Check horzontal collision
            if self:checkCollision(world) then
                self.x = prevX
            end

            -- Vertical gravity
            self.velocityY = self.velocityY + self.gravity * dt
            self.y = self.y + self.velocityY * dt

            -- Check vertical collision
            if self:checkCollision(world) then
                self.y = prevY -- Revert Y if collision
                self.velocityY = 0
                self.isJumping = false
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
end

-- Draw player to screen
function Player:draw(cameraY)
    -- Only draw player if not in shack
    if not self.isInShack then
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

    -- Draw prompts when near shack
    if self.nearShack and not self.isInShack then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Press ENTER to enter shack", self.x - 60, self.y - 30 - cameraY)
    elseif self.isInShack then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Press ENTER to exit shack", 10, 70)
    end
end

return Player
