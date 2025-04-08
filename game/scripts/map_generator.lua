local MapGenerator = {}

-- Constants
MapGenerator.MAP_W = 1920
MapGenerator.MAP_H = 1080
MapGenerator.TUNNEL = 0
MapGenerator.WALL = 1
MapGenerator.BLOCKAGE = 2
MapGenerator.SHACK = 3
MapGenerator.SPAWNER = 4  -- New tile type for entity spawning
MapGenerator.VERTICAL_TUNNEL = 5
MapGenerator.PLATFORM = 6
MapGenerator.DOORS = 7

-- Config settings
MapGenerator.config = {
    mainMine = { xPosition = 0.4, width = 0.0010 },
    shacks = {  
        size = {width = 20, height = 16} -- Increased from 5x4 to 20x16
    },
    levels = {
        count = {min = 8, max = 10}, 
        heightPercent = {min = 0.05, max = 0.2},
        length = {min = 0.1, max = 0.2}
    },
    branches = {
        chance = 0.7,
        minSpacingPercent = 0.0005,
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
        verticalPassages = {min = 4, max = 6},
        endBranchChance = 1
    },
    platforms = {
        spawnChance = 5,
        minLength = 5,
        maxLength = 15,
        minHeight = 1,
        maxHeight = 1,
        minVerticalGap = 3,
        minDistanceFromWall = 0
    },
    stackedPlatforms = {
        enabled = true,  
        chance = 200,  
        maxStackHeight = 4,  
        verticalGap = {
            min = 2,
            max = 4,
        },          
        horizontalOffset = {      
            min = -2,
            max = 2
        }
    },
    doors = {
        spawnChance = 1.0,
        positionRange = {
            minDistancePercent = 0.5,
            maxDistancePercent = 1,
        },
        width = 3,
        height = 6,
        enforcePairs = true,
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
    local map, levels, levelTunnels, doorPositions
    local mainMineX = math.floor(MapGenerator.MAP_W * MapGenerator.config.mainMine.xPosition)
    
    -- Accessibility check and retry if fail
    repeat
        attempts = attempts + 1
        map, levels, levelTunnels, doorPositions = MapGenerator.generateMine()
        local isAccessible = MapGenerator.checkAccessibility(map, levels[#levels], mainMineX)
        
        if isAccessible then
            if MapGenerator.config.debug and MapGenerator.config.debug.enabled then
                MapGenerator.verifyLevelIntegrity(levels, levelTunnels)
            end
            
            return map, mainMineX, levels[1], levels, levelTunnels, doorPositions
        end
        
        math.randomseed(os.time() * random(100))
    until attempts >= MapGenerator.config.maxGenerationAttempts
    
    return map, mainMineX, levels[1], levels, levelTunnels, doorPositions
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
        local minSpacing = floor(avgSpacing * 0.4)
        local maxSpacing = floor(avgSpacing * 0.4)        
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
function MapGenerator.carveHorizontalTunnel(map, startX, endX, y, width, levelIndex)
    for x = startX, endX do
        for w = 0, width - 1 do
            local yPos = y + w
            if yPos <= MapGenerator.MAP_H then
                map[yPos][x] = MapGenerator.TUNNEL
            end
        end
    end
    
    -- Add shacks
    if levelIndex == 1 or levelIndex % 2 == 1 then
        local groundX = random(startX, endX)
        local groundY = y + width - 1
        if groundY <= MapGenerator.MAP_H then
            map[groundY][groundX] = MapGenerator.SHACK
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

function MapGenerator.addVerticalBlockages(map, levels, branchMines)
    local blockageCount = 0
    local blockageLength = 5

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
                    -- Find blockage start and end points
                    local halfBlockage = math.floor(blockageLength / 2)
                    local blockageStart = math.max(1, x - halfBlockage)
                    local blockageEnd = math.min(MapGenerator.MAP_W, x + halfBlockage)

                    -- Place blockage above the horizontal tunnel
                    for blockageX = blockageStart, blockageEnd do
                        if map[levelY-1][blockageX] == MapGenerator.TUNNEL or map[levelY-1][blockageX] == MapGenerator.VERTICAL_TUNNEL then
                            map[levelY-1][blockageX] = MapGenerator.BLOCKAGE
                            blockageCount = blockageCount + 1
                        end
                    end

                    -- Calculate end of the horizontal tunnel from config
                    local tunnelWidth = math.max(2, math.floor(MapGenerator.MAP_W * MapGenerator.config.tunnels.widthPercent.min))
                    local horizontalEndY = levelY + tunnelWidth - 1
                    local yBelow = horizontalEndY + 1

                    -- Place blockage below the horizontal tunnel if vertical mine continues
                    if yBelow <= MapGenerator.MAP_H and (map[yBelow][x] == MapGenerator.TUNNEL or map[yBelow][x] == MapGenerator.VERTICAL_TUNNEL) then
                        for blockageX = blockageStart, blockageEnd do
                            if map[yBelow][blockageX] == MapGenerator.TUNNEL or map[yBelow][blockageX] == MapGenerator.VERTICAL_TUNNEL then
                                map[yBelow][blockageX] = MapGenerator.BLOCKAGE
                                blockageCount = blockageCount + 1
                            end
                        end
                    end
                end
            end
        end

        -- Generate blockages at the top of the vertical line with offset
        if map[mine.startY][x] == MapGenerator.TUNNEL or map[mine.startY][x] == MapGenerator.VERTICAL_TUNNEL then
            local halfBlockage = math.floor(blockageLength / 2)
            local blockageStart = math.max(1, x - halfBlockage)
            local blockageEnd = math.min(MapGenerator.MAP_W, x + halfBlockage)

            for blockageX = blockageStart, blockageEnd do
                -- Offset top blockage by 3 tiles
                if map[mine.startY + 3][blockageX] == MapGenerator.TUNNEL or map[mine.startY + 3][blockageX] == MapGenerator.VERTICAL_TUNNEL then
                    map[mine.startY + 3][blockageX] = MapGenerator.BLOCKAGE
                    blockageCount = blockageCount + 1
                end
            end
        end
    end

    return map
end

function MapGenerator.addJumpPlatforms(map, levelTunnels)
    local platformCount = 0
    local config = MapGenerator.config.platforms
    local stackConfig = MapGenerator.config.stackedPlatforms
    
    -- Create a buffer zone
    local placedPlatforms = {}
    local bufferRadius = 2
    
    -- Progressive probability
    local baseSpawnChance = config.spawnChance / 10
    local maxSpawnChance = 0.9
    local chanceIncrement = 0.05
    local currentSpawnChance = baseSpawnChance
    local attemptsSinceLastPlatform = 0
    
    -- Check if a position conflicts
    local function checkBufferZone(x, y, length, height)
        -- Check the whole platform
        for py = y - bufferRadius, y + height - 1 + bufferRadius do
            for px = x - bufferRadius, x + length - 1 + bufferRadius do
                if px < 1 or px > MapGenerator.MAP_W or py < 1 or py > MapGenerator.MAP_H then
                    goto continue
                end
                
                -- Check if this position is within buffer of any existing platform
                for _, platform in ipairs(placedPlatforms) do
                    if px >= platform.x - bufferRadius and px <= platform.x + platform.length - 1 + bufferRadius and
                       py >= platform.y - bufferRadius and py <= platform.y + platform.height - 1 + bufferRadius then
                        return false
                    end
                end
                
                ::continue::
            end
        end
        return true
    end
    
    -- Check if a platform can be placed
    local function canPlacePlatform(x, y, length, height)
        for py = y, y + height - 1 do
            for px = x, x + length - 1 do
                if px > MapGenerator.MAP_W or py > MapGenerator.MAP_H or 
                   map[py][px] ~= MapGenerator.TUNNEL then
                    return false
                end
            end
        end
        return checkBufferZone(x, y, length, height)
    end
    
    -- Place a platform
    local function placePlatform(x, y, length, height)
        for py = y, y + height - 1 do
            for px = x, x + length - 1 do
                map[py][px] = MapGenerator.PLATFORM
            end
        end
        
        -- Track the placed platform
        table.insert(placedPlatforms, {
            x = x,
            y = y,
            length = length,
            height = height
        })
        
        -- Reset the progressive probability
        currentSpawnChance = baseSpawnChance
        attemptsSinceLastPlatform = 0
        
        return length * height
    end
    
    -- Process each tunnel in each level
    for _, level in ipairs(levelTunnels) do
        for _, tunnel in pairs({level.left, level.right}) do
            -- Skip tunnels that are too short
            local tunnelWidth = tunnel.right - tunnel.left
            if tunnelWidth < config.minLength + 2 * config.minDistanceFromWall then
                goto continue
            end
            
            local tunnelHeight = tunnel.bottom - tunnel.top
            local possibleRows = {}
            
            -- Create fixed rows
            local firstRow = tunnel.top + math.floor(tunnelHeight * 0.25)
            local secondRow = tunnel.top + math.floor(tunnelHeight * 0.5)
            local thirdRow = tunnel.top + math.floor(tunnelHeight * 0.75)
            
            if firstRow >= tunnel.top + config.minVerticalGap then
                table.insert(possibleRows, firstRow)
            end
            if secondRow >= tunnel.top + config.minVerticalGap and
               secondRow >= firstRow + config.minVerticalGap then
                table.insert(possibleRows, secondRow)
            end
            if thirdRow >= tunnel.top + config.minVerticalGap and
               thirdRow >= secondRow + config.minVerticalGap then
                table.insert(possibleRows, thirdRow)
            end
            
            if #possibleRows == 0 then
                goto continue
            end
            
            -- Attempt to place platforms
            local attempts = math.floor(tunnelWidth / 4)
            for _ = 1, attempts do
                -- Use progressive probability
                if random() <= currentSpawnChance then
                    -- Random position within tunnel
                    local x = random(tunnel.left + config.minDistanceFromWall, 
                                     tunnel.right - config.minDistanceFromWall - config.minLength)
                                     
                    local length = random(config.minLength, math.min(config.maxLength, tunnel.right - x))
                    local height = random(config.minHeight, config.maxHeight)
                    
                    -- Choose a row
                    local rowIndex = random(1, #possibleRows)
                    local y = possibleRows[rowIndex]
                    
                    -- Place platform if space is available                    
                    if canPlacePlatform(x, y, length, height) then
                        platformCount = platformCount + placePlatform(x, y, length, height)
                        
                        -- Try to place stacked platforms
                        if stackConfig.enabled and random() <= stackConfig.chance then
                            local stackHeight = random(1, stackConfig.maxStackHeight - 1)
                            local currentY = y
                            
                            for _ = 1, stackHeight do
                                -- Use fixed vertical gaps for stacked platforms
                                local verticalGap = random(stackConfig.verticalGap.min, stackConfig.verticalGap.max)
                                currentY = currentY - verticalGap - height
                                
                                -- Calculate horizontal offset
                                local offsetX = random(stackConfig.horizontalOffset.min, stackConfig.horizontalOffset.max)
                                
                                -- If offset is too small, push it to minimum separation
                                if math.abs(offsetX) < bufferRadius then
                                    offsetX = offsetX < 0 and -bufferRadius or bufferRadius
                                end
                                
                                local stackX = math.max(x + offsetX, tunnel.left + config.minDistanceFromWall)
                                stackX = math.min(stackX, tunnel.right - config.minDistanceFromWall - length)
                                
                                -- Place stack if there's space
                                if currentY > tunnel.top and canPlacePlatform(stackX, currentY, length, height) then
                                    platformCount = platformCount + placePlatform(stackX, currentY, length, height)
                                else
                                    break
                                end
                            end
                        end
                    else
                        attemptsSinceLastPlatform = attemptsSinceLastPlatform + 5
                    end
                else
                    attemptsSinceLastPlatform = attemptsSinceLastPlatform + 2
                    currentSpawnChance = math.min(maxSpawnChance, baseSpawnChance + (attemptsSinceLastPlatform * chanceIncrement))
                end
            end
            ::continue::
        end
    end
    
    return map, platformCount
end

function MapGenerator.addDoorsToLevels(map, levelTunnels, mainX)
    local doorPositions = {}
    
    for i=1, #levelTunnels do
        doorPositions[i] = {left = nil, right = nil}
    end
    
    -- Process each level
    for levelIndex, level in ipairs(levelTunnels) do
        local isFirstLevel = (levelIndex == 1)
        local isLastLevel = (levelIndex == #levelTunnels)
        
        -- For first and last levels, place exactly one door
        if isFirstLevel then
            -- Choose left or right tunnel randomly
            local side = random(1, 2) -- 1 = left, 2 = right
            local tunnel = (side == 1) and level.left or level.right
            local sideName = (side == 1) and "left" or "right"
            
            -- Calculate valid position range along the tunnel
            local minX = tunnel.left + 2
            local maxX = tunnel.right - MapGenerator.config.doors.width - 2
            
            -- Make sure there's enough space
            if maxX > minX then
                -- Pick a random position for the door
                local doorX = random(minX, maxX)
                local doorY = tunnel.bottom - MapGenerator.config.doors.height + 1
                
                -- Place the door
                for y = doorY, tunnel.bottom do
                    for x = doorX, doorX + MapGenerator.config.doors.width - 1 do
                        if map[y][x] == MapGenerator.TUNNEL then
                            map[y][x] = MapGenerator.DOORS
                        end
                    end
                end
                
                -- Store door position
                doorPositions[levelIndex][sideName] = {x = doorX, y = doorY, width = MapGenerator.config.doors.width, height = MapGenerator.config.doors.height}
            end
        else
            -- Make pairs for all other levels
            if level.left then
                local minX = level.left.left + 2
                local maxX = level.left.right - MapGenerator.config.doors.width - 2
                
                if maxX > minX then
                    local doorX = random(minX, maxX)
                    local doorY = level.left.bottom - MapGenerator.config.doors.height + 1
                    
                    for y = doorY, level.left.bottom do
                        for x = doorX, doorX + MapGenerator.config.doors.width - 1 do
                            if map[y][x] == MapGenerator.TUNNEL then
                                map[y][x] = MapGenerator.DOORS
                            end
                        end
                    end
                    
                    doorPositions[levelIndex]["left"] = {x = doorX, y = doorY, width = MapGenerator.config.doors.width, height = MapGenerator.config.doors.height}
                end
            end
            
            if level.right and not isLastLevel then
                local minX = level.right.left + 2
                local maxX = level.right.right - MapGenerator.config.doors.width - 2
                
                if maxX > minX then
                    local doorX = random(minX, maxX)
                    local doorY = level.right.bottom - MapGenerator.config.doors.height + 1
                    
                    for y = doorY, level.right.bottom do
                        for x = doorX, doorX + MapGenerator.config.doors.width - 1 do
                            if map[y][x] == MapGenerator.TUNNEL then
                                map[y][x] = MapGenerator.DOORS
                            end
                        end
                    end
                    
                    doorPositions[levelIndex]["right"] = {x = doorX, y = doorY, width = MapGenerator.config.doors.width, height = MapGenerator.config.doors.height}
                end
            end
        end
    end
    
    return map, #doorPositions, doorPositions
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
    local levelTunnels = {} 
    
    -- Create horizontal levels
    local levelTunnels = {} 
    for i, y in ipairs(levels) do
        -- Calculate tunnel properties
        local tunnelWidth = max(2, floor(MapGenerator.MAP_W * random(
            MapGenerator.config.tunnels.widthPercent.min, 
            MapGenerator.config.tunnels.widthPercent.max
        )))
        
        -- Define tunnel bounds
        local tunnelTop = y
        local tunnelBottom = y + tunnelWidth - 1
        
        -- Create an entry for this level's tunnels
        levelTunnels[i] = {}
        
        -- Procces left side
            local leftLength = floor(MapGenerator.MAP_W * random(
            MapGenerator.config.levels.length.min, 
            MapGenerator.config.levels.length.max
        ))
        local leftEnd = max(mainX - leftLength, mapMargin)
        
        levelTunnels[i].left = {
            top = tunnelTop,
            bottom = tunnelBottom,
            left = leftEnd,
            right = mainX
        }
        
        MapGenerator.carveHorizontalTunnel(map, leftEnd, mainX, y, tunnelWidth, i)
        
        -- Procces right side

            local rightLength = floor(MapGenerator.MAP_W * random(
            MapGenerator.config.levels.length.min, 
            MapGenerator.config.levels.length.max
        ))
        local rightEnd = min(mainX + rightLength, MapGenerator.MAP_W - mapMargin)
        
        levelTunnels[i].right = {
            top = tunnelTop,
            bottom = tunnelBottom,
            left = mainX,
            right = rightEnd
        }
        
        MapGenerator.carveHorizontalTunnel(map, mainX, rightEnd, y, tunnelWidth, i)
    end
    
    MapGenerator.carveVerticalMine(map, mainX, 1, MapGenerator.MAP_H)
    
    local branchMines = {{x = mainX, startY = 1, endY = MapGenerator.MAP_H}}
    
    local newBranchMines = MapGenerator.addBranchMines(map, levels, mainX)
    for _, mine in ipairs(newBranchMines) do
        insert(branchMines, mine)
    end
    
    --Call Extra generation functions
    map, platformCount = MapGenerator.addJumpPlatforms(map, levelTunnels)
    map = MapGenerator.addVerticalBlockages(map, levels, branchMines)  
    map, doorCount, doorPositions = MapGenerator.addDoorsToLevels(map, levelTunnels, mainX)
                       
    return map, levels, levelTunnels, doorPositions
end

function MapGenerator.getCurrentLevel(playerY, levels)
    for i, levelY in ipairs(levels) do
        if playerY <= levelY then
            return i
        end
    end
    return #levels
end

-- Set a random seed
function MapGenerator.newSeed()
    local seed = os.time() * random(100)
    math.randomseed(seed)
    return seed
end

return MapGenerator