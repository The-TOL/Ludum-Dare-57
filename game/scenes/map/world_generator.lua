local mapGenerator = require("scenes.map.map_generator")

local worldGenerator = {}

function worldGenerator.generateWorld(tileSize)
    tileSize = tileSize or 32
    local worldSeed = mapGenerator.newSeed()
    local mapData, playerStartX, playerStartY, levels = mapGenerator.generateAccessibleMine()
    
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
        playerStartX = playerStartX,
        playerStartY = playerStartY
    }
    
    return world
end

-- Collision checking
function worldGenerator.checkCollision(world, x, y, width, height)
    local left = math.floor((x - width/2) / world.tileSize) + 1
    local right = math.ceil((x + width/2) / world.tileSize)
    local top = math.floor((y - height/2) / world.tileSize) + 1
    local bottom = math.ceil((y + height/2) / world.tileSize)
    
    for checkY = top, bottom do
        for checkX = left, right do
            if checkX < 1 or checkX > world.mapWidth or checkY < 1 or checkY > world.mapHeight then
                return false
            end
            
            local tile = world.mapData[checkY][checkX]
            if tile == world.WALL or tile == world.BLOCKAGE then
                return false
            end
        end
    end
    
    return true
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
return worldGenerator