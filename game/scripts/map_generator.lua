--TODO add platforms, blockages and level transitions

local MapGenerator = {}

-- Constants
MapGenerator.MAP_W = 1920
MapGenerator.MAP_H = 1080
MapGenerator.TUNNEL = 0
MapGenerator.WALL = 1
MapGenerator.BLOCKAGE = 2

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
            row[bx] = MapGenerator.TUNNEL
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

-- Create blockages in tunnels
function MapGenerator.createBlockageCluster(map, x, y, type)
    local minSize = MapGenerator.config.blockages.sizePercent.min
    local maxSize = MapGenerator.config.blockages.sizePercent.max
    local size = floor(MapGenerator.MAP_W * random(minSize, maxSize))
    local halfSize = floor(size / 2)
    
    if type == "vertical" then
        -- Vertical blockage
        local startY = max(1, y - halfSize)
        local endY = min(MapGenerator.MAP_H, y + halfSize)
        
        for by = startY, endY do
            map[by][x] = MapGenerator.BLOCKAGE
            
            -- Add horizontal extensions
            local hExtent = floor(MapGenerator.MAP_W * random(0.0005, 0.0015))
            for bx = max(1, x - hExtent), min(MapGenerator.MAP_W, x + hExtent) do
                if map[by][bx] == MapGenerator.TUNNEL then
                    map[by][bx] = MapGenerator.BLOCKAGE
                end
            end
        end
    else
        -- Horizontal or diagonal blockage based on random direction
        local direction = random(1, 2)
        
        if direction == 1 then
            -- Horizontal
            local startX = max(1, x - halfSize)
            local endX = min(MapGenerator.MAP_W, x + halfSize)
            
            for bx = startX, endX do
                if map[y][bx] == MapGenerator.TUNNEL then
                    map[y][bx] = MapGenerator.BLOCKAGE
                    
                    -- Extend vertically with chance
                    if random() < 0.5 and y > 1 and map[y-1][bx] == MapGenerator.TUNNEL then
                        map[y-1][bx] = MapGenerator.BLOCKAGE
                    end
                    if random() < 0.5 and y < MapGenerator.MAP_H and map[y+1][bx] == MapGenerator.TUNNEL then
                        map[y+1][bx] = MapGenerator.BLOCKAGE
                    end
                end
            end
        else 
            -- Vertical
            local startY = max(1, y - halfSize)
            local endY = min(MapGenerator.MAP_H, y + halfSize)
            
            for by = startY, endY do
                if map[by][x] == MapGenerator.TUNNEL then
                    map[by][x] = MapGenerator.BLOCKAGE
                    
                    -- Extend horizontally with chance
                    if random() < 0.5 and x > 1 and map[by][x-1] == MapGenerator.TUNNEL then
                        map[by][x-1] = MapGenerator.BLOCKAGE
                    end
                    if random() < 0.5 and x < MapGenerator.MAP_W and map[by][x+1] == MapGenerator.TUNNEL then
                        map[by][x+1] = MapGenerator.BLOCKAGE
                    end
                end
            end
        end
    end
end

-- Check if location is suitable for blockage
function MapGenerator.isSuitableBlockageLocation(map, x, y)
    local directions = {{-1,0}, {1,0}, {0,-1}, {0,1}}
    local openCount = 0
    
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir[1], y + dir[2]
        if nx >= 1 and nx <= MapGenerator.MAP_W and ny >= 1 and ny <= MapGenerator.MAP_H and
           map[ny][nx] == MapGenerator.TUNNEL then
            openCount = openCount + 1
        end
    end
    
    return openCount >= 2
end

-- Add blockages to vertical mines
function MapGenerator.addVerticalBlockages(map, branchMines, mainX)
    local liftChance = MapGenerator.config.blockages.liftChance
    
    for _, mine in ipairs(branchMines) do
        if mine.x ~= mainX and random() < liftChance then
            local blockY = random(mine.startY, mine.endY)
            MapGenerator.createBlockageCluster(map, mine.x, blockY, "vertical")
        end
    end
end

-- Add blockages to horizontal tunnels Will be changes is old code. TODO
function MapGenerator.addHorizontalBlockages(map, levels)
    local tunnelChance = MapGenerator.config.blockages.tunnelChance
    
    for _, y in ipairs(levels) do
        local x = 1
        while x <= MapGenerator.MAP_W do
            if map[y][x] == MapGenerator.TUNNEL and 
               random() < tunnelChance and
               MapGenerator.isSuitableBlockageLocation(map, x, y) then
                
                MapGenerator.createBlockageCluster(map, x, y, "horizontal")
                -- Skip ahead to avoid dense blockages
                x = x + floor(MapGenerator.MAP_W * MapGenerator.config.blockages.sizePercent.max * 2)
            end
            x = x + 1
        end
    end
end

-- Add blockages to the map
function MapGenerator.addBlockages(map, branchMines, levels, mainX)
    -- Create a copy of the map
    local blockedMap = {}
    for y = 1, MapGenerator.MAP_H do
        blockedMap[y] = {}
        for x = 1, MapGenerator.MAP_W do
            blockedMap[y][x] = map[y][x]
        end
    end
    
    -- Add blockage at enterence for gameplay
    for i = 1, #levels - 1 do
        local currentLevel = levels[i]
        local nextLevel = levels[i+1]
        
        -- Block the vertical shaft starting from just below the current level
        -- to just above the next level
        local blockStart = currentLevel + 1
        local blockEnd = nextLevel - 1
        
        for y = blockStart, blockEnd do
            blockedMap[y][mainX] = MapGenerator.BLOCKAGE
        end
        
        -- Ensure there's a navigable path by connecting horizontal tunnels
        -- with vertical passages at their ends
        if i < #levels then
            -- Add vertical passages at the ends of horizontal tunnels
            local tunnelWidth = max(2, floor(MapGenerator.MAP_W * random(
                MapGenerator.config.tunnels.widthPercent.min, 
                MapGenerator.config.tunnels.widthPercent.max
            )))
            
            -- Left side vertical passage
            local leftEnd = max(mainX - floor(MapGenerator.MAP_W * MapGenerator.config.levels.length.min), 
                             floor(MapGenerator.MAP_W * MapGenerator.config.mapMarginPercent))
            
            if random() < MapGenerator.config.tunnels.endBranchChance then
                local passageX = leftEnd + random(0, floor(tunnelWidth * 1.5))
                MapGenerator.carveVerticalMine(blockedMap, passageX, currentLevel, nextLevel)
            end
            
            -- Right side vertical passage
            local rightEnd = min(mainX + floor(MapGenerator.MAP_W * MapGenerator.config.levels.length.min),
                              MapGenerator.MAP_W - floor(MapGenerator.MAP_W * MapGenerator.config.mapMarginPercent))
            
            if random() < MapGenerator.config.tunnels.endBranchChance then
                local passageX = rightEnd - random(0, floor(tunnelWidth * 1.5))
                MapGenerator.carveVerticalMine(blockedMap, passageX, currentLevel, nextLevel)
            end
        end
    end
    
    -- Add blockages in tunnels
    MapGenerator.addVerticalBlockages(blockedMap, branchMines, mainX)
    MapGenerator.addHorizontalBlockages(blockedMap, levels) 

    return blockedMap
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
               map[ny][nx] == MapGenerator.TUNNEL and
               not visited[ny][nx] then
                visited[ny][nx] = true
                insert(queue, {x = nx, y = ny})
            end
        end
    end
    
    return false
end

-- Main function to generate the mine map
function MapGenerator.ensureConnectivity(map, levels, mainX)
    -- Check of there is a path per level
    for i = 1, #levels - 1 do
        local currentLevel = levels[i]
        local nextLevel = levels[i+1]
        
        -- Temporary map to do check
        local tempMap = {}
        for y = currentLevel, nextLevel do
            tempMap[y - currentLevel + 1] = {}
            for x = 1, MapGenerator.MAP_W do
                tempMap[y - currentLevel + 1][x] = map[y][x]
            end
        end
        
        -- Check if there is a path from the current level to the next
        local isConnected = false
        for x = 1, MapGenerator.MAP_W do
            if tempMap[1][x] == MapGenerator.TUNNEL then
                -- Try to find a path from this point on the current level 
                local queue = {{x = x, y = 1}}
                local visited = {}
                
                for y = 1, nextLevel - currentLevel + 1 do
                    visited[y] = {}
                end
                
                visited[1][x] = true
                
                while #queue > 0 do
                    local current = remove(queue, 1)
                    local cx, cy = current.x, current.y
                    
                    if cy == nextLevel - currentLevel + 1 then
                        isConnected = true
                        break
                    end
                    
                    local directions = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}}
                    for _, dir in ipairs(directions) do
                        local nx, ny = cx + dir[1], cy + dir[2]
                        
                        if nx >= 1 and nx <= MapGenerator.MAP_W and 
                           ny >= 1 and ny <= nextLevel - currentLevel + 1 and
                           tempMap[ny][nx] == MapGenerator.TUNNEL and
                           not visited[ny][nx] then
                            visited[ny][nx] = true
                            insert(queue, {x = nx, y = ny})
                        end
                    end
                end
                
                if isConnected then break end
            end
        end
        
        -- If no path found, add a random vertical connection
        if not isConnected then
            -- Find a random valid position on the horizontal tunnel
            local x = -1
            local attempts = 0
            while attempts < 10 do
                local candidate
                if random() < 0.5 then
                    -- Try left side
                    candidate = random(mainX - floor(MapGenerator.MAP_W * MapGenerator.config.levels.length.min), mainX - 1)
                else
                    -- Try right side
                    candidate = random(mainX + 1, mainX + floor(MapGenerator.MAP_W * MapGenerator.config.levels.length.min))
                end
                
                if candidate >= 1 and candidate <= MapGenerator.MAP_W and map[currentLevel][candidate] == MapGenerator.TUNNEL then
                    x = candidate
                    break
                end
                attempts = attempts + 1
            end
            
            -- If found a valid position, add a vertical passage
            if x > 0 then
                MapGenerator.carveVerticalMine(map, x, currentLevel, nextLevel)
            end
        end
    end
    
    return map
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
    
    local blockedMap = MapGenerator.addBlockages(map, branchMines, levels, mainX)
    blockedMap = MapGenerator.ensureConnectivity(blockedMap, levels, mainX)
    
    return blockedMap, levels
end

-- Set a random seed
function MapGenerator.newSeed()
    local seed = os.time() * random(100)
    math.randomseed(seed)
    return seed
end

return MapGenerator