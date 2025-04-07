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

-- Check if player is colliding with a door and determine which door
function worldGenerator.getDoorCollision(world, x, y, width, height)
    -- Convert to tile coordinates
    local tileX = math.floor(x / world.tileSize) + 1
    local tileY = math.floor(y / world.tileSize) + 1
    -- First check if were on a door tile
    if tileX >= 1 and tileX <= world.mapWidth and tileY >= 1 and tileY <= world.mapHeight then
        if world.mapData[tileY][tileX] == world.DOORS then
            -- Find which level we're on
            local currentLevel = mapGenerator.getCurrentLevel(tileY, world.levels)
            
            -- Find which side of the level this door is on (left or right)
            local doorSide = "unknown"
            local doorInfo = nil
            if currentLevel and world.levelData[currentLevel] and world.levelData[currentLevel].doors then
                -- Check left door
                if world.levelData[currentLevel].doors.left then
                    print("left")
                    local door = world.levelData[currentLevel].doors.left
                    if tileX >= door.x and tileX < door.x + door.width and
                       tileY >= door.y and tileY < door.y + door.height then
                        doorSide = "left"
                        doorInfo = door
                    end
                end
                
                -- Check right door
                if doorSide == "unknown" and world.levelData[currentLevel].doors.right then
                    print("right")
                    local door = world.levelData[currentLevel].doors.right
                    if tileX >= door.x and tileX < door.x + door.width and
                       tileY >= door.y and tileY < door.y + door.height then
                        doorSide = "right"
                        doorInfo = door
                    end
                end
            end
            
            return {
                isDoor = true,
                level = currentLevel,
                side = doorSide,
                doorInfo = doorInfo
            }
        end
    end
    
    return false
end

-- Function to teleport player to a door on another level
function worldGenerator.teleportThroughDoor(world, player, doorCollision)
    -- Can only teleport if we have valid door information
    if not doorCollision or not doorCollision.isDoor or doorCollision.side == "unknown" then
        return false
    end
    print("trying teleport")
    
    local currentLevel = doorCollision.level
    local currentSide = doorCollision.side

    print(currentLevel)
    print(currentSide)
    
    -- Determine target level (typically the level below)
    local targetLevel = currentLevel + 1
    
    -- If we're at the bottom level, teleport to the top level
    if targetLevel > #world.levels then
        targetLevel = 1
    end
    
    -- Check if target level has a door on the same side
    if world.levelData[targetLevel] and 
       world.levelData[targetLevel].doors and 
       world.levelData[targetLevel].doors[currentSide] then
        
        local targetDoor = world.levelData[targetLevel].doors[currentSide]
        
        -- Calculate target position (center of door)
        local targetX = (targetDoor.x + targetDoor.width / 2 - 1) * world.tileSize
        local targetY = (targetDoor.y + targetDoor.height / 2) * world.tileSize
        
        -- Teleport player
        player.x = targetX
        player.y = targetY
        
        -- Add a teleport effect or sound if desired
        -- if player.playSound then player:playSound("teleport") end
        
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
    
    -- Door collision info
    local doorCollision = nil
    
    -- Check for wall collision
    for checkY = tileTop, tileBottom do
        for checkX = tileLeft, tileRight do
            if checkX < 1 or checkX > world.mapWidth or checkY < 1 or checkY > world.mapHeight then
                return {isWall = true}
            end
            
            local tileType = world.mapData[checkY][checkX]
            if tileType == world.WALL then
                return {isWall = true}
            elseif tileType == world.DOORS then
                doorCollision = worldGenerator.getDoorCollision(world, x, y, width, height)
            end
        end
    end
    
    -- If we found a door, return door collision data
    if doorCollision then
        return doorCollision
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
    local verticalTunnelColor = {0.3, 0.3, 0.3, 1}
    local blockageColor = {1, 0.1, 0.1, 1}
    local platformColor = {0.3, 0.7, 0.3, 1}
    
    -- Hitbox color for doors
    local doorHitboxColor = {1, 0, 0, 1} -- Red color
    
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
                -- Draw hitbox for doors
                love.graphics.setColor(doorHitboxColor)
                love.graphics.rectangle(
                    "line", 
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
                love.graphics.setColor(blockageColor)
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