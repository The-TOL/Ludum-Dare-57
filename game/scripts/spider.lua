local Spider = {}

function Spider:new(x, y, world)
    local obj = {
        x = x,
        y = y,
        size = 70,
        speed = 120,
        direction = math.random(0, 1) == 0 and -1 or 1,
        jumpTimer = 0,
        jumpInterval = math.random(5, 10), 
        restInterval = math.random(1, 2),
        isResting = false,
        world = world,
        sprite = love.graphics.newImage("assets/visual/stalker.png"),
        frameWidth = nil,
        currentFrame = 1,
        animationTimer = 0,
        frameDuration = 0.15,
        numFrames = 4,
        velocityX = 0,
        velocityY = 0,
        gravity = 700,
        jumpForce = 200, 
        farJumpDistance = 700, 
        isGrounded = false,
        collisionBox = {
            offsetX = 20,
            offsetY = 15,
            width = 30,
            height = 40
        },
        detectionRange = 400,
        isTrackingPlayer = false,
        lungeSpeed = 400,
        maxLungeHeight = 600, 
        minLungeHeight = 500, 
        wasGroundedLastFrame = false
    }
    
    pcall(function()
        obj.frameWidth = obj.sprite:getWidth() / obj.numFrames
    end)
    
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Set up collision
function Spider:getCollisionBox()
    return {
        x = self.x + self.collisionBox.offsetX,
        y = self.y + self.collisionBox.offsetY,
        width = self.collisionBox.width,
        height = self.collisionBox.height
    }
end

function Spider:checkCollision()
    -- Check collisions
    local box = self:getCollisionBox()
    
    if box.x < 0 or box.x + box.width > self.world.width then
        return true
    end
    
    for y = math.floor(box.y / self.world.tileSize), math.ceil((box.y + box.height) / self.world.tileSize) do
        for x = math.floor(box.x / self.world.tileSize), math.ceil((box.x + box.width) / self.world.tileSize) do
            if y >= 1 and y <= self.world.mapHeight and x >= 1 and x <= self.world.mapWidth then
                if self.world.mapData[y][x] == self.world.WALL then
                    return true
                end
            else
                return true
            end
        end
    end
    
    return false
end

function Spider:isGroundBelow()
    local box = self:getCollisionBox()
    local groundY = box.y + box.height + 2
    
    for x = math.floor(box.x / self.world.tileSize), math.ceil((box.x + box.width) / self.world.tileSize) do
        local tileY = math.floor(groundY / self.world.tileSize)
        if tileY >= 1 and tileY <= self.world.mapHeight and x >= 1 and x <= self.world.mapWidth then
            if self.world.mapData[tileY][x] == self.world.WALL then
                return true
            end
        end
    end
    
    return false
end

function Spider:jump(height, horizontalSpeed)
    if self.isGrounded then
        self.velocityY = -height
        self.velocityX = horizontalSpeed or (self.direction * self.speed)
        self.isGrounded = false
    end
end

function Spider:calculateLungeHeight(distance)
    local proximityFactor = 1 - math.min(1, distance / self.detectionRange)
    return self.minLungeHeight + proximityFactor * (self.maxLungeHeight - self.minLungeHeight)
end

function Spider:update(dt, player)
    self.wasGroundedLastFrame = self.isGrounded
    self.isGrounded = self:isGroundBelow()
    
    if not self.wasGroundedLastFrame and self.isGrounded then
        self.velocityX = 0  -- Fixed the extra hyphen here
    end
    
    -- Apply gravity
    if not self.isGrounded then
        self.velocityY = self.velocityY + self.gravity * dt
    else
        self.velocityY = 0
    end
    
    local prevX = self.x
    local prevY = self.y
    
    self.x = self.x + self.velocityX * dt
    self.y = self.y + self.velocityY * dt
    
    -- Check collisions and resolve possible conflict
    if self:checkCollision() then
        if prevY == self.y then
            self.x = prevX
            self.velocityX = 0
            self.direction = self.direction * -1
        else 
            self.y = prevY
            self.velocityY = 0
            if self.velocityY < 0 then
                self.velocityY = 10 
            else
                self.isGrounded = true
            end
        end
    end
    
    -- Check if player is within detection range
    local isPlayerInRange = false
    if player and not player.isDead and not player.isInShack then
        local distanceX = math.abs(self.x - player.x)
        local distanceY = math.abs(self.y - player.y)
        local distance = math.sqrt(distanceX * distanceX + distanceY * distanceY)
        
        if distance < self.detectionRange then
            isPlayerInRange = true
            self.isTrackingPlayer = true
        else
            self.isTrackingPlayer = false
        end
        
        -- Kill on collision
        if self:isCollidingWithPlayer(player) then
            player.isDead = true
        end
    else
        self.isTrackingPlayer = false
    end
    
    if self.isTrackingPlayer and player and self.isGrounded then
        local distanceX = player.x - self.x
        local distanceY = player.y - self.y
        local distance = math.sqrt(distanceX * distanceX + distanceY * distanceY)
        
        self.direction = distanceX > 0 and 1 or -1

        local lungeHeight = self:calculateLungeHeight(distance)
        
        self:jump(lungeHeight, self.direction * self.lungeSpeed * 0.7)
    elseif self.isGrounded then
        self.jumpTimer = self.jumpTimer + dt
        if self.jumpTimer >= self.jumpInterval then
            if math.random() > 0.7 then
                self.direction = self.direction * -1
            end
            
            self:jump(self.jumpForce, self.direction * self.farJumpDistance)
            
            self.jumpTimer = 0
            self.jumpInterval = math.random(5, 10)
        end
    end
    
    -- Update animation
    if not self.isGrounded then
        -- Use a specific frame for jumping
        self.currentFrame = 2
    elseif math.abs(self.velocityX) > 0 then  -- Fixed 'else if' to proper 'elseif'
        -- Animate when moving horizontally
        self.animationTimer = self.animationTimer + dt
        if self.animationTimer >= self.frameDuration then
            self.animationTimer = self.animationTimer - self.frameDuration
            self.currentFrame = self.currentFrame % self.numFrames + 1
        end
    else
        -- Resting frame
        self.currentFrame = 1
    end
end

-- Check if the entity is colliding with the player
function Spider:isCollidingWithPlayer(player)
    if player.isInShack then
        return false
    end
    
    local spiderBox = self:getCollisionBox()
    local playerBox = player:getCollisionBox()
    
    return spiderBox.x < playerBox.x + playerBox.width and
           spiderBox.x + spiderBox.width > playerBox.x and
           spiderBox.y < playerBox.y + playerBox.height and 
           spiderBox.y + spiderBox.height > playerBox.y
end

function Spider:draw(cameraY)
    local scaleX = self.size / self.frameWidth
    if self.direction < 0 then scaleX = -scaleX end
    
    -- Draw the entity
    love.graphics.setColor(1, 1, 1, 1)
    
    local success = pcall(function()
        local quad = love.graphics.newQuad(
            (self.currentFrame - 1) * self.frameWidth,
            0,
            self.frameWidth,
            self.sprite:getHeight(),
            self.sprite:getWidth(),
            self.sprite:getHeight()
        )
        
        love.graphics.draw(
            self.sprite,
            quad,
            self.x + (self.direction < 0 and self.size or 0),
            self.y - cameraY,
            0,
            scaleX,
            self.size / self.sprite:getHeight()
        )
    end)
end

return Spider
