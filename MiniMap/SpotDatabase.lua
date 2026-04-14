
SpotDatabase = {
    _data = nil,
}
SpotDatabase.__index = SpotDatabase

RESOURCE_CATEGORIES = {
    { key = 'blacksmithing', color = { 1, 0.5, 0, 1 } },
    { key = 'clothier', color = { 0.8, 0.6, 0.4, 1 } },
    { key = 'woodworking', color = { 0.6, 0.4, 0.2, 1 } },
    { key = 'jewelrycrafter', color = { 0.9, 0.7, 0.2, 1 } },
    { key = 'wood', color = { 0.5, 0.35, 0.15, 1 } },
    { key = 'rune_refreme', color = { 0.5, 0.2, 1, 1 } },
    { key = 'alchemy', color = { 0.2, 0.8, 0.2, 1 } },
    { key = 'poison', color = { 0.4, 0.8, 0.4, 1 } },
    { key = 'treasure', color = { 1, 0.84, 0, 1 } },
}

function SpotDatabase:Init(savedVars)
    self._data = savedVars
end

function SpotDatabase:AddSpot(x, y, category, mapName)
    if not self._data then
        return false
    end
    if not x or not y or not category then return false end
    if not self._data[category] then self._data[category] = {} end

    local threshold = 0.0001
    local thresholdSq = threshold * threshold
    local currentMap = mapName or GetMapName()

    for i, s in ipairs(self._data[category]) do
        if s.map == currentMap then
            local dx = s.x - x
            local dy = s.y - y
            if (dx * dx + dy * dy) <= thresholdSq then
                self._data[category][i] = { x = x, y = y, map = currentMap, ts = GetTimeStamp() }
                return true
            end
        end
    end

    table.insert(self._data[category], { x = x, y = y, map = currentMap, ts = GetTimeStamp() })
    return true
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

return SpotDatabase, RESOURCE_CATEGORIES