local Oxygen = require("scripts/oxygen")

local Canary = {}

function Canary:new()
    -- Define variables for the canary
    local obj = {
        sprite = love.graphics.newImage("assets/visual/canary.png"),
        size = 30,
        anchorX = 85,
        anchorY = 94,
        oxygen = Oxygen:new(180, 2), 
        isDead = false,
        clickSound = love.audio.newSource("assets/audio/chirp.mp3", "static"),
        alertThresholds = {0.2, 0.1},
        lastThresholdIndex = nil,
        angle = 0,                  
        angularVelocity = 0,     
        springConstant = 6,         
        damping = 0.995,            
        maxAngle = 1.2,             
        swingForce = 1.4          
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Anchor canary sprite relative to the player
function Canary:draw(player, cameraY)
    if not self.isDead and not player.isInShack then
        local canaryScaleX = self.size / self.sprite:getWidth()
        local canaryX
        
        if player.facingLeft then 
            canaryScaleX = -canaryScaleX
            canaryX = player.x + player.size - self.anchorX
        else
            canaryX = player.x + self.anchorX
        end

        -- Apply swing
        love.graphics.draw(
            self.sprite,
            canaryX,
            player.y + self.anchorY - cameraY,
            self.angle, 
            canaryScaleX,
            self.size / self.sprite:getHeight(),
            self.sprite:getWidth() / 2, 
            0
        )
    end
end

function Canary:update(dt)
    if not self.isDead then
        -- Physics swinging
        local acceleration = -self.springConstant * self.angle
        
        if love.keyboard.isDown("a") then
            acceleration = acceleration + self.swingForce
        end
        if love.keyboard.isDown("d") then
            acceleration = acceleration - self.swingForce
        end
        
        self.angularVelocity = self.angularVelocity + acceleration * dt
        self.angularVelocity = self.angularVelocity * self.damping
        self.angle = self.angle + self.angularVelocity * dt
        
        self.angle = math.max(-self.maxAngle, math.min(self.maxAngle, self.angle))

        self.oxygen:update(dt)
        
        -- Delete canary when dead
        -- Check oxygen thresholds and play sound when at 20% or lower
        local oxygenPercent = self.oxygen:getPercentage()
        for i, threshold in ipairs(self.alertThresholds) do
            if oxygenPercent <= threshold and self.lastThresholdIndex ~= i then
                self.clickSound:play()
                self.lastThresholdIndex = i
            end
        end
        if oxygenPercent > self.alertThresholds[1] then
            self.lastThresholdIndex = nil
        end

        if self.oxygen.isDepleted then
            self.isDead = true
        end
    end
end

return Canary
