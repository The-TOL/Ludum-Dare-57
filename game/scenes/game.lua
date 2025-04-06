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
        world = world,
        showFullMap = false
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
        -- Sync canary oxygen refill with player's state
        self.canary.oxygen.isRefilling = self.player.oxygen.isRefilling
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
    if key == "space" and not self.player.isJumping and not self.player.isDead then
        self.player.velocityY = -300
        self.player.isJumping = true
    end
    if key == "i" then
        self.player.oxygen:toggleRefill()
        self.canary.oxygen:toggleRefill()
    end
    if key == "j" then
        self.player.speed = 2000
    end
    if key == "f3" then  
        self.showFullMap = not self.showFullMap
    end
    if key == "g" then
        self.world = worldGenerator.generateWorld(32)
        self.player.x = self.world.playerStartX
        self.player.y = self.world.playerStartY
    end
end

function Game:draw()
    if self.showFullMap then
        -- Draw debug map
        love.graphics.setColor(1, 1, 1, 1)
        
        local scaleX = self.windowWidth / (self.world.width)
        local scaleY = self.windowHeight / (self.world.height)
        local scale = math.min(scaleX, scaleY)
        
        local offsetX = (self.windowWidth - (self.world.width * scale)) / 2
        local offsetY = (self.windowHeight - (self.world.height * scale)) / 2

        love.graphics.push()
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(scale, scale)
        
        -- Draw map with colors for tiles
        for y = 1, self.world.mapHeight do
            for x = 1, self.world.mapWidth do
                local tileX = (x-1) * self.world.tileSize
                local tileY = (y-1) * self.world.tileSize
                
                if self.world.mapData[y][x] == self.world.WALL then
                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                elseif self.world.mapData[y][x] == self.world.TUNNEL then
                    love.graphics.setColor(0, 0.7, 0, 1)
                elseif self.world.mapData[y][x] == self.world.BLOCKAGE then
                    love.graphics.setColor(1, 0, 0, 1)
                end
                
                love.graphics.rectangle("fill", tileX, tileY, 
                    self.world.tileSize, self.world.tileSize)
            end
        end
        
        -- Draw player position indicator
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.circle("fill", self.player.x, self.player.y, 10)
        
        love.graphics.pop()
    else
        local cameraX, cameraY = self.camera:getPosition()
        self.camera:applyTransform()
        
        -- Background parralax logic
        love.graphics.setColor(1, 1, 1, 1)
        for _, bg in ipairs(self.backgrounds) do
            local scaleX = self.windowWidth / bg.sprite:getWidth()
            local scaleY = self.windowHeight / bg.sprite:getHeight()
            local yOffset = (self.player.y * bg.scrollSpeed) % self.windowHeight
            local xOffset = (cameraX * bg.scrollSpeed) % self.windowWidth
            
            -- Draw background
            love.graphics.draw(bg.sprite, cameraX + xOffset, -yOffset, 0, scaleX, scaleY)
            love.graphics.draw(bg.sprite, cameraX + xOffset + self.windowWidth, -yOffset, 0, scaleX, scaleY)
        end
        
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
end

return Game
