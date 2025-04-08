--TODO player changing color when touching some tiles?, also add vertical tiles in front of player
local mapGenerator = require("scripts.map_generator")

local worldGenerator = {}

function worldGenerator.generateWorld(tileSize)
    tileSize = tileSize or 32
    local worldSeed = mapGenerator.newSeed()
    local mapData, mainMineX, playerStartY, levels, levelTunnels, doorPositions = mapGenerator.generateAccessibleMine()
    local playerStartWorldX = (mainMineX - 1) * tileSize + (tileSize / 2)
    local playerStartWorldY = (playerStartY - 1) * tileSize + (tileSize / 2)
    
    -- Create level-specific data
    local levelData = {}
    
    for i, levelY in ipairs(levels) do
        levelData[i] = {
            yPosition = levelY,
            worldY = (levelY - 1) * tileSize,
            isCompleted = false,
            hasCanary = false,
            oxygenLevel = 100,
            doors = doorPositions[i]
        }
    end
    
    -- Constants for map tiles
    local DOORS = mapGenerator.DOORS
    
    local world = {
        seed = worldSeed,
        mapData = mapData,
        tileSize = tileSize,
        width = mapGenerator.MAP_W * tileSize,
        height = mapGenerator.MAP_H * tileSize,
        mapWidth = mapGenerator.MAP_W,
        mapHeight = mapGenerator.MAP_H,
        levels = levels,
        levelData = levelData,
        WALL = mapGenerator.WALL,
        TUNNEL = mapGenerator.TUNNEL,
        BLOCKAGE = mapGenerator.BLOCKAGE,
        DOORS = mapGenerator.DOORS,
        PLATFORM = mapGenerator.PLATFORM,
        VERTICAL_TUNNEL = mapGenerator.VERTICAL_TUNNEL,
        playerStartX = playerStartWorldX,
        playerStartY = playerStartWorldY,
        doorPositions = doorPositions
    }
    
    return world
end 

function worldGenerator.getDoorCollision(world, x, y, width, height)
    local tileX = math.floor(x / world.tileSize) + 1
    local tileY = math.floor(y / world.tileSize) + 1
    if world.mapData[tileY][tileX] == world.DOORS then
        local currentLevel = mapGenerator.getCurrentLevel(tileY, world.levels)
        return { isDoor = true, level = currentLevel }
    end
    return false
end

function worldGenerator.teleportThroughDoor(world, player, doorCollision)
    local currentLevel = doorCollision.level
    local targetLevel = currentLevel - 1

    -- Get target level's vertical range
    local targetLevelData = world.levelData[targetLevel]
    local levelStartY = targetLevelData.yPosition
    local levelEndY = targetLevel < #world.levels 
        and (world.levelData[targetLevel + 1].yPosition - 1) 
        or world.mapHeight

    -- Find all doors in target level
    local targetDoors = {}
    for y = levelStartY, levelEndY do
        for x = 1, world.mapWidth do
            if world.mapData[y][x] == world.DOORS then
                table.insert(targetDoors, {x = x, y = y})
            end
        end
    end

    print("Current Level:", currentLevel)
    print("Target Level:", targetLevel)

    print(targetLevelData)
    print("Level Start Y:", levelStartY)
    print("Level End Y:", levelEndY)

    print("Number of Target Doors:", #targetDoors)

    if #targetDoors > 0 then
        local door = targetDoors[math.random(#targetDoors)]
        player.x = (door.x - 1) * world.tileSize + (world.tileSize / 2)
        player.y = (door.y - 1) * world.tileSize + (world.tileSize / 2)
    end
        print("No doors found in target level.")
    return false
end

-- Update checkCollision to incorporate door detection
function worldGenerator.checkCollision(world, x, y, width, height)
    width = width or world.tileSize
    height = height or world.tileSize

    -- Calculate collision bounds using player's collision box
    local left = x
    local right = x + width
    local top = y
    local bottom = y + height

    -- Convert to tile coordinates
    local tileLeft = math.floor(left / world.tileSize) + 1
    local tileRight = math.ceil(right / world.tileSize)
    local tileTop = math.floor(top / world.tileSize) + 1
    local tileBottom = math.ceil(bottom / world.tileSize)

    -- Ensure were checking within map bounds
    tileLeft = math.max(1, math.min(tileLeft, world.mapWidth))
    tileRight = math.max(1, math.min(tileRight, world.mapWidth))
    tileTop = math.max(1, math.min(tileTop, world.mapHeight))
    tileBottom = math.max(1, math.min(tileBottom, world.mapHeight))

    -- Check all tiles in collision area
    for checkY = tileTop, tileBottom do
        for checkX = tileLeft, tileRight do
            local tileType = world.mapData[checkY][checkX]
            
            if tileType == world.DOORS then
                return { 
                    isDoor = true, 
                    level = mapGenerator.getCurrentLevel(checkY, world.levels) 
                }
            end
        end
    end
    
    -- Check for walls and platforms
    for checkY = tileTop, tileBottom do
        for checkX = tileLeft, tileRight do
            local tileType = world.mapData[checkY][checkX]
            
            if tileType == world.WALL then
                return { isWall = true }
            elseif tileType == world.PLATFORM then
                -- Check if character is above the platform
                local tileTopY = (checkY - 1) * world.tileSize
                local playerBottom = bottom
                
                if playerBottom >= tileTopY and playerBottom <= tileTopY + world.tileSize/2 then
                    return {
                        isPlatform = true,
                        resolveY = tileTopY - height
                    }
                end
            end
        end
    end
    
    return false
end
-- Get tile at wordl position
function worldGenerator.getTileAtPosition(world, x, y)
    local mapX = math.floor(x / world.tileSize) + 1
    local mapY = math.floor(y / world.tileSize) + 1
    
    if mapX < 1 or mapX > world.mapWidth or mapY < 1 or mapY > world.mapHeight then
        return nil
    end
    
    return world.mapData[mapY][mapX]
end

--Drawing map
function worldGenerator.drawMap(world, cameraY, cameraX)
    -- Wall color
    local wallColor = {0.5,0.5,0.5,1}
    -- Door color
    local doorColor = {0.8, 0.4, 0.1, 1}
    -- Vertical tunnel color
    local TunnelColor = {0.5,0.5,0.5,1}
    local blockageColor = {1, 0.1, 0.1, 1}
    local platformColor = {0.3, 0.7, 0.3, 1}
    
    -- Calculate visible area
    local startY = math.floor(cameraY / world.tileSize)
    local endY = math.ceil((cameraY + love.graphics.getHeight()) / world.tileSize)
    local startX = math.floor(cameraX / world.tileSize)
    local endX = math.ceil((cameraX + love.graphics.getWidth()) / world.tileSize)
    
    -- Ensure were within map bounds
    startY = math.max(1, startY)
    endY = math.min(world.mapHeight, endY)
    startX = math.max(1, startX)
    endX = math.min(world.mapWidth, endX)
    
    -- First draw regular tiles
    for y = startY, endY do
        for x = startX, endX do
            local tileType = world.mapData[y][x]
            if tileType == world.WALL then
                love.graphics.setColor(wallColor)
                love.graphics.rectangle(
                    "fill", 
                    (x-1) * world.tileSize, 
                    (y-1) * world.tileSize - cameraY, 
                    world.tileSize, 
                    world.tileSize
                )
            elseif tileType == world.DOORS then
                love.graphics.setColor(doorColor)
                love.graphics.rectangle(
                    "fill", 
                    (x-1) * world.tileSize, 
                    (y-1) * world.tileSize - cameraY, 
                    world.tileSize, 
                    world.tileSize
                )
            elseif tileType == world.BLOCKAGE then
                love.graphics.setColor(blockageColor)
                love.graphics.rectangle(
                    "fill", 
                    (x-1) * world.tileSize, 
                    (y-1) * world.tileSize - cameraY, 
                    world.tileSize, 
                    world.tileSize
                )
            elseif tileType == world.PLATFORM then
                love.graphics.setColor(wallColor)
                love.graphics.rectangle(
                    "fill", 
                    (x-1) * world.tileSize, 
                    (y-1) * world.tileSize - cameraY, 
                    world.tileSize, 
                    world.tileSize
                )
            end
        end
    end
end

return worldGenerator