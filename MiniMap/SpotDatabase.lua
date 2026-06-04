
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
    { key = 'world_boss', color = { 0.8, 0.1, 0.1, 1 } },
}

---Initialise the spot database with saved variables and built-in defaults.
---@param savedVars table The ZO_SavedVars table with a "data" key.
function SpotDatabase:Init(savedVars)
    self._metadata = savedVars
    if not self._metadata["data"] then
        self._metadata["data"] = {}
    end
    self._data = self._metadata["data"]
    self._builtinData = (MiniMapDefaultSpots and MiniMapDefaultSpots["data"]) or {}
    self._mergedCache = {}
end

---Print a message to the chat frame.
---@param message string The message text to display.
local function Echo(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(message)
    end
end

---Check whether two spots are within the duplicate threshold distance.
---@param s1 table First spot {x, y}.
---@param s2 table Second spot {x, y}.
---@return boolean True if the spots are considered duplicates.
local function IsDuplicate(s1, s2)
    if not s1 or not s2 then return false end
    local dx = s1.x - s2.x
    local dy = s1.y - s2.y
    return (dx * dx + dy * dy) <= (MINIMAP_SPOT_DUPLICATE_THRESHOLD * MINIMAP_SPOT_DUPLICATE_THRESHOLD)
end

---Append spots from a source list to a target list, skipping duplicates.
---@param target table Destination list.
---@param source table Source list of {x, y} spots.
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

---Append all categories/spots from a source map into a target merged map, skipping duplicates.
---@param target table Destination merged map (category → list of spots).
---@param source table Source map data (category → list of spots).
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

---Invalidate the merged cache for a specific map (or all maps).
---@param mapName string|nil Map key to invalidate, or nil for all.
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

---Get built-in spots for a category and map.
---@param category string Category key.
---@param mapName string|nil Map key (auto-detected if nil).
---@return table List of built-in spots.
function SpotDatabase:GetBuiltinSpots(category, mapName)
    if not category then return {} end
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return {} end
    if not self._builtinData or not self._builtinData[currentMap] then
        return {}
    end
    return self._builtinData[currentMap][category] or {}
end

---Add a resource spot, updating duplicate position or rejecting cross-category/builtin duplicates.
---@param x number World X.
---@param y number World Y.
---@param category string Category key.
---@param mapName string|nil Map key (auto-detected if nil).
---@return boolean added True if the operation succeeded.
---@return boolean isNew True if a brand new spot was created (vs updating an existing one).
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
            self._data[currentMap][category][i] = { x = x, y = y, ts = GetTimeStamp(), collectedTs = GetTimeStamp() }
            self:InvalidateMergedCache(currentMap)
            return true, false
        end
    end

    for _, s in ipairs(self:GetBuiltinSpots(category, currentMap)) do
        if IsDuplicate(s, candidate) then
            return true, false
        end
    end

    for catKey, spots in pairs(self._data[currentMap]) do
        if catKey ~= category and type(catKey) == "string" and type(spots) == "table" then
            for _, s in ipairs(spots) do
                if IsDuplicate(s, candidate) then
                    return true, false
                end
            end
        end
    end

    local builtinMap = self._builtinData and self._builtinData[currentMap]
    if builtinMap then
        for catKey, spots in pairs(builtinMap) do
            if catKey ~= category and type(catKey) == "string" and type(spots) == "table" then
                for _, s in ipairs(spots) do
                    if IsDuplicate(s, candidate) then
                        return true, false
                    end
                end
            end
        end
    end

    table.insert(self._data[currentMap][category], { x = x, y = y, ts = GetTimeStamp(), collectedTs = GetTimeStamp() })
    self:InvalidateMergedCache(currentMap)
    return true, true
end

---Remove duplicate spots (within threshold) across all zones and categories.
---@return number removed Count of removed duplicate spots.
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

---Find the nearest spot to a position in a given category.
---@param px number World X.
---@param py number World Y.
---@param category string Category key.
---@param maxCount number|nil Unused, reserved.
---@param mapName string|nil Map key (auto-detected if nil).
---@return table|nil Nearest spot {x, y, category, distance}, or nil.
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

---Get the nearest spot per category, sorted by distance.
---@param px number World X.
---@param py number World Y.
---@param maxCount number|nil Unused, reserved.
---@param mapName string|nil Map key (auto-detected if nil).
---@return table Sorted list of nearest spots per category.
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

---Clear spots for a specific zone/category, or all zones if no zone given.
---@param zoneName string|nil Zone map key (nil = all zones).
---@param category string|nil Category key (nil = all categories in the zone).
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

---Remove all spots within a radius of a position, optionally restricted to a category.
---@param x number World X.
---@param y number World Y.
---@param radius number Radius in world units.
---@param category string|nil Category key (nil = all categories).
---@param mapName string|nil Map key (auto-detected if nil).
---@return number removed Count of removed spots.
---@return number total Count of spots examined.
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

---Mark nearby resourcable spots as collected (sets collectedTs to now).
---Skips non-respawning categories.
---@param x number World X.
---@param y number World Y.
---@param mapName string|nil Map key (auto-detected if nil).
function SpotDatabase:SetCollectedTimestamp(x, y, mapName)
    if not self._data or not x or not y then return end
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return end

    local thresholdSq = MINIMAP_SPOT_DUPLICATE_THRESHOLD * MINIMAP_SPOT_DUPLICATE_THRESHOLD
    local now = GetTimeStamp()

    if self._data[currentMap] then
        for catKey, spots in pairs(self._data[currentMap]) do
            if type(catKey) == "string" and type(spots) == "table" and not MINIMAP_NON_RESPAWNING_CATEGORIES[catKey] then
                for _, spot in ipairs(spots) do
                    local dx = spot.x - x
                    local dy = spot.y - y
                    if (dx * dx + dy * dy) <= thresholdSq then
                        spot.collectedTs = now
                    end
                end
            end
        end
    end

    if self._builtinData and self._builtinData[currentMap] then
        for catKey, spots in pairs(self._builtinData[currentMap]) do
            if type(catKey) == "string" and type(spots) == "table" and not MINIMAP_NON_RESPAWNING_CATEGORIES[catKey] then
                for _, spot in ipairs(spots) do
                    local dx = spot.x - x
                    local dy = spot.y - y
                    if (dx * dx + dy * dy) <= thresholdSq then
                        spot.collectedTs = now
                    end
                end
            end
        end
    end
end

---Get the merged (user + builtin) spots for a given category on the current map.
---@param category string Category key.
---@param mapName string|nil Map key (auto-detected if nil).
---@return table List of spots for the category.
function SpotDatabase:GetSpots(category, mapName)
    if not category then return {} end
    local currentMap = mapName or MiniMapRenderUtils.GetCurrentMapKey()
    if not currentMap then return {} end
    local mapData = self:GetSpotsByMap(currentMap)
    return mapData[category] or {}
end

---Get all spots for a map, merged from user data and built-in data (cached).
---@param mapName string|nil Map key (auto-detected if nil).
---@return table Merged map data: category → list of spots.
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

---Get the total spot count, optionally filtered by category and/or map.
---@param category string|nil Category key (nil = all categories).
---@param mapName string|nil Map key (nil = all maps).
---@return number Total spot count.
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

---Get the set of all map keys that have user or built-in spots.
---@return table Map of map key → true.
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

---Map a LOOT_TYPE constant to a resource category key.
---@param lootType number The LOOT_TYPE_* constant.
---@return string|nil The corresponding category key, or nil.
function SpotDatabase:GetResourceCategory(lootType)
    if lootType == MINIMAP_LOOT_TYPE_RUNE then return 'rune'
    elseif lootType == MINIMAP_LOOT_TYPE_WATER then return 'water'
    elseif lootType == MINIMAP_LOOT_TYPE_FURNITURE then return 'furniture'
    elseif lootType == MINIMAP_LOOT_TYPE_PLANT then return 'plant'
    elseif lootType == MINIMAP_LOOT_TYPE_ORE then return 'ore'
    elseif lootType == MINIMAP_LOOT_TYPE_WOOD then return 'wood'
    elseif lootType == MINIMAP_LOOT_TYPE_SILK then return 'silk'
    end
    return nil
end

-- 11 = armor
-- 12 = light armor
-- 30 = recipe?

return SpotDatabase, RESOURCE_CATEGORIES
