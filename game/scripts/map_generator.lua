--TODO add platforms, blockages and level transitions also add vertical line after every horizontal line and fix background, horizontal lines can be too long 

local MapGenerator = {}

-- Constants
MapGenerator.MAP_W = 1920
MapGenerator.MAP_H = 1080
MapGenerator.TUNNEL = 0
MapGenerator.WALL = 1
MapGenerator.BLOCKAGE = 2
MapGenerator.DOORS = 4
MapGenerator.VERTICAL_TUNNEL = 5
MapGenerator.PLATFORM = 6

-- Configuration settings
-- Constants and config will be moved later
MapGenerator.config = {
    mainMine = { xPosition = 0.4, width = 0.0010 },
    levels = {
        count = {min = 4, max = 7},
        heightPercent = {min = 0.05, max = 0.2},
        length = {min = 0.10, max = 0.25}
    },
    branches = {
        chance = 0.7,
        minSpacingPercent = 0.015,
        startDepthPercent = 0.2,
        noSpawnZonePercent = 0.03,
        connectLevels = {min = 1, max = 4}
    },
    blockages = {
        liftChance = 0.15,
        tunnelChance = 0.02,
        sizePercent = {min = 0.0015, max = 0.004},
        gapFillChance = 0.7
    },
    tunnels = {
        widthPercent = {min = 0.01, max = 0.01},
        verticalPassages = {min = 2, max = 4},
        endBranchChance = 0.7
    },
    platforms = {
        spawnChance = 3,
        minLength = 2,
        maxLength = 15,
        minHeight = 1,
        maxHeight = 1,
        minVerticalGap = 3,
        minDistanceFromWall = 2
    },
    stackedPlatforms = {
        enabled = true,  
        chance = 1,  
        maxStackHeight = 3,  
        verticalGap = {
            min = 3,
            max = 5,
        },          
        horizontalOffset = {      
            min = -5,
            max = 5
        }
    },
    maxGenerationAttempts = 1,
    mapMarginPercent = 0.05,
    verticalTunnelWidthPercent = {min = 0.003, max = 0.008},
}

-- Cache
local floor, random, min, max, abs = math.floor, math.random, math.min, math.max, math.abs
local insert, remove = table.insert, table.remove

-- Generate map
function MapGenerator.generateAccessibleMine()
    local attempts = 0
    local map, levels
    local mainMineX = math.floor(MapGenerator.MAP_W * MapGenerator.config.mainMine.xPosition)
    
    -- Accessibility check And retry if fail
    repeat
        attempts = attempts + 1
        map, levels = MapGenerator.generateMine()
        local isAccessible = MapGenerator.checkAccessibility(map, levels[#levels], mainMineX)
        
        if isAccessible then
            return map, mainMineX, levels[1], levels
        end
        
        math.randomseed(os.time() * random(100))
    until attempts >= MapGenerator.config.maxGenerationAttempts
    
    return map, mainMineX, levels[1], levels
end

-- Create empty map grid
local function initializeEmptyMap()
    local map = {}
    for y = 1, MapGenerator.MAP_H do
        map[y] = {}
        local row = map[y]
        for x = 1, MapGenerator.MAP_W do
            row[x] = MapGenerator.WALL
        end
    end
    return map
end

-- Generate level positions with proper spacing
function MapGenerator.generateLevelPositions(count)
    local positions = {}
    local margin = floor(MapGenerator.MAP_H * MapGenerator.config.mapMarginPercent)
    local y = margin + random(1, 2)
    insert(positions, y)
    
    -- Calculate availablel vertical space
    local availableHeight = MapGenerator.MAP_H - (2 * margin)
    local avgSpacing = availableHeight / (count + 1)
    
    for i = 2, count do
        local minSpacing = floor(avgSpacing * 0.8)
        local maxSpacing = floor(avgSpacing * 1.2)
        local spacing = random(minSpacing, maxSpacing)
        
        y = y + spacing
        
        if y >= MapGenerator.MAP_H - margin then break end
        insert(positions, y)
    end
    
    return positions
end

-- Carve a vertical mine with reduced width
function MapGenerator.carveVerticalMine(map, x, yStart, yEnd)
    -- Use the reducd vertical tunnel width
    local mineWidth = max(2, floor(MapGenerator.MAP_W * random(
        MapGenerator.config.verticalTunnelWidthPercent.min, 
        MapGenerator.config.verticalTunnelWidthPercent.max
    )))
    
    local mapMargin = floor(MapGenerator.MAP_W * MapGenerator.config.mapMarginPercent)
    x = min(x, MapGenerator.MAP_W - mapMargin - mineWidth)
    
    -- Calculate the mine boundaries
    local halfWidth = floor(mineWidth / 2)
    local startX = max(1, x - halfWidth)
    local endX = min(MapGenerator.MAP_W, x + halfWidth)
    
    for y = yStart, min(yEnd, MapGenerator.MAP_H) do
        local row = map[y]
        for bx = startX, endX do
            row[bx] = MapGenerator.VERTICAL_TUNNEL
        end
    end
end

-- Carve a horizontal tunnel
function MapGenerator.carveHorizontalTunnel(map, startX, endX, y, width)
    for x = startX, endX do
        for w = 0, width - 1 do
            local yPos = y + w
            if yPos <= MapGenerator.MAP_H then
                map[yPos][x] = MapGenerator.TUNNEL
            end
        end
    end
end

-- Check if a tunnel overlaps with existing tunnels
function MapGenerator.checkTunnelOverlap(tunnelList, top, bottom)
    for _, tunnel in ipairs(tunnelList) do
        if top <= tunnel.bottom and bottom >= tunnel.top then
            return true
        end
    end
    return false
end

-- Try to add a branch mine
function MapGenerator.tryAddBranchMine(map, levels, levelIndex, side, mainX, branchPositions, branchMines)
    if random() >= MapGenerator.config.branches.chance then return end
    
    local currentY = levels[levelIndex]
    local mapMargin = floor(MapGenerator.MAP_W * MapGenerator.config.mapMarginPercent)
    local minSpacing = floor(MapGenerator.MAP_W * MapGenerator.config.branches.minSpacingPercent)
    local buffer = floor(MapGenerator.MAP_W * 0.0026)
    
    -- Determine position based on side
    local x
    if side == "left" then
        x = random(mapMargin, mainX - buffer)
    else
        x = random(mainX + buffer, MapGenerator.MAP_W - mapMargin)
    end
    
    if map[currentY][x] ~= MapGenerator.TUNNEL then return end
    
    -- Check spacing with existing branches
    for _, pos in ipairs(branchPositions) do
        if abs(pos - x) < minSpacing then return end
    end
    
    -- Connect to a level further below
    local minConnect = MapGenerator.config.branches.connectLevels.min
    local maxConnect = min(MapGenerator.config.branches.connectLevels.max, #levels - levelIndex)
    local connectLevels = random(minConnect, max(minConnect, maxConnect))
    
    local endLevelIndex = levelIndex + connectLevels
    local endY = levels[endLevelIndex]
    
    -- Carve and record
    MapGenerator.carveVerticalMine(map, x, currentY, endY)
    insert(branchPositions, x)
    insert(branchMines, {x = x, startY = currentY, endY = endY})
end

-- Add branch mines to the map
function MapGenerator.addBranchMines(map, levels, mainX)
    local branchPositions = {}
    local branchMines = {}
    
    local totalDepth = levels[#levels] - levels[1]
    local minBranchDepth = levels[1] + floor(totalDepth * MapGenerator.config.branches.startDepthPercent)
    
    -- Calculate height for branches
    local noBranchZoneHeight = floor(MapGenerator.MAP_H * MapGenerator.config.branches.noSpawnZonePercent)
    
    for i = 1, #levels - 1 do
        -- Only add branches after certain height
        if levels[i] >= minBranchDepth and levels[i] > noBranchZoneHeight then
            MapGenerator.tryAddBranchMine(map, levels, i, "left", mainX, branchPositions, branchMines)
            MapGenerator.tryAddBranchMine(map, levels, i, "right", mainX, branchPositions, branchMines)
        end
    end
    
    return branchMines
end

-- Check if it is possible to go the deepest level WIll be changes when end goal is discussed
function MapGenerator.checkAccessibility(map, targetY, startX)
    local queue = {{x = startX, y = 1}}
    local visited = {}
    
    for y = 1, MapGenerator.MAP_H do
        visited[y] = {}
    end
    
    visited[1][startX] = true
    
    while #queue > 0 do
        local current = remove(queue, 1)
        local x, y = current.x, current.y
        
        if y == targetY then return true end
        
        local directions = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}}
        for _, dir in ipairs(directions) do
            local nx, ny = x + dir[1], y + dir[2]
            
            if nx >= 1 and nx <= MapGenerator.MAP_W and 
               ny >= 1 and ny <= MapGenerator.MAP_H and
               (map[ny][nx] == MapGenerator.TUNNEL or map[ny][nx] == MapGenerator.VERTICAL_TUNNEL or map[ny][nx] == MapGenerator.PLATFORM) and
               not visited[ny][nx] then
                visited[ny][nx] = true
                insert(queue, {x = nx, y = ny})
            end
        end
    end
    
    return false
end

function MapGenerator.addVerticalDoors(map, levels, branchMines)
    local doorCount = 0
    local doorLength = 5

    -- Process each vertical mine
    for _, mine in ipairs(branchMines) do
        local x = mine.x

        -- Find intersections
        for _, levelY in ipairs(levels) do
            -- Check if level intersects with the vertical mine
            if levelY >= mine.startY and levelY <= mine.endY then
                local isTunnelAbove = levelY > 1 and (map[levelY-1][x] == MapGenerator.TUNNEL or map[levelY-1][x] == MapGenerator.VERTICAL_TUNNEL)
                local isTunnelBelow = levelY < MapGenerator.MAP_H and (map[levelY+1][x] == MapGenerator.TUNNEL or map[levelY+1][x] == MapGenerator.VERTICAL_TUNNEL)

                if isTunnelAbove and isTunnelBelow then
                    -- Find door start and end points
                    local halfDoor = math.floor(doorLength / 2)
                    local doorStart = math.max(1, x - halfDoor)
                    local doorEnd = math.min(MapGenerator.MAP_W, x + halfDoor)

                    -- Place door above the horizontal tunnel
                    for doorX = doorStart, doorEnd do
                        if map[levelY-1][doorX] == MapGenerator.TUNNEL or map[levelY-1][doorX] == MapGenerator.VERTICAL_TUNNEL then
                            map[levelY-1][doorX] = MapGenerator.DOORS
                            doorCount = doorCount + 1
                        end
                    end

                    -- Calculate end of the horizontal tunnel from config
                    local tunnelWidth = math.max(2, math.floor(MapGenerator.MAP_W * MapGenerator.config.tunnels.widthPercent.min))
                    local horizontalEndY = levelY + tunnelWidth - 1
                    local yBelow = horizontalEndY + 1

                    -- Place door below the horizontal tunnel if vertical mine continues
                    if yBelow <= MapGenerator.MAP_H and (map[yBelow][x] == MapGenerator.TUNNEL or map[yBelow][x] == MapGenerator.VERTICAL_TUNNEL) then
                        for doorX = doorStart, doorEnd do
                            if map[yBelow][doorX] == MapGenerator.TUNNEL or map[yBelow][doorX] == MapGenerator.VERTICAL_TUNNEL then
                                map[yBelow][doorX] = MapGenerator.DOORS
                                doorCount = doorCount + 1
                            end
                        end
                    end
                end
            end
        end

        -- Generate doors at the top of the vertical line with offset
        if map[mine.startY][x] == MapGenerator.TUNNEL or map[mine.startY][x] == MapGenerator.VERTICAL_TUNNEL then
            local halfDoor = math.floor(doorLength / 2)
            local doorStart = math.max(1, x - halfDoor)
            local doorEnd = math.min(MapGenerator.MAP_W, x + halfDoor)

            for doorX = doorStart, doorEnd do
                -- Offset top door by 3 tiles
                if map[mine.startY + 3][doorX] == MapGenerator.TUNNEL or map[mine.startY + 3][doorX] == MapGenerator.VERTICAL_TUNNEL then
                    map[mine.startY + 3][doorX] = MapGenerator.DOORS
                    doorCount = doorCount + 1
                end
            end
        end
    end

    return map
end

function MapGenerator.addJumpPlatforms(map, horizontalTunnels)
    local platformCount = 0
    local config = MapGenerator.config.platforms
    local stackedConfig = MapGenerator.config.stackedPlatforms
    
    for _, tunnel in ipairs(horizontalTunnels) do
        local tunnelLength = tunnel.right - tunnel.left
        local tunnelHeight = tunnel.bottom - tunnel.top + 1
        
        -- Only add platforms in tunnels that are high enough
        if tunnelHeight >= config.minVerticalGap + config.maxHeight + 1 then
            -- Random platforms
            local x = tunnel.left + config.minDistanceFromWall
            
            while x < tunnel.right - config.minDistanceFromWall do
                -- Randomly decide whether to place a platform here
                if random() <= config.spawnChance then
                    local platformLength = random(config.minLength, config.maxLength)
                    local platformHeight = random(config.minHeight, config.maxHeight)
                    
                    -- Make sure platform fits
                    if x + platformLength < tunnel.right - config.minDistanceFromWall then
                        -- Choose a random height for the platform
                        local platformY = random(
                            tunnel.top + config.minVerticalGap,
                            tunnel.bottom - platformHeight 
                        )
                        
                        -- Check if there's enough space
                        for checkY = platformY - config.minVerticalGap, platformY - 1 do
                            for checkX = x, x + platformLength do
                                if checkY >= 1 and map[checkY][checkX] ~= MapGenerator.TUNNEL then
                                    hasSpace = false
                                    break
                                end
                            end
                            if not hasSpace then break end
                        end
                        
                        -- Place the platform
                        if hasSpace then
                            for py = platformY, platformY + platformHeight - 1 do
                                for px = x, x + platformLength do
                                    if py <= MapGenerator.MAP_H and map[py][px] == MapGenerator.TUNNEL then
                                        map[py][px] = MapGenerator.PLATFORM
                                        platformCount = platformCount + 1
                                    end
                                end
                            end
                            
                            -- Try to add stacked platforms
                            if stackedConfig.enabled and random() <= stackedConfig.chance then
                                local stackSize = random(1, stackedConfig.maxStackHeight - 1)  -- -1 because we already placed one
                                local currentY = platformY
                                
                                for stack = 1, stackSize do
                                    -- position for the next platform in the stack
                                    currentY = currentY - random(
                                        stackedConfig.verticalGap.min,
                                        stackedConfig.verticalGap.max
                                    ) - platformHeight
                                    
                                    -- Apply random horozontal offset   
                                    local offsetX = random(
                                        stackedConfig.horizontalOffset.min,
                                        stackedConfig.horizontalOffset.max
                                    )
                                    local stackX = math.max(tunnel.left + config.minDistanceFromWall, 
                                                     math.min(x + offsetX, tunnel.right - config.minDistanceFromWall - platformLength))
                                    
                                    -- Check if we have enough space for this stacked platform
                                    if currentY >= tunnel.top + config.minVerticalGap then
                                        -- Check for space above for jumping
                                        local hasStackSpace = true
                                        for checkY = currentY - config.minVerticalGap, currentY - 1 do
                                            for checkX = stackX, stackX + platformLength do
                                                if checkY >= 1 and map[checkY][checkX] ~= MapGenerator.TUNNEL then
                                                    hasStackSpace = false
                                                    break
                                                end
                                            end
                                            if not hasStackSpace then break end
                                        end
                                        
                                        -- Place stacked platform
                                        if hasStackSpace then
                                            for py = currentY, currentY + platformHeight - 1 do
                                                for px = stackX, stackX + platformLength do
                                                    if py >= 1 and py <= MapGenerator.MAP_H and map[py][px] == MapGenerator.TUNNEL then
                                                        map[py][px] = MapGenerator.PLATFORM
                                                        platformCount = platformCount + 1
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                    else
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Move to next potential platform position with some spacing
                    x = x + platformLength + random(5, 10)
                else
                    -- Skip some space if not placing a platform
                    x = x + random(3, 8)
                end
            end
        end
    end
    
    return map, platformCount
end

function MapGenerator.generateMine()
    local map = initializeEmptyMap()
    
    -- Generate levels and main tunnel
    local levelCount = random(MapGenerator.config.levels.count.min, MapGenerator.config.levels.count.max)
    local levels = MapGenerator.generateLevelPositions(levelCount)
    local mainX = math.floor(MapGenerator.MAP_W * MapGenerator.config.mainMine.xPosition)
    local mapMargin = floor(MapGenerator.MAP_W * MapGenerator.config.mapMarginPercent)
    
    -- Carve main vertical tunnel
    MapGenerator.carveVerticalMine(map, mainX, 1, MapGenerator.MAP_H)
    
    -- Track branches and tunnels
    local branchMines = {{x = mainX, startY = 1, endY = MapGenerator.MAP_H}}
    local horizontalTunnels = {}
    
    -- Create horizontal levels
    for i, y in ipairs(levels) do
        -- Calculate tunnel properties
        local tunnelWidth = max(2, floor(MapGenerator.MAP_W * random(
            MapGenerator.config.tunnels.widthPercent.min, 
            MapGenerator.config.tunnels.widthPercent.max
        )))
        
        -- Define tunnel bounds
        local tunnelTop = y
        local tunnelBottom = y + tunnelWidth - 1
        
        -- Check for tunnel overlap
        if not MapGenerator.checkTunnelOverlap(horizontalTunnels, tunnelTop, tunnelBottom) then
            -- Procces left side
            local leftLength = floor(MapGenerator.MAP_W * random(
                MapGenerator.config.levels.length.min, 
                MapGenerator.config.levels.length.max
            ))
            local leftEnd = max(mainX - leftLength, mapMargin)
            
            insert(horizontalTunnels, {
                top = tunnelTop,
                bottom = tunnelBottom,
                left = leftEnd,
                right = mainX
            })
            
            MapGenerator.carveHorizontalTunnel(map, leftEnd, mainX, y, tunnelWidth)
            
            -- Procces right side
            local rightLength = floor(MapGenerator.MAP_W * random(
                MapGenerator.config.levels.length.min, 
                MapGenerator.config.levels.length.max
            ))
            local rightEnd = min(mainX + rightLength, MapGenerator.MAP_W - mapMargin)
            
            insert(horizontalTunnels, {
                top = tunnelTop,
                bottom = tunnelBottom,
                left = mainX,
                right = rightEnd
            })
            
            MapGenerator.carveHorizontalTunnel(map, mainX, rightEnd, y, tunnelWidth)
        end
    end
    
    local newBranchMines = MapGenerator.addBranchMines(map, levels, mainX)
    for _, mine in ipairs(newBranchMines) do
        insert(branchMines, mine)
    end
    
    --Call Extra generation functions
    map, platformCount = MapGenerator.addJumpPlatforms(map, horizontalTunnels)
    map = MapGenerator.addVerticalDoors(map, levels, branchMines)
    
    return map, levels
end
-- Set a random seed
function MapGenerator.newSeed()
    local seed = os.time() * random(100)
    math.randomseed(seed)
    return seed
end

return MapGenerator