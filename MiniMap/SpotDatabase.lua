
SpotDatabase = {
    _data = nil,
    _builtinData = nil,
    _mergedCache = nil,
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
    self._builtinData = (MiniMapDefaultSpots and MiniMapDefaultSpots["data"]) or {}
    self._mergedCache = {}
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

local function AppendUniqueSpots(target, source)
    if type(source) ~= "table" then
        return
    end

    for _, spot in ipairs(source) do
        if type(spot) == "table" and spot.x and spot.y then
            local duplicate = false
            for _, existing in ipairs(target) do
                if IsDuplicate(existing, spot) then
                    duplicate = true
                    break
                end
            end
            if not duplicate then
                table.insert(target, spot)
            end
        end
    end
end

local function AppendMapData(target, source)
    if type(source) ~= "table" then
        return
    end

    for category, spots in pairs(source) do
        if type(category) == "string" and type(spots) == "table" then
            if not target[category] then
                target[category] = {}
            end
            AppendUniqueSpots(target[category], spots)
        end
    end
end

function SpotDatabase:InvalidateMergedCache(mapName)
    if not self._mergedCache then
        return
    end
    if mapName then
        self._mergedCache[mapName] = nil
    else
        self._mergedCache = {}
    end
end

function SpotDatabase:GetBuiltinSpots(category, mapName)
    if not category then return {} end
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return {} end
    if not self._builtinData or not self._builtinData[currentMap] then
        return {}
    end
    return self._builtinData[currentMap][category] or {}
end

function SpotDatabase:AddSpot(x, y, category, mapName)
    if not self._data then
        return false
    end
    if not x or not y or not category then return false end

    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return false end
    if not self._data[currentMap] then
        self._data[currentMap] = {}
    end
    if not self._data[currentMap][category] then
        self._data[currentMap][category] = {}
    end

    local candidate = { x = x, y = y }
    for i, s in ipairs(self._data[currentMap][category]) do
        if IsDuplicate(s, candidate) then
            self._data[currentMap][category][i] = { x = x, y = y, ts = GetTimeStamp() }
            self:InvalidateMergedCache(currentMap)
            return true, false
        end
    end

    for _, s in ipairs(self:GetBuiltinSpots(category, currentMap)) do
        if IsDuplicate(s, candidate) then
            return true, false
        end
    end

    table.insert(self._data[currentMap][category], { x = x, y = y, ts = GetTimeStamp() })
    self:InvalidateMergedCache(currentMap)
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
                        self:InvalidateMergedCache(zoneName)
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
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return nil end

    local spots = self:GetSpots(category, currentMap)

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
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return {} end
    local results = {}
    local mapData = self:GetSpotsByMap(currentMap)

    for cat, _ in pairs(mapData) do
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
                self:InvalidateMergedCache(zoneName)
            end
        else
            self._data[zoneName] = {}
            self:InvalidateMergedCache(zoneName)
        end
    else
        for k in pairs(self._data) do
            if type(k) == 'string' then
                self._data[k] = {}
            end
        end
        self:InvalidateMergedCache()
    end
end

function SpotDatabase:RemoveSpotsInRadius(x, y, radius, category, mapName)
    if not self._data or not x or not y then return 0, 0 end
    mapName = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not mapName then return 0, 0 end
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
            self:InvalidateMergedCache(mapName)
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
        self:InvalidateMergedCache(mapName)
    end

    return removed, total
end

function SpotDatabase:GetSpots(category, mapName)
    if not category then return {} end
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return {} end
    local mapData = self:GetSpotsByMap(currentMap)
    return mapData[category] or {}
end

function SpotDatabase:GetSpotsByMap(mapName)
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return {} end
    if self._mergedCache and self._mergedCache[currentMap] then
        return self._mergedCache[currentMap]
    end

    local merged = {}
    if self._data then
        AppendMapData(merged, self._data[currentMap])
    end
    if self._builtinData then
        AppendMapData(merged, self._builtinData[currentMap])
    end

    if self._mergedCache then
        self._mergedCache[currentMap] = merged
    end
    return merged
end

function SpotDatabase:GetSpotCount(category, mapName)
    if mapName then
        if category then
            return #self:GetSpots(category, mapName)
        else
            local mapData = self:GetSpotsByMap(mapName)
            local t = 0
            for k, v in pairs(mapData) do
                if type(k) == 'string' and type(v) == 'table' then t = t + #v end
            end
            return t
        end
    else
        local t = 0
        for zoneName in pairs(self:GetAllMaps()) do
            local mapData = self:GetSpotsByMap(zoneName)
            for k, v in pairs(mapData) do
                if type(k) == 'string' and type(v) == 'table' and (not category or k == category) then
                    t = t + #v
                end
            end
        end
        return t
    end
end

function SpotDatabase:GetAllMaps()
    local maps = {}
    for mapName, mapData in pairs(self._data or {}) do
        if type(mapName) == "string" and type(mapData) == "table" then
            maps[mapName] = true
        end
    end
    for mapName, mapData in pairs(self._builtinData or {}) do
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
