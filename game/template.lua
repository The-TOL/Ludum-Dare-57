local Template = {}

-- Template for how objects and scenes work

function Template:new()
    -- Put variables here
    local obj = {
        parameter1, 
        paramater2
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Called once when the scene is loaded, same as Unity's Start()
function Template:load()
    
end

-- Called every frame to update the scene, same as Unity's Update()
function Template:update(dt)

end

-- Custom function
function Template:custom()
    
end

-- What you want to draw
function Template:draw()

end

return Template

-- This can then be used like so in other files
local Template = require("template")
templateObject = Template:new(parameter1, paramater2)