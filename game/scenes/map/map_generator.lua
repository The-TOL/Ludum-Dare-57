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
        count = {min = 3, max = 5},
        heightPercent = {min = 0.05, max = 0.15},
        length = {min = 0.15, max = 0.35}
    },
    branches = {
        chance = 0.5,
        minSpacingPercent = 0.02, 
        startDepthPercent = 0.4,
        noSpawnZonePercent = 0.05,
        connectLevels = {min = 1, max = 3}
    },
    blockages = {
        liftChance = 0.2,
        tunnelChance = 0.01,
        sizePercent = {min = 0.0015, max = 0.004},
        gapFillChance = 0.85
    },
    tunnels = {
        widthPercent = {min = 0.0125, max = 0.015},
        verticalPassages = {min = 1, max = 3}
    },
    maxGenerationAttempts = 5,
    mapMarginPercent = 0.05,
    verticalTunnelWidthPercent = {min = 0.004, max = 0.005}
}

-- Cache
local floor, random, min, max, abs = math.floor, math.random, math.min, math.max, math.abs
local insert, remove = table.insert, table.remove

-- Generate map
function MapGenerator.generateAccessibleMine()
    local attempts = 0
    local map, levels
    local mainMineX = floor(MapGenerator.MAP_W * MapGenerator.config.mainMine.xPosition)
    
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

-- Try to fill small gaps between blockades WILL BE CHANGED
function MapGenerator.fillBlockageGaps(map)
    -- Iterate through the map and find small gaps between blockades
    for y = 1, MapGenerator.MAP_H do
        for x = 2, MapGenerator.MAP_W - 1 do
            -- Check for horizontal gaps
            if map[y][x] == MapGenerator.TUNNEL then
                -- Check left and right for blockages
                if (map[y][x-1] == MapGenerator.BLOCKAGE and map[y][x+1] == MapGenerator.BLOCKAGE) then
                    if random() < MapGenerator.config.blockages.gapFillChance then
                        map[y][x] = MapGenerator.BLOCKAGE
                    end
                end
            end
        end
    end
    
    -- Do the same for vertical gaps
    for x = 1, MapGenerator.MAP_W do
        for y = 2, MapGenerator.MAP_H - 1 do
            if map[y][x] == MapGenerator.TUNNEL then
                -- Check above and below for blockages
                if (map[y-1][x] == MapGenerator.BLOCKAGE and map[y+1][x] == MapGenerator.BLOCKAGE) then
                    if random() < MapGenerator.config.blockages.gapFillChance then
                        map[y][x] = MapGenerator.BLOCKAGE
                    end
                end
            end
        end
    end
    
    return map
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
    local firstLevel = levels[1]
    if firstLevel and firstLevel + 1 <= MapGenerator.MAP_H then
        blockedMap[firstLevel + 1][mainX] = MapGenerator.BLOCKAGE 
    end
    
    -- Add blockages in mines and tunnels
    MapGenerator.addVerticalBlockages(blockedMap, branchMines, mainX)
    MapGenerator.addHorizontalBlockages(blockedMap, levels)
    
    -- Try filling blockade gaps
    blockedMap = MapGenerator.fillBlockageGaps(blockedMap)
    
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
function MapGenerator.generateMine()
    local map = initializeEmptyMap()
    
    -- Generate levels and main tunnel
    local levelCount = random(MapGenerator.config.levels.count.min, MapGenerator.config.levels.count.max)
    local levels = MapGenerator.generateLevelPositions(levelCount)
    local mainX = floor(MapGenerator.MAP_W * MapGenerator.config.mainMine.xPosition)
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
    
    return MapGenerator.addBlockages(map, branchMines, levels, mainX), levels
end

-- Set a random seed
function MapGenerator.newSeed()
    local seed = os.time() * random(100)
    math.randomseed(seed)
    return seed
end

return MapGenerator