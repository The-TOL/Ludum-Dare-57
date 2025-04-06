local Button = require("scripts/button")
local DeathScreen = require("scenes/death_screen")
local Player = require("scripts/player")
local Canary = require("scripts/canary")

local Game = {}

function Game:new(windowWidth, windowHeight, onMainMenu)
    --- Define the player, canary, background and death screen
    local obj = {
        player = Player:new(400, 100),
        canary = Canary:new(),
        backgrounds = {
            {
                sprite = love.graphics.newImage("assets/visual/grey_L1.png"),
                scrollSpeed = 0.01
            },
            {
                sprite = love.graphics.newImage("assets/visual/grey_L2.png"),
                scrollSpeed = 0.02
            },
            {
                sprite = love.graphics.newImage("assets/visual/grey_L3.png"),
                scrollSpeed = 0.03
            },
            {
                sprite = love.graphics.newImage("assets/visual/grey_L4.png"),
                scrollSpeed = 0.04
            }
        },
        cameraY = 100,
        windowWidth = windowWidth,
        windowHeight = windowHeight,
    }

    obj.deathScreen = DeathScreen:new(
        windowWidth, 
        windowHeight,
        function() 
            -- Recreate player and canary instead of just respawning (UPDATE THIS TO RESTART THE ENTIRE SCENE LATER)
            obj.player = Player:new(400, 100)
            obj.canary = Canary:new()
        end,
        onMainMenu
    )

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Game update functions, see game.lua/player.lua
function Game:update(dt)
    if not self.player.isDead then
        self.player:update(dt, self.windowWidth)
        self.canary:update(dt)
        self.cameraY = self.player.y - self.windowHeight * 0.4
    end
end

-- Click listener for game
function Game:mousepressed(x, y, button)
    if self.player.isDead then
        self.deathScreen:mousepressed(x, y, button)
    end
end

-- Unique inputs (y kills player, u stops falling, space is jump, i toggles oxgen deplete/refill)
function Game:keypressed(key)
    if key == "y" then
        self.player.isDead = true
    end
    if key == "u" then
        self.player.gravity = 0
        self.player.velocityY = 0
    end
    if key == "space" and not self.player.isJumping and not self.player.isDead then
        self.player.velocityY = -300
        self.player.isJumping = true
    end
    if key == "i" then
        self.player.oxygen:toggleRefill()
        self.canary.oxygen:toggleRefill()
    end
end

function Game:draw()
    -- Background parralax logic
    love.graphics.setColor(1, 1, 1, 1)
    for _, bg in ipairs(self.backgrounds) do
        local scaleX = self.windowWidth / bg.sprite:getWidth()
        local scaleY = self.windowHeight / bg.sprite:getHeight()
        local yOffset = (self.player.y * bg.scrollSpeed) % self.windowHeight
        
        love.graphics.draw(bg.sprite, 0, -yOffset, 0, scaleX, scaleY)
        love.graphics.draw(bg.sprite, 0, self.windowHeight - yOffset, 0, scaleX, scaleY)
    end
    
    -- Draw player and canary
    self.player:draw(self.cameraY)
    self.canary:draw(self.player, self.cameraY)
    
    -- Draw oxygen meters
    love.graphics.setColor(1, 1, 1, 1)
    -- Player oxygen meter
    love.graphics.rectangle("line", 10, 10, 200, 20)
    love.graphics.rectangle("fill", 10, 10, 200 * self.player.oxygen:getPercentage(), 20)
    -- Canary oxygen meter
    love.graphics.rectangle("line", 10, 40, 100, 10)
    love.graphics.rectangle("fill", 10, 40, 100 * self.canary.oxygen:getPercentage(), 10)
    
    -- Draw death screen
    if self.player.isDead then
        self.deathScreen:draw()
    end
end

return Game
