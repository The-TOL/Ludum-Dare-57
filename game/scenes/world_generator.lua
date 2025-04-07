local mapGenerator = require("scripts.map_generator")

local worldGenerator = {
    shackSprite = love.graphics.newImage("assets/visual/shack.png")
}

function worldGenerator.generateWorld(tileSize)
    tileSize = tileSize or 32
    local worldSeed = mapGenerator.newSeed()
    local mapData, mainMineX, playerStartY, levels = mapGenerator.generateAccessibleMine()
    local playerStartWorldX = (mainMineX - 1) * tileSize + (tileSize / 2)
    local playerStartWorldY = (playerStartY - 1) * tileSize + (tileSize / 2)
    
    local world = {
        seed = worldSeed,
        mapData = mapData,
        tileSize = tileSize,
        width = mapGenerator.MAP_W * tileSize,
        height = mapGenerator.MAP_H * tileSize,
        mapWidth = mapGenerator.MAP_W,
        mapHeight = mapGenerator.MAP_H,
        levels = levels,
        WALL = mapGenerator.WALL,
        TUNNEL = mapGenerator.TUNNEL,
        BLOCKAGE = mapGenerator.BLOCKAGE,
        SHACK = mapGenerator.SHACK,
        SPAWNER = mapGenerator.SPAWNER, -- Add the spawner constant to the world
        playerStartX = playerStartWorldX,
        playerStartY = playerStartWorldY
    }
    
    -- Stay away from player start position
    local safeRadius = 200
    local spawnerCount = 0
    local attempts = 0
    local maxAttempts = 600
    
    -- Spawn 12 spawners randomly
    while spawnerCount < 12 and attempts < maxAttempts do
        attempts = attempts + 1
        
        local randX = math.random(1, world.mapWidth)
        local randY = math.random(1, world.mapHeight)
        
        if world.mapData[randY][randX] == world.TUNNEL then
            local tileX = (randX - 1) * world.tileSize + (world.tileSize / 2)
            local tileY = (randY - 1) * world.tileSize + (world.tileSize / 2)
            local distanceToPlayer = math.sqrt((tileX - playerStartWorldX)^2 + (tileY - playerStartWorldY)^2)
            
            if distanceToPlayer > safeRadius then
                world.mapData[randY][randX] = world.SPAWNER
                spawnerCount = spawnerCount + 1
            end
        end
    end
    
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
    
    for checkY = tileTop, tileBottom do
        for checkX = tileLeft, tileRight do
            if checkX < 1 or checkX > world.mapWidth or checkY < 1 or checkY > world.mapHeight then
                return true
            end
            
            if world.mapData[checkY][checkX] == world.WALL then
                return true
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
    -- Original wall drawing (keep your existing colors)
    local wallColor = {0.5, 0.5, 0.5, 1}
    
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
            elseif tileType == world.SPAWNER then
                -- Draw the spawner as a purple rectangle
                love.graphics.setColor(0.7, 0.2, 0.7, 1)
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