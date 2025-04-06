local Oxygen = {}

function Oxygen:new(maxOxygen, depletionRate)
    -- Define variables for oxygen
    local obj = {
        maxOxygen = maxOxygen or 100,
        currentOxygen = maxOxygen or 100,
        depletionRate = depletionRate or 1,
        refillRate = 20, -- Refills 20 oxygen per second
        isDepleted = false,
        isRefilling = false
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Decrease oxygen till 0 or refill to max
function Oxygen:update(dt)
    if not self.isDepleted then
        if self.isRefilling then
            self.currentOxygen = math.min(self.currentOxygen + self.refillRate * dt, self.maxOxygen)
        else
            self.currentOxygen = self.currentOxygen - self.depletionRate * dt
            if self.currentOxygen <= 0 then
                self.currentOxygen = 0
                self.isDepleted = true
            end
        end
    end
end

-- Toggle refill state
function Oxygen:toggleRefill()
    self.isRefilling = not self.isRefilling
end

-- Refill oxygen
function Oxygen:refill(amount)
    self.currentOxygen = math.min(self.currentOxygen + amount, self.maxOxygen)
    self.isDepleted = false
end

function Oxygen:getPercentage()
    return self.currentOxygen / self.maxOxygen
end

return Oxygen
