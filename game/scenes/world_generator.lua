--TODO add per level rendering, player changing color when touching some tiles?, also add vertical tiles in front of player
local mapGenerator = require("scripts.map_generator")

local worldGenerator = {}

function worldGenerator.generateWorld(tileSize)
    tileSize = tileSize or 32
    local worldSeed = mapGenerator.newSeed()
    local mapData, mainMineX, playerStartY, levels, doorPairs = mapGenerator.generateAccessibleMine()
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
        playerStartY = playerStartWorldY
    }
    
    return world
end

-- coll
function worldGenerator.checkCollision(world, x, y, width, height)
    width = width or world.tileSize
    height = height or world.tileSize
    
    -- Calculate collision bounds using players collision box
    local left = x
    local right = x + width
    local top = y
    local bottom = y + height
    
    -- Convert to tile coordinates
    local tileLeft = math.floor(left / world.tileSize) + 1
    local tileRight = math.ceil(right / world.tileSize)
    local tileTop = math.floor(top / world.tileSize) + 1
    local tileBottom = math.ceil(bottom / world.tileSize)
    
    -- Keep track of door collision
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
                doorCollision = true
            end
        end
    end

    if doorCollision then
        return {isWall = true, isDoor = true}
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