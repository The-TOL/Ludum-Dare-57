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
    
    -- Load lighting shader
    local lightingShader = nil
    local useLighting = false
    
    if love.graphics.shadersSupported and love.graphics.canvasSupported then
        lightingShader = love.graphics.newShader("shaders/lighting.glsl")
        useLighting = true
    end
    
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
        showFullMap = false,
        lightingShader = lightingShader,
        useLighting = useLighting,
        lightSettings = {
            range = 2500,
            width = 7,
            ambientLight = 0.20
        }
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
    if key == "return" then
        if self.player.nearShack and not self.player.isInShack then
            self.player.isInShack = true
        elseif self.player.isInShack then
            self.player.isInShack = false
        end
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
        
        if self.useLighting then
            -- First draw all assets
            local canvas = love.graphics.newCanvas(self.windowWidth, self.windowHeight)
            
            love.graphics.setCanvas(canvas)
            love.graphics.clear()
            
            self.camera:applyTransform()
            love.graphics.setColor(1, 1, 1, 1)
        -- Background parralax logic
            for _, bg in ipairs(self.backgrounds) do
                local scaleX = self.windowWidth / bg.sprite:getWidth()
                local scaleY = self.windowHeight / bg.sprite:getHeight()
                local yOffset = (self.player.y * bg.scrollSpeed) % self.windowHeight
                local xOffset = (cameraX * bg.scrollSpeed) % self.windowWidth
                
                love.graphics.draw(bg.sprite, cameraX + xOffset, -yOffset, 0, scaleX, scaleY)
                love.graphics.draw(bg.sprite, cameraX + xOffset + self.windowWidth, -yOffset, 0, scaleX, scaleY)
            end
            
            worldGenerator.drawMap(self.world, cameraY, cameraX)
            self.player:draw(cameraY)
            self.canary:draw(self.player, cameraY)
            
            self.camera:removeTransform()
            
            love.graphics.setCanvas()
            
            -- Calculate light position and angle
            local lightSource = self.player:getLightSource()
            local playerScreenX = lightSource.x - cameraX
            local playerLightSource = {
                x = playerScreenX,
                y = lightSource.y - cameraY
            }
            
            -- Set light angle based on player direction
            local lightAngle = self.player.facingLeft and math.pi or 0
            
            -- Apply the shader 
            self.lightingShader:send("lightPosition", {playerLightSource.x, playerLightSource.y})
            self.lightingShader:send("lightAngle", lightAngle)
            self.lightingShader:send("lightWidth", self.lightSettings.width)
            self.lightingShader:send("lightRange", self.lightSettings.range)
            self.lightingShader:send("ambientLight", self.lightSettings.ambientLight)
            self.lightingShader:send("inShack", self.player.isInShack)
            
            -- Apply the shader to the drawn assets
            love.graphics.setShader(self.lightingShader)
            love.graphics.draw(canvas)
            love.graphics.setShader()
        else
            -- If lighting doesnt work for player
            self.camera:applyTransform()
            
            love.graphics.setColor(0.5, 0.5, 0.5, 1) 
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
            love.graphics.setColor(0.3, 0.3, 0.3, 1) 
            worldGenerator.drawMap(self.world, cameraY, cameraX)
            
            -- Draw player and canary
            love.graphics.setColor(0.7, 0.7, 0.7, 1) 
            self.player:draw(cameraY)
            self.canary:draw(self.player, cameraY)
            
            self.camera:removeTransform()
        end
        
        -- Draw oxygen meters
        love.graphics.setColor(1, 1, 1, 1)
        -- Player oxygen meter
        love.graphics.rectangle("line", 10, 10, 200, 20)
        love.graphics.rectangle("fill", 10, 10, 200 * self.player.oxygen:getPercentage(), 20)
        -- Canary oxygen meter
        love.graphics.rectangle("line", 10, 40, 100, 10)
        love.graphics.rectangle("fill", 10, 40, 100 * self.canary.oxygen:getPercentage(), 10)
        
        -- Draw prompts
        local promptInfo = self.player:getPromptInfo(cameraY)
        if promptInfo then
            love.graphics.setColor(1, 1, 1, 1) 
            if promptInfo.isScreenSpace then
                love.graphics.print(promptInfo.text, promptInfo.x, promptInfo.y)
            else
                self.camera:applyTransform()
                love.graphics.print(promptInfo.text, promptInfo.x, promptInfo.y)
                self.camera:removeTransform()
            end
        end
        
        -- Draw death screen
        if self.player.isDead then
            self.deathScreen:draw()
        end
    end
end

return Game
