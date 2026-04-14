
SpotDatabase = {
    _data = nil,
}
SpotDatabase.__index = SpotDatabase

RESOURCE_CATEGORIES = {
    { key = 'chest', color = { 1, 0.84, 0, 1 } },
    { key = 'jewelrycrafter', color = { 0.9, 0.7, 0.2, 1 } },
    { key = 'ore', color = { 1, 0.5, 0, 1 } },
    { key = 'plant', color = { 0.2, 0.8, 0.2, 1 } },
    { key = 'poison', color = { 0.5, 0.5, 0.5, 1 } },
    { key = 'rune', color = { 0.5, 0.2, 1, 1 } },
    { key = 'silk', color = { 0.7, 0.3, 0.3, 1 } },
    { key = 'thief_chest', color = { 0.3, 0.5, 0.8, 1 } },
    { key = 'water', color = { 0.25, 0.5, 1, 1 } },
    { key = 'wood', color = { 0.6, 0.4, 0.2, 1 } },
}

function SpotDatabase:Init(savedVars)
    self._data = savedVars
end

local function IsDuplicate(s1, s2, mapName)
    if not s1 or not s2 then return false end
    if mapName and s1.map ~= mapName then return false end
    local dx = s1.x - s2.x
    local dy = s1.y - s2.y
    return (dx * dx + dy * dy) <= (MINIMAP_SPOT_DUPLICATE_THRESHOLD * MINIMAP_SPOT_DUPLICATE_THRESHOLD)
end

function SpotDatabase:AddSpot(x, y, category, mapName)
    if not self._data then
        return false
    end
    if not x or not y or not category then return false end
    if not self._data[category] then self._data[category] = {} end

    local currentMap = mapName or GetMapName()

    for i, s in ipairs(self._data[category]) do
        if IsDuplicate(s, {x = x, y = y}, currentMap) then
            self._data[category][i] = { x = x, y = y, map = currentMap, ts = GetTimeStamp() }
            return true
        end
    end

    table.insert(self._data[category], { x = x, y = y, map = currentMap, ts = GetTimeStamp() })
    return true
end

function SpotDatabase:CleanDuplicates()
    local removed = 0
    if not self._data then
        return 0
    end
    
    for category, spots in pairs(self._data) do
        local isValidCat = type(category) == "string"
        local isValidSpots = type(spots) == "table"
        
        if isValidCat and isValidSpots then
            local count = #spots
            if count >= 2 then
                local toRemove = {}
                for i = 1, count do
                    for j = i + 1, count do
                        if IsDuplicate(spots[i], spots[j]) then
                            toRemove[j] = true
                        end
                    end
                end
                
                local newList = {}
                for i = 1, count do
                    if not toRemove[i] then
                        table.insert(newList, spots[i])
                    else
                        removed = removed + 1
                    end
                end
                self._data[category] = newList
            end
        end
    end
    
    return removed
end

function SpotDatabase:GetNearestSpot(px, py, category, maxCount, mapName)
    if not px or not py then return nil end
    maxCount = maxCount or 1
    local spots = self._data[category] or {}
    local currentMap = mapName or GetMapName()

    local best = nil
    local bestDistSq = nil

    for _, s in ipairs(spots) do
        if s.map == currentMap then
            local dx, dy = s.x - px, s.y - py
            local distSq = (dx * dx) + (dy * dy)
            if not bestDistSq or distSq < bestDistSq then
                best = s
                bestDistSq = distSq
            end
        end
    end

    if best then
        return { x = best.x, y = best.y, category = category, distance = math.sqrt(bestDistSq) }
    end
    return nil
end

function SpotDatabase:GetNearestSpotByCategory(px, py, maxCount, mapName)
    if not px or not py then return {} end
    maxCount = maxCount or 1
    local currentMap = mapName or GetMapName()
    local results = {}
    for cat, _ in pairs(self._data) do
        if type(cat) == 'string' then
            local nearest = self:GetNearestSpot(px, py, cat, 1, currentMap)
            if nearest then table.insert(results, nearest) end
        end
    end
    table.sort(results, function(a, b) return (a.distance or 0) < (b.distance or 0) end)
    return results
end

function SpotDatabase:Clear(category)
    if category then self._data[category] = {}
    else for k in pairs(self._data) do if type(k) == 'string' then self._data[k] = {} end end end
end

function SpotDatabase:RemoveSpotsInRadius(x, y, radius, category, mapName)
    if not self._data or not x or not y then return 0, 0 end
    category = category or nil
    mapName = mapName or GetMapName()
    local threshold = radius or MINIMAP_SPOT_DUPLICATE_THRESHOLD
    local thresholdSq = threshold * threshold
    local removed = 0
    local total = 0

    local categories = category and {category} or RESOURCE_CATEGORIES

    for _, cat in ipairs(categories) do
        local catKey = type(cat) == "table" and cat.key or cat
        local spots = self._data[catKey] or {}
        local newSpots = {}
        for _, s in ipairs(spots) do
            total = total + 1
            if s.map ~= mapName then
                table.insert(newSpots, s)
            else
                local dx = s.x - x
                local dy = s.y - y
                if (dx * dx + dy * dy) > thresholdSq then
                    table.insert(newSpots, s)
                else
                    removed = removed + 1
                end
            end
        end
        self._data[catKey] = newSpots
    end

    return removed, total
end

function SpotDatabase:GetSpots(category)
    if not category then return {} end
    return self._data[category] or {}
end

function SpotDatabase:GetSpotCount(category)
    if category then return #(self._data[category] or {}) end
    local t = 0
    for k, v in pairs(self._data) do
        if type(k) == 'string' and type(v) == 'table' then t = t + #v end
    end
    return t
end

function SpotDatabase:GetResourceCategory(lootType)
    if lootType == 15 then return 'rune'
    elseif lootType == 19 then return 'water'
    elseif lootType == 22 then return 'furniture'
    elseif lootType == 23 then return 'plant'
    elseif lootType == 26 then return 'ore'
    elseif lootType == 37 then return 'wood'
    elseif lootType == 40 then return 'silk'
    -- elseif lootType == 0 then return 'jewelrycrafter'
    -- elseif lootType == 0 then return 'poison'
    -- elseif lootType == 0 then return 'treasure'
    end
    return nil
end

-- 11 = armor
-- 12 = light armor
-- 30 = recipe?

return SpotDatabase, RESOURCE_CATEGORIES
