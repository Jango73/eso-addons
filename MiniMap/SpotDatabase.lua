
SpotDatabase = {
    _data = nil,
}
SpotDatabase.__index = SpotDatabase

RESOURCE_CATEGORIES = {
    { key = 'book', color = { 0.8, 0.3, 0, 1 } },
    { key = 'chest', color = { 1, 0.84, 0, 1 } },
    { key = 'home', color = { 1, 1, 1, 1 } },
    { key = 'jewelry', color = { 0.9, 0.7, 0.2, 1 } },
    { key = 'ore', color = { 1, 0.5, 0, 1 } },
    { key = 'plant', color = { 0.2, 0.8, 0.2, 1 } },
    { key = 'rune', color = { 0.5, 0.2, 1, 1 } },
    { key = 'shard', color = { 1, 1, 1, 1 } },
    { key = 'silk', color = { 0.7, 0.3, 0.3, 1 } },
    { key = 'thief_chest', color = { 0.3, 0.5, 0.8, 1 } },
    { key = 'water', color = { 0.25, 0.5, 1, 1 } },
    { key = 'wood', color = { 0.6, 0.4, 0.2, 1 } },
}

function SpotDatabase:Init(savedVars)
    self._metadata = savedVars
    if not self._metadata["data"] then
        self._metadata["data"] = {}
    end
    self._data = self._metadata["data"]
end

local function Echo(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function IsDuplicate(s1, s2)
    if not s1 or not s2 then return false end
    local dx = s1.x - s2.x
    local dy = s1.y - s2.y
    return (dx * dx + dy * dy) <= (MINIMAP_SPOT_DUPLICATE_THRESHOLD * MINIMAP_SPOT_DUPLICATE_THRESHOLD)
end

function SpotDatabase:AddSpot(x, y, category, mapName)
    if not self._data then
        return false
    end
    if not x or not y or not category then return false end

    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then
        self._data[currentMap] = {}
    end
    if not self._data[currentMap][category] then
        self._data[currentMap][category] = {}
    end

    for i, s in ipairs(self._data[currentMap][category]) do
        if IsDuplicate(s, {x = x, y = y}) then
            self._data[currentMap][category][i] = { x = x, y = y, ts = GetTimeStamp() }
            return true, false
        end
    end

    table.insert(self._data[currentMap][category], { x = x, y = y, ts = GetTimeStamp() })
    return true, true
end

function SpotDatabase:CleanDuplicates()
    local removed = 0
    if not self._data then
        return 0
    end

    for zoneName, mapData in pairs(self._data) do
        if type(zoneName) == "string" and type(mapData) == "table" then
            for category, spots in pairs(mapData) do
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
                        self._data[zoneName][category] = newList
                    end
                end
            end
        end
    end

    return removed
end

function SpotDatabase:GetNearestSpot(px, py, category, maxCount, mapName)
    if not px or not py then return nil end
    maxCount = maxCount or 1
    local currentMap = mapName or GetMapName()

    if not self._data[currentMap] then
        return nil
    end

    local spots = self._data[currentMap][category]
    if not spots then
        return nil
    end

    local best = nil
    local bestDistSq = nil

    for _, s in ipairs(spots) do
        local dx, dy = s.x - px, s.y - py
        local distSq = (dx * dx) + (dy * dy)
        if not bestDistSq or distSq < bestDistSq then
            best = s
            bestDistSq = distSq
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

    if not self._data[currentMap] then
        return results
    end

    for cat, _ in pairs(self._data[currentMap]) do
        if type(cat) == 'string' then
            local nearest = self:GetNearestSpot(px, py, cat, 1, currentMap)
            if nearest then table.insert(results, nearest) end
        end
    end
    table.sort(results, function(a, b) return (a.distance or 0) < (b.distance or 0) end)
    return results
end

function SpotDatabase:Clear(zoneName, category)
    if zoneName then
        if category then
            if self._data[zoneName] then
                self._data[zoneName][category] = {}
            end
        else
            self._data[zoneName] = {}
        end
    else
        for k in pairs(self._data) do
            if type(k) == 'string' then
                self._data[k] = {}
            end
        end
    end
end

function SpotDatabase:RemoveSpotsInRadius(x, y, radius, category, mapName)
    if not self._data or not x or not y then return 0, 0 end
    mapName = mapName or GetMapName()
    local threshold = radius or MINIMAP_SPOT_DUPLICATE_THRESHOLD
    local thresholdSq = threshold * threshold
    local removed = 0
    local total = 0

    if not self._data[mapName] then
        return 0, 0
    end

    if category then
        local spots = self._data[mapName][category]
        if spots then
            local newSpots = {}
            for _, s in ipairs(spots) do
                total = total + 1
                local dx = s.x - x
                local dy = s.y - y
                if (dx * dx + dy * dy) > thresholdSq then
                    table.insert(newSpots, s)
                else
                    removed = removed + 1
                end
            end
            self._data[mapName][category] = newSpots
        end
    else
        for catKey, spots in pairs(self._data[mapName]) do
            if type(catKey) == "string" and type(spots) == "table" then
                local newSpots = {}
                for _, s in ipairs(spots) do
                    total = total + 1
                    local dx = s.x - x
                    local dy = s.y - y
                    if (dx * dx + dy * dy) > thresholdSq then
                        table.insert(newSpots, s)
                    else
                        removed = removed + 1
                    end
                end
                self._data[mapName][catKey] = newSpots
            end
        end
    end

    return removed, total
end

function SpotDatabase:GetSpots(category, mapName)
    if not category then return {} end
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then
        return {}
    end
    return self._data[currentMap][category] or {}
end

function SpotDatabase:GetSpotsByMap(mapName)
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then
        return {}
    end
    return self._data[currentMap]
end

function SpotDatabase:GetSpotCount(category, mapName)
    if mapName then
        if category then
            local mapData = self._data[mapName]
            if not mapData then return 0 end
            return #(mapData[category] or {})
        else
            local mapData = self._data[mapName]
            if not mapData then return 0 end
            local t = 0
            for k, v in pairs(mapData) do
                if type(k) == 'string' and type(v) == 'table' then t = t + #v end
            end
            return t
        end
    else
        local t = 0
        for zoneName, mapData in pairs(self._data) do
            if type(zoneName) == "string" and type(mapData) == "table" then
                for k, v in pairs(mapData) do
                    if type(k) == 'string' and type(v) == 'table' and (not category or k == category) then
                        t = t + #v
                    end
                end
            end
        end
        return t
    end
end

function SpotDatabase:GetAllMaps()
    local maps = {}
    for mapName, mapData in pairs(self._data) do
        if type(mapName) == "string" and type(mapData) == "table" then
            maps[mapName] = true
        end
    end
    return maps
end

function SpotDatabase:GetResourceCategory(lootType)
    if lootType == 15 then return 'rune'
    elseif lootType == 19 then return 'water'
    elseif lootType == 22 then return 'furniture'
    elseif lootType == 23 then return 'plant'
    elseif lootType == 26 then return 'ore'
    elseif lootType == 37 then return 'wood'
    elseif lootType == 40 then return 'silk'
    -- elseif lootType == 0 then return 'jewelry'
    -- elseif lootType == 0 then return 'treasure'
    end
    return nil
end

-- 11 = armor
-- 12 = light armor
-- 30 = recipe?

return SpotDatabase, RESOURCE_CATEGORIES
