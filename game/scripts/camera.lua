local Camera = {}

function Camera:new(windowWidth, windowHeight)
    local obj = {
        x = 0,
        y = 0,
        targetX = 0,
        targetY = 0,
        smoothing = 4,
        windowWidth = windowWidth,
        windowHeight = windowHeight
    }
    
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Camera:update(dt, target, worldWidth, worldHeight)
    -- Update camera target position to follow player
    self.targetX = target.x - self.windowWidth * 0.5
    self.targetY = target.y - self.windowHeight * 0.6
    self.x = self.x + (self.targetX - self.x) * dt * self.smoothing
    self.y = self.y + (self.targetY - self.y) * dt * self.smoothing
    
    -- keep camera in world bounds
    self.x = math.max(0, math.min(self.x, worldWidth - self.windowWidth))
    self.y = math.max(0, math.min(self.y, worldHeight - self.windowHeight))
end

function Camera:getPosition()
    return self.x, self.y
end

function Camera:applyTransform()
    love.graphics.push()
    love.graphics.translate(-self.x, 0)
end

function Camera:removeTransform()
    love.graphics.pop()
end

return Camera 