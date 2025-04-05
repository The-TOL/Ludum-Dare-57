--THIS IS TEMP for gameplay the main vertical line will be blocked
-- Map dimensions
local MAP_W, MAP_H = 100, 50

-- Tile types
local WALL = 1
local TUNNEL = 0

-- Config
local config = {
    mainShaft = {
        x = math.floor(MAP_W * 0.4),
        width = 1
    },
    levels = {
        count = {min = 4, max = 5},    
        height = {min = 3, max = 10},
        length = {min = 20, max = 50}
    },
    branches = {
        chance = 0.35,
        minSpacing = 20
    },
    maxGenerationAttempts = 5
}

local levels, map, currentSeed, gridSize

function love.load()
    love.window.setMode(1920, 1080, {resizable = false})
    local screenWidth, screenHeight = love.graphics.getDimensions()
    gridSize = math.min(screenWidth / MAP_W, screenHeight / MAP_H)
    newSeed()
end

function love.keypressed(key)
    if key == "r" then newSeed() end
end

function newSeed()
    currentSeed = os.time() * love.math.random(100)
    love.math.setRandomSeed(currentSeed)
    map = generateAccessibleMineshaft()
end

-- Generate a mineshaft that is accessible
function generateAccessibleMineshaft()
    local attempts = 0
    local mineshaftMap
    local isAccessible = false
    
    while not isAccessible and attempts < config.maxGenerationAttempts do
        attempts = attempts + 1
        mineshaftMap = generateMineshaft()
        isAccessible = checkAccessibility(mineshaftMap, levels[#levels], config.mainShaft.x)
        
        if not isAccessible then
            currentSeed = os.time() * love.math.random(100)
            love.math.setRandomSeed(currentSeed)
        end
    end
    
    return isAccessible and mineshaftMap or createForcedAccessPath(generateMineshaft())
end

-- Create a blank map filled with walls
function createBlankMap()
    local newMap = {}
    for y = 1, MAP_H do
        newMap[y] = {}
        for x = 1, MAP_W do
            newMap[y][x] = WALL
        end
    end
    return newMap
end

-- Generate the mineshaft map
function generateMineshaft()
    local map = createBlankMap()
    
    local levelCount = math.random(config.levels.count.min, config.levels.count.max)
    levels = generateLevelPositions(levelCount)
    
    local mainX = config.mainShaft.x
    carveVerticalShaft(map, mainX, 1, levels[#levels] + 1)
    
    local branchShafts = {}
    table.insert(branchShafts, {x = mainX, startY = 1, endY = levels[#levels] + 1})
    
    -- Carve horizontal tunnels for each level
    for _, y in ipairs(levels) do
        local leftLength = math.random(config.levels.length.min, config.levels.length.max)
        local rightLength = math.random(config.levels.length.min, config.levels.length.max)
        
        local leftEnd = math.max(mainX - leftLength, 2)
        local rightEnd = math.min(mainX + rightLength, MAP_W - 2)
        
        for x = leftEnd, rightEnd do
            map[y][x] = TUNNEL
        end
    end
    
    -- Add guaranteed vertical shafts connected to the first level
    local firstLevel = levels[1]
    local nextLevel = levels[2] or (firstLevel + 5)
    
    local leftShaftX = math.max(math.floor(mainX * 0.6), 2)
    local rightShaftX = math.min(math.floor(mainX * 1.4), MAP_W - 2)
    
    carveVerticalShaft(map, leftShaftX, firstLevel, nextLevel)
    carveVerticalShaft(map, rightShaftX, firstLevel, nextLevel)
    
    -- Add to branch shafts list
    table.insert(branchShafts, {x = leftShaftX, startY = firstLevel, endY = nextLevel})
    table.insert(branchShafts, {x = rightShaftX, startY = firstLevel, endY = nextLevel})
    
    -- Add additional branch shafts
    local newBranchShafts = addBranchShafts(map, levels, mainX)
    for _, shaft in ipairs(newBranchShafts) do
        table.insert(branchShafts, shaft)
    end
    
    return map
end

-- Generate positions for levels
function generateLevelPositions(count)
    local positions = {}
    local margin = 3
    local y = margin + math.random(1, 2)
    table.insert(positions, y)
    
    for i = 2, count do
        local spacing = math.random(config.levels.height.min, config.levels.height.max)
        y = y + spacing
        
        if y >= MAP_H - margin then
            break
        end
        
        table.insert(positions, y)
    end
    
    return positions
end

-- Carve a vertical shaft in the map
function carveVerticalShaft(map, x, yStart, yEnd)
    yEnd = math.min(yEnd, MAP_H)
    
    for y = yStart, yEnd do
        map[y][x] = TUNNEL
    end
end

-- Add branch shafts to the map
function addBranchShafts(map, levels, mainX)
    local branchPositions = {}
    local branchShafts = {}
    
    for i = 1, #levels - 1 do
        tryAddBranchShaft(map, levels, i, "left", mainX, branchPositions, branchShafts)
        tryAddBranchShaft(map, levels, i, "right", mainX, branchPositions, branchShafts)
    end
    
    return branchShafts
end

-- Check if position is valid for a branch shaft
function isValidBranchPosition(map, x, y, branchPositions)
    if map[y][x] ~= TUNNEL then
        return false
    end
    
    for _, pos in ipairs(branchPositions) do
        if math.abs(pos - x) < config.branches.minSpacing then
            return false
        end
    end
    
    return true
end

-- Get a valid branch position
function getBranchPosition(map, currentY, side, mainX, branchPositions)
    local x
    
    if side == "left" then
        x = math.random(2, mainX - 5)
    else
        x = math.random(mainX + 5, MAP_W - 2)
    end
    
    return isValidBranchPosition(map, x, currentY, branchPositions) and x or nil
end

-- Attempt to add a branch shaft
function tryAddBranchShaft(map, levels, levelIndex, side, mainX, branchPositions, branchShafts)
    if math.random() >= config.branches.chance then
        return
    end
    
    local currentY = levels[levelIndex]
    local x = getBranchPosition(map, currentY, side, mainX, branchPositions)
    
    if not x then
        return
    end
    
    local connectLevels = math.min(math.random(1, 3), #levels - levelIndex)
    local endLevelIndex = levelIndex + connectLevels
    local endY = levels[endLevelIndex]
    
    carveVerticalShaft(map, x, currentY, endY)
    
    table.insert(branchPositions, x)
    table.insert(branchShafts, {x = x, startY = currentY, endY = endY})
end

-- Check if deepest level is accessible from the top
function checkAccessibility(map, deepestLevel, mainX)
    -- Placeholder
    return true 
end

-- Draw the map
function love.draw()
    for y = 1, #map do
        for x = 1, #map[y] do
            love.graphics.setColor(map[y][x] == TUNNEL and {0.8, 0.8, 0.8} or {0.4, 0.3, 0.2})
            love.graphics.rectangle("fill", (x - 1) * gridSize, (y - 1) * gridSize, gridSize, gridSize)
        end
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Seed: " .. currentSeed .. "\nPress R to regenerate", 10, 10)
    
    local isAccessible = checkAccessibility(map, levels[#levels], config.mainShaft.x)
    love.graphics.print("Deepest level is " .. (isAccessible and "ACCESSIBLE" or "NOT ACCESSIBLE"), 10, 50)
end