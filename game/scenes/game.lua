local Button = require("scripts/button")
local DeathScreen = require("scenes/death_screen")
local Player = require("scripts/player")
local Canary = require("scripts/canary")
local Camera = require("scripts/camera")
local worldGenerator = require("scenes/world_generator")
local Stalker = require("scripts/stalker")
local Spider = require("scripts/spider") 

local Game = {}

function Game:new(windowWidth, windowHeight, onMainMenu)
    --- Define the player, canary, background and death screen
    local world = worldGenerator.generateWorld(32)
    
    -- Load lighting shader
    local lightingShader = nil
    local useLighting = false
    local gameCanvas = nil
    
    if love.graphics.shadersSupported and love.graphics.canvasSupported then
        lightingShader = love.graphics.newShader("shaders/lighting.glsl")
        useLighting = true
        -- Create canvas once instead of every frame (oops!)
        gameCanvas = love.graphics.newCanvas(windowWidth, windowHeight)
    end
    
    -- Pre-load and cache all background images to avoid reloading
    local backgrounds = {}
    local bgImages = {
        "assets/visual/grey_L1.png",
        "assets/visual/grey_L2.png",
        "assets/visual/grey_L3.png",
        "assets/visual/grey_L4.png"
    }
    
    for i, path in ipairs(bgImages) do
        backgrounds[i] = {
            sprite = love.graphics.newImage(path),
            scrollSpeed = i * 0.01
        }
    end
    
    local obj = {
        player = Player:new(world.playerStartX, world.playerStartY),
        canary = Canary:new(),
        camera = Camera:new(windowWidth, windowHeight),
        backgrounds = backgrounds,
        windowWidth = windowWidth,
        windowHeight = windowHeight,
        world = world,
        showFullMap = false,
        lightingShader = lightingShader,
        useLighting = useLighting,
        gameCanvas = gameCanvas,
        lightSettings = {
            range = 2500,
            width = 7,
            ambientLight = 0.20
        },
        stalkers = {},  -- (holds both entities)
        spawners = {},
        spawnerTimers = {}
    }

    obj.deathScreen = DeathScreen:new(
        windowWidth, 
        windowHeight,
        function() 
            -- Cleanup old world data
            obj.world = worldGenerator.generateWorld(32)
            obj.player = Player:new(obj.world.playerStartX, obj.world.playerStartY)
            obj.canary = Canary:new()
            obj.camera = Camera:new(windowWidth, windowHeight)
            
            collectgarbage("collect")
        end,
        onMainMenu
    )

    -- Set initial camera position to focus on player
    obj.camera:update(0, obj.player, obj.world.width, obj.world.height)

    -- Find and initialize spawners
    for y = 1, obj.world.mapHeight do
        for x = 1, obj.world.mapWidth do
            if obj.world.mapData[y][x] == obj.world.SPAWNER then
                local spawnerX = (x - 1) * obj.world.tileSize + (obj.world.tileSize / 2) 
                local spawnerY = (y - 1) * obj.world.tileSize + (obj.world.tileSize / 2)
                
                table.insert(obj.spawners, {
                    x = spawnerX,
                    y = spawnerY,
                    tileX = x,
                    tileY = y
                })
                table.insert(obj.spawnerTimers, math.random(3, 20))
            end
        end
    end

    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Calculate distance between two points
local function distanceBetween(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Game update functions, see game.lua/player.lua
function Game:update(dt)
    if not self.player.isDead then
        self.player:update(dt, self.world, self.windowWidth)
        -- Sync canary oxygen refill with player's state
        self.canary.oxygen.isRefilling = self.player.oxygen.isRefilling
        self.canary:update(dt)
        self.camera:update(dt, self.player, self.world.width, self.world.height)
        
        -- Update spawners
        for i, timer in ipairs(self.spawnerTimers) do
            self.spawnerTimers[i] = timer - dt
            
            -- Spawn when expired
            if self.spawnerTimers[i] <= 0 then
                local spawner = self.spawners[i]
                
                -- Only spawn if it's not too close to player (avoid sudden deaths)
                local distToPlayer = distanceBetween(spawner.x, spawner.y, self.player.x, self.player.y)
                -- Get position above the spawner tile
                local spawnX, spawnY = worldGenerator.getSpawnPositionAboveTile(
                    self.world, 
                    spawner.tileX, 
                    spawner.tileY
                )
                
                -- Randomly decide whether to spawn a Stalker or a Spider
                if math.random() < 0.5 then
                    table.insert(self.stalkers, Stalker:new(spawnX, spawnY, self.world))
                else
                    table.insert(self.stalkers, Spider:new(spawnX, spawnY, self.world))
                    
                end
                
                self.spawnerTimers[i] = math.random(3, 15)
            end
        end
        
        for i, entity in ipairs(self.stalkers) do
            entity:update(dt, self.player)
        end
        worldGenerator.update(self.world, dt)
    end
end

-- Click listener for game
function Game:mousepressed(x, y, button)
    if self.player.isDead then
        self.deathScreen:mousepressed(x, y, button)
    end
end

-- Unique inputs (y kills player, j activates super speed, space is jump, f3 shows the seed map, g regenerates the seed and return enters the shack)
function Game:keypressed(key)
    if key == "space" and not self.player.isJumping and not self.player.isDead then
        self.player.velocityY = -400

        self.player.isJumping = true
        if self.onGround then
            self.onGround = false
        end
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
                elseif self.world.mapData[y][x] == self.world.SPAWNER then
                    love.graphics.setColor(0.7, 0.2, 0.7, 1)
                end
                
                love.graphics.rectangle("fill", tileX, tileY, 
                    self.world.tileSize, self.world.tileSize)
            end
        end
        
        -- Draw player position indicator
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.circle("fill", self.player.x, self.player.y, 10)
        
        -- Add drawing entities on the map
        love.graphics.setColor(0, 0, 1, 1) 
        for _, stalker in ipairs(self.stalkers) do
            love.graphics.circle("fill", stalker.x + stalker.size/2, stalker.y + stalker.size/2, 8)
        end
        
        love.graphics.pop()
    else
        local cameraX, cameraY = self.camera:getPosition()
        
        if self.useLighting then
            love.graphics.setCanvas(self.gameCanvas)
            love.graphics.clear()
            
            local cameraX, cameraY = self.camera:getPosition()
            -- Background parralax logic
            love.graphics.setColor(1, 1, 1, 1)
            for _, bg in ipairs(self.backgrounds) do
                local scaleX = self.windowWidth / bg.sprite:getWidth()
                local scaleY = self.windowHeight / bg.sprite:getHeight()
                local yOffset = (self.player.y * bg.scrollSpeed) % self.windowHeight
        
                local parallaxX = cameraX * bg.scrollSpeed
                
                love.graphics.draw(bg.sprite, -parallaxX % self.windowWidth, -yOffset, 0, scaleX, scaleY)
                love.graphics.draw(bg.sprite, (-parallaxX % self.windowWidth) - self.windowWidth, -yOffset, 0, scaleX, scaleY)
                love.graphics.draw(bg.sprite, (-parallaxX % self.windowWidth) + self.windowWidth, -yOffset, 0, scaleX, scaleY)
            end
            
            self.camera:applyTransform()
            
            worldGenerator.drawMap(self.world, cameraY, cameraX)
            
            -- Draw entities before player
            for _, stalker in ipairs(self.stalkers) do
                stalker:draw(cameraY)
            end
            
            -- Draw player and canary
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
            love.graphics.draw(self.gameCanvas)
            love.graphics.setShader()
        else
            -- If lighting doesn't work for player
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
            
            -- Draw entities
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            for _, stalker in ipairs(self.stalkers) do
                stalker:draw(cameraY)
            end
            
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

function Game:destroy()
    if self.gameCanvas then
        self.gameCanvas:release()
        self.gameCanvas = nil
    end
    
    collectgarbage("collect")
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