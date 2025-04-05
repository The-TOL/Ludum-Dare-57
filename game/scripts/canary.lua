local Oxygen = require("scripts/oxygen")

local Canary = {}

function Canary:new()
    -- Define variables for the canary
    local obj = {
        sprite = love.graphics.newImage("assets/visual/canary.png"),
        size = 40,
        anchorX = 65,
        anchorY = 68,
        oxygen = Oxygen:new(80, 10), 
        isDead = false,
        clickSound = love.audio.newSource("assets/audio/click.mp3", "static"),
        alertThresholds = {0.2, 0.1},
        lastThresholdIndex = nil
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Anchor canary sprite relative to the player
function Canary:draw(player, cameraY)
    if not self.isDead then
        local canaryScaleX = self.size / self.sprite:getWidth()
        local canaryX
        
        if player.facingLeft then 
            canaryScaleX = -canaryScaleX
            canaryX = player.x + player.size - self.anchorX
        else
            canaryX = player.x + self.anchorX
        end

        love.graphics.draw(
            self.sprite,
            canaryX,
            player.y + self.anchorY - cameraY,
            0,
            canaryScaleX,
            self.size / self.sprite:getHeight()
        )
    end
end

-- Delete canary when dead
function Canary:update(dt)
    if not self.isDead then
        self.oxygen:update(dt)
        
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
