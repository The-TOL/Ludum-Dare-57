local Stalker = {}

function Stalker:new(x, y, world)
    local obj = {
        x = x,
        y = y,
        size = 80,
        speed = 100,
        direction = math.random(0, 1) == 0 and -1 or 1, 
        moveTimer = 0,
        isMoving = true,
        moveInterval = math.random(5, 10),
        pauseInterval = math.random(1, 3), 
        world = world,
        sprite = love.graphics.newImage("assets/visual/stalker.png"),
        frameWidth = nil,
        currentFrame = 1,
        animationTimer = 0,
        frameDuration = 0.2,
        numFrames = 4,
        velocityY = 0,
        gravity = 500,
        isJumping = false,
        collisionBox = {
            offsetX = 25,
            offsetY = 15,
            width = 30,
            height = 65
        },
        detectionRange = 1200,
        isTrackingPlayer = false,
        trackingSpeed = 150 
    }
    
    pcall(function()
        obj.frameWidth = obj.sprite:getWidth() / obj.numFrames
    end)
    
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Set up collision
function Stalker:getCollisionBox()
    return {
        x = self.x + self.collisionBox.offsetX,
        y = self.y + self.collisionBox.offsetY,
        width = self.collisionBox.width,
        height = self.collisionBox.height
    }
end

function Stalker:checkCollision()
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

function Stalker:update(dt, player)
    -- Apply gravity
    local prevY = self.y
    self.velocityY = self.velocityY + self.gravity * dt
    self.y = self.y + self.velocityY * dt
    
    -- Collision
    if self:checkCollision() then
        self.y = prevY
        self.velocityY = 0
        self.isJumping = false
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
    
    if self.isTrackingPlayer and player then
        local prevX = self.x
        
        if self.x < player.x then
            self.direction = 1
            self.x = self.x + self.trackingSpeed * dt
        else
            self.direction = -1
            self.x = self.x - self.trackingSpeed * dt
        end
        
        if self:checkCollision() then
            self.x = prevX
        end
        
        self.animationTimer = self.animationTimer + dt
        if self.animationTimer >= self.frameDuration then
            self.animationTimer = self.animationTimer - self.frameDuration
            self.currentFrame = self.currentFrame % self.numFrames + 1
        end
    else
        self.moveTimer = self.moveTimer + dt
        
        -- Moving
        if self.isMoving then
            if self.moveTimer >= self.moveInterval then
                self.isMoving = false
                self.moveTimer = 0
                self.pauseInterval = math.random(1, 3)
            else
                local prevX = self.x
                self.x = self.x + self.speed * self.direction * dt
                
                if self:checkCollision() then
                    self.x = prevX
                    self.direction = self.direction * -1
                end
            end
        -- Not moving
        else
            if self.moveTimer >= self.pauseInterval then
                self.isMoving = true
                self.moveTimer = 0
                self.moveInterval = math.random(5, 10)
                if math.random() > 0.5 then
                    self.direction = self.direction * -1
                end
            end
        end
        
        if self.isMoving then
            self.animationTimer = self.animationTimer + dt
            if self.animationTimer >= self.frameDuration then
                self.animationTimer = self.animationTimer - self.frameDuration
                self.currentFrame = self.currentFrame % self.numFrames + 1
            end
        else
            self.currentFrame = 1
        end
    end
end

-- Check if the entity is colliding with the player
function Stalker:isCollidingWithPlayer(player)
    if player.isInShack then
        return false
    end
    
    local stalkerBox = self:getCollisionBox()
    local playerBox = player:getCollisionBox()
    
    return stalkerBox.x < playerBox.x + playerBox.width and
           stalkerBox.x + stalkerBox.width > playerBox.x and
           stalkerBox.y < playerBox.y + playerBox.height and 
           stalkerBox.y + stalkerBox.height > playerBox.y
end

function Stalker:draw(cameraY)
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

return Stalker
