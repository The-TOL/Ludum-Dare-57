local mapGenerator = require("scripts.map_generator")

local worldGenerator = {
    shackSprite = love.graphics.newImage("assets/visual/shack.png")
}

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
        SHACK = mapGenerator.SHACK,
        SPAWNER = mapGenerator.SPAWNER, -- Add the spawner constant to the world
        DOORS = mapGenerator.DOORS,
        PLATFORM = mapGenerator.PLATFORM,
        VERTICAL_TUNNEL = mapGenerator.VERTICAL_TUNNEL,
        playerStartX = playerStartWorldX,
        playerStartY = playerStartWorldY,
        doorPositions = doorPositions,
        doorConnections = {},
        currentLevel = 1
    }
    
    -- Stay away from player start position
    local safeRadius = 500
    local minSpawnerDistance = 300  -- Minimum distance between spawners
    local maxSpawnersPerLevel = 2   -- Maximum spawners per level
    local placedSpawners = {}       -- Track positions of placed spawners
    local spawnersPerLevel = {}     -- Track count of spawners on each level
    
    -- Initialize spawners per level counter
    for i=1, #levels do
        spawnersPerLevel[i] = 0
    end
    
    -- Total number of spawners to place
    local totalSpawners = 12
    local spawnerCount = 0
    local attempts = 0
    local maxAttempts = 800
    
    -- Alternate through levels to ensure even distribution
    while spawnerCount < totalSpawners and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Select a level based on current spawner distribution
        local targetLevel = 1
        if #levels > 1 then
            -- Skip the player starting level (level 1) more often
            if spawnerCount > 0 and math.random() > 0.2 then
                -- Find level with least spawners
                local minSpawners = math.huge
                for i=2, #levels do
                    if spawnersPerLevel[i] < minSpawners then
                        minSpawners = spawnersPerLevel[i]
                        targetLevel = i
                    end
                end
                
                -- If the level with minimum spawners already has the max allowed,
                -- try a random level (except first level)
                if spawnersPerLevel[targetLevel] >= maxSpawnersPerLevel then
                    targetLevel = math.random(2, #levels)
                end
            end
        end
        
        -- Get y-range for this level
        local levelY = levels[targetLevel]
        local levelYRange = 30  -- Search range around the level
        local minY = math.max(1, levelY - levelYRange)
        local maxY = math.min(world.mapHeight, levelY + levelYRange)
        
        -- Try to place a spawner in this level
        local randX = math.random(1, world.mapWidth)
        local randY = math.random(minY, maxY)
        
        if world.mapData[randY][randX] == world.TUNNEL then
            local tileX = (randX - 1) * world.tileSize + (world.tileSize / 2)
            local tileY = (randY - 1) * world.tileSize + (world.tileSize / 2)
            local distanceToPlayer = math.sqrt((tileX - playerStartWorldX)^2 + (tileY - playerStartWorldY)^2)
            
            -- Check distance to player
            if distanceToPlayer > safeRadius then
                -- Check distance to other spawners
                local tooClose = false
                for _, spawner in ipairs(placedSpawners) do
                    local spawnerDist = math.sqrt((tileX - spawner.x)^2 + (tileY - spawner.y)^2)
                    if spawnerDist < minSpawnerDistance then
                        tooClose = true
                        break
                    end
                end
                
                -- Place the spawner if not too close to others
                if not tooClose then
                    world.mapData[randY][randX] = world.SPAWNER
                    table.insert(placedSpawners, {x = tileX, y = tileY, level = targetLevel})
                    spawnerCount = spawnerCount + 1
                    spawnersPerLevel[targetLevel] = spawnersPerLevel[targetLevel] + 1
                end
            end
        end
    end
    
    worldGenerator.establishDoorConnections(world)
    
    return world
end 

-- Establish fixed door connections between levels
function worldGenerator.establishDoorConnections(world)
    world.doorConnections = {}
    
    -- Process door connections between levels
    for level = 1, #world.levels do
        -- First level has only one door (to next level)
        if level == 1 then
            if world.levelData[level].doors and world.levelData[level].doors.left then
                world.doorConnections[1] = {
                    door = world.levelData[level].doors.left,
                    targetLevel = 2,
                    isEntrance = false
                }
            elseif world.levelData[level].doors and world.levelData[level].doors.right then
                world.doorConnections[1] = {
                    door = world.levelData[level].doors.right,
                    targetLevel = 2,
                    isEntrance = false
                }
            end
        else
            -- Door connection logic
            if world.levelData[level].doors then
                local entranceDoor, exitDoor
                if world.levelData[level].doors.left and world.levelData[level].doors.right then
                    entranceDoor = world.levelData[level].doors.left
                    exitDoor = world.levelData[level].doors.right
                elseif world.levelData[level].doors.left then
                    entranceDoor = world.levelData[level].doors.left
                elseif world.levelData[level].doors.right then
                    entranceDoor = world.levelData[level].doors.right
                end
                
                -- Only set connections if doors exist
                if entranceDoor then
                    world.doorConnections[#world.doorConnections + 1] = {
                        door = entranceDoor,
                        targetLevel = level - 1,
                        isEntrance = true
                    }
                end
                
                if exitDoor and level < #world.levels then
                    world.doorConnections[#world.doorConnections + 1] = {
                        door = exitDoor,
                        targetLevel = level + 1,
                        isEntrance = false
                    }
                end
            end
        end
    end
end

function worldGenerator.getDoorInfo(world, tileX, tileY)
    for i, connection in ipairs(world.doorConnections) do
        local door = connection.door
        if door.x == tileX and door.y == tileY then
            return connection
        end
    end
    return nil
end

-- Search for valid doors
function worldGenerator.getDoorCollision(world, x, y, width, height)
    local tileX = math.floor(x / world.tileSize) + 1
    local tileY = math.floor(y / world.tileSize) + 1
    
    if world.mapData[tileY][tileX] == world.DOORS then
        local doorInfo = worldGenerator.getDoorInfo(world, tileX, tileY)
        if doorInfo then
            return { 
                isDoor = true, 
                x = tileX, 
                y = tileY,
                doorInfo = doorInfo
            }
        end
    end
    
    
    local expandedSearchArea = 1 
    for searchY = math.max(1, tileY - expandedSearchArea), math.min(world.mapHeight, tileY + expandedSearchArea) do
        for searchX = math.max(1, tileX - expandedSearchArea), math.min(world.mapWidth, tileX + expandedSearchArea) do
            if not (searchX == tileX and searchY == tileY) then
                if world.mapData[searchY][searchX] == world.DOORS then
                    local doorInfo = worldGenerator.getDoorInfo(world, searchX, searchY)
                    if doorInfo then
                        return { 
                            isDoor = true, 
                            x = searchX, 
                            y = searchY,
                            doorInfo = doorInfo
                        }
                    end
                end
            end
        end
    end
    
    return false
end

function worldGenerator.teleportThroughDoor(world, player, doorCollision)
    local doorInfo = doorCollision.doorInfo
    if not doorInfo then return false end
    
    local previousLevel = world.currentLevel
    world.currentLevel = doorInfo.targetLevel
    
    local targetDoor = nil
    
    for _, connection in ipairs(world.doorConnections) do
        if connection.targetLevel == previousLevel and
           ((doorInfo.isEntrance and not connection.isEntrance) or
            (not doorInfo.isEntrance and connection.isEntrance)) then
            targetDoor = connection.door
            break
        end
    end
    
    if not targetDoor then
        local doorsInTargetLevel = {}
        for _, connection in ipairs(world.doorConnections) do
            local door = connection.door
            -- Find all doors in target level
            local doorLevel = mapGenerator.getCurrentLevel(door.y, world.levels)
            if doorLevel == world.currentLevel then
                table.insert(doorsInTargetLevel, door)
            end
        end
        
        if #doorsInTargetLevel > 0 then
            targetDoor = doorsInTargetLevel[math.random(#doorsInTargetLevel)]
        end
    end
    
    -- Go down and enforce cooldown
    if targetDoor then
        player.x = (targetDoor.x - 1) * world.tileSize + (world.tileSize / 2)
        
        local doorY = (targetDoor.y - 1) * world.tileSize + (world.tileSize / 2)
        local verticalOffset = world.tileSize * 5
        player.y = doorY - verticalOffset
        
        player.velocityY = 0
        
        if not doorInfo.isEntrance then
            world.lastUsedDoor = { x = targetDoor.x, y = targetDoor.y, cooldown = 2.0 }
        end
        
        return true
    end
    
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

    -- Check for door collision first
    for checkY = tileTop, tileBottom do
        for checkX = tileLeft, tileRight do
            local tileType = world.mapData[checkY][checkX]
            if tileType == world.DOORS then
                if world.lastUsedDoor and 
                   world.lastUsedDoor.x == checkX and 
                   world.lastUsedDoor.y == checkY and
                   world.lastUsedDoor.cooldown > 0 then
                    -- Skip this door if on cooldown
                else
                    local doorCollision = worldGenerator.getDoorCollision(world, x, y, width, height)
                    if doorCollision then
                        return {isDoor = true, doorInfo = doorCollision.doorInfo}
                    end
                end
            end
        end
    end

    -- Check for walls, blockages and platforms
    for checkY = tileTop, tileBottom do
        for checkX = tileLeft, tileRight do
            local tileType = world.mapData[checkY][checkX]
            
            if tileType == world.WALL or tileType == world.BLOCKAGE then
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

function worldGenerator.update(world, dt)
    if world.lastUsedDoor and world.lastUsedDoor.cooldown > 0 then
        world.lastUsedDoor.cooldown = world.lastUsedDoor.cooldown - dt
    end
end

-- Get tile at world position
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
    local entranceDoorColor = {0.2, 0.6, 0.8, 1}
    local exitDoorColor = {0.8, 0.4, 0.1, 1}
    -- First level door color
    local firstLevelDoorColor = {0.8, 0.8, 0.1, 1}
    -- Vertical tunnel color
    local TunnelColor = {0.5,0.5,0.5,1}
    local blockageColor = {1, 0.1, 0.1, 1}
    local platformColor = {0.3, 0.7, 0.3, 1}
    
    -- Calculate visible area
    local startY = math.floor(cameraY / world.tileSize)
    local endY = math.ceil((cameraY + love.graphics.getHeight()) / world.tileSize)
    local startX = math.floor(cameraX / world.tileSize)
    local endX = math.ceil((cameraX + love.graphics.getWidth()) / world.tileSize)
    
    -- Calculate visible area with some padding
    local padding = 2 -- Add a small buffer of tiles
    local startY = math.floor(cameraY / world.tileSize) - padding
    local endY = math.ceil((cameraY + love.graphics.getHeight()) / world.tileSize) + padding
    local startX = math.floor(cameraX / world.tileSize) - padding
    local endX = math.ceil((cameraX + love.graphics.getWidth()) / world.tileSize) + padding
    
    -- Ensure we're within map bounds
    startY = math.max(1, startY)
    endY = math.min(world.mapHeight, endY)
    startX = math.max(1, startX)
    endX = math.min(world.mapWidth, endX)
    
    -- First draw regular tiles (only visible ones)
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
            elseif tileType == world.SHACK then
                -- Only draw shacks if they're close to being visible
                local shackX = (x-1) * world.tileSize
                local shackY = (y-1) * world.tileSize - cameraY - (world.tileSize * 10)
                
                -- Check if shack is close to screen before drawing
                if shackY > -world.tileSize * 12 and 
                   shackY < love.graphics.getHeight() + world.tileSize * 2 then
                
                    -- Scale and center the shack sprite over the tile
                    local shackScale = world.tileSize * 11
                    local shackWidth = shackScale
                    
                    local centerOffset = (shackWidth / 2) - (world.tileSize / 2)
                    
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        worldGenerator.shackSprite,
                        shackX - centerOffset,
                        shackY, 
                        0,
                        shackScale / worldGenerator.shackSprite:getWidth(),
                        shackScale / worldGenerator.shackSprite:getHeight()
                    )
                end
            elseif tileType == world.DOORS then
                local doorInfo = worldGenerator.getDoorInfo(world, x, y)
                local doorColor = exitDoorColor
                
                if doorInfo then
                    if doorInfo.targetLevel == 1 then
                        doorColor = entranceDoorColor
                    elseif doorInfo.isEntrance then
                        doorColor = entranceDoorColor
                    elseif doorInfo.targetLevel > world.currentLevel then
                        doorColor = exitDoorColor
                    end
                    if doorInfo.targetLevel == 2 and world.currentLevel == 1 then
                        doorColor = firstLevelDoorColor
                    end
                end
                
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

-- Position for spawning entity
function worldGenerator.getSpawnPositionAboveTile(world, tileX, tileY)
    local worldX = (tileX - 1) * world.tileSize + (world.tileSize / 2)
    local worldY = (tileY - 1) * world.tileSize - world.tileSize
    
    return worldX, worldY
end

function worldGenerator.drawDebug(world, cameraY, cameraX)
    mapGenerator.drawDebug(world.mapData, world.tileSize, cameraY, cameraX)
end

return worldGenerator