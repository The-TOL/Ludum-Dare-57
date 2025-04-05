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
        isDead = false
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
        if self.oxygen.isDepleted then
            self.isDead = true
        end
    end
end

return Canary
