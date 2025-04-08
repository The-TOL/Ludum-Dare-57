local Button = require("scripts/button")
local DeathScreen = require("scenes/death_screen")
local Player = require("scripts/player")
local Canary = require("scripts/canary")
local Camera = require("scripts/camera")
local worldGenerator = require("scenes.world_generator")

local Game = {}

function Game:new(windowWidth, windowHeight, onMainMenu)
    --- Define the player, canary, background and death screen
    local world = worldGenerator.generateWorld(32)
    
    local obj = {
        player = Player:new(world.playerStartX, world.playerStartY),
        canary = Canary:new(),
        camera = Camera:new(windowWidth, windowHeight),
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
        windowWidth = windowWidth,
        windowHeight = windowHeight,
        world = world
    }

    obj.deathScreen = DeathScreen:new(
        windowWidth, 
        windowHeight,
        function() 
            obj.world = worldGenerator.generateWorld(32)
            obj.player = Player:new(obj.world.playerStartX, obj.world.playerStartY)
            obj.canary = Canary:new()
            obj.camera = Camera:new(windowWidth, windowHeight)
        end,
        onMainMenu
    )

    -- Set initial camera position to focus on player
    obj.camera:update(0, obj.player, obj.world.width, obj.world.height)

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Game update functions, see game.lua/player.lua
function Game:update(dt)
    if not self.player.isDead then
        self.player:update(dt, self.world, self.windowWidth)
        self.canary:update(dt)
        self.camera:update(dt, self.player, self.world.width, self.world.height)
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
        self.player.velocityY = -850
        self.player.isJumping = true
        if self.onGround then
            self.onGround = false
        end
    end
    if key == "i" then
        self.player.oxygen:toggleRefill()
        self.canary.oxygen:toggleRefill()
    end
end

function Game:draw()
    local cameraX, cameraY = self.camera:getPosition()
    -- Background parralax logic
    love.graphics.setColor(1, 1, 1, 1)
    for _, bg in ipairs(self.backgrounds) do
        local scaleX = self.windowWidth / bg.sprite:getWidth()
        local scaleY = self.windowHeight / bg.sprite:getHeight()
        local yOffset = (self.player.y * bg.scrollSpeed) % self.windowHeight

        local parallaxX = cameraX * bg.scrollSpeed
        
        -- First background
        love.graphics.draw(bg.sprite, -parallaxX % self.windowWidth, -yOffset, 0, scaleX, scaleY)
        -- Second background (for seamless scrolling)
        love.graphics.draw(bg.sprite, (-parallaxX % self.windowWidth) - self.windowWidth, -yOffset, 0, scaleX, scaleY)
        -- Third background (for seamless scrolling in the other direction)
        love.graphics.draw(bg.sprite, (-parallaxX % self.windowWidth) + self.windowWidth, -yOffset, 0, scaleX, scaleY)
    end
    
    self.camera:applyTransform()
    
    -- Draw the walls
    worldGenerator.drawMap(self.world, cameraY, cameraX)
    
    -- Draw player and canary
    self.player:draw(cameraY)
    self.canary:draw(self.player, cameraY)
    
    self.camera:removeTransform()
    
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