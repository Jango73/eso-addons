local SpotDatabase = {
    spots = {},
    categories = {
        FORGE = "forge",
        WOOD = "wood",
        PLANT = "plant",
        CHEST = "chest",
    },
    SPOT_RADIUS = 0.0001,
}

local SpotDatabase_mt = { __index = SpotDatabase }

function SpotDatabase:New()
    local instance = setmetatable({}, SpotDatabase_mt)
    return instance
end

function SpotDatabase:AddSpot(x, y, category)
    if not x or not y or not category then
        return false
    end

    if not self.spots[category] then
        self.spots[category] = {}
    end

    table.insert(self.spots[category], {
        x = x,
        y = y,
        timestamp = GetTimeStamp(),
    })

    return true
end

function SpotDatabase:RemoveSpotsNear(x, y, category, radius)
    radius = radius or self.SPOT_RADIUS

    if category then
        self:RemoveSpotsInCategory(category, x, y, radius)
    else
        for cat, _ in pairs(self.categories) do
            self:RemoveSpotsInCategory(cat, x, y, radius)
        end
    end
end

function SpotDatabase:RemoveSpotsInCategory(category, x, y, radius)
    if not self.spots[category] then
        return
    end

    local newSpots = {}
    for _, spot in ipairs(self.spots[category]) do
        local dx = spot.x - x
        local dy = spot.y - y
        local distance = (dx * dx) + (dy * dy)
        if distance > (radius * radius) then
            table.insert(newSpots, spot)
        end
    end
    self.spots[category] = newSpots
end

function SpotDatabase:GetNearestSpot(x, y, category, maxCount)
    if not x or not y then
        return nil
    end

    maxCount = maxCount or 1
    local candidates = {}

    if category then
        candidates = self:GetSpotsInCategory(category)
    else
        for cat, _ in pairs(self.categories) do
            for _, spot in ipairs(self.spots[cat] or {}) do
                table.insert(candidates, {
                    x = spot.x,
                    y = spot.y,
                    category = cat,
                    distanceSq = self:CalculateDistanceSq(x, y, spot.x, spot.y),
                })
            end
        end
    end

    if category and not candidates[1] then
        candidates = self:GetSpotsInCategory(category)
    end

    table.sort(candidates, function(a, b)
        return a.distanceSq < b.distanceSq
    end)

    local results = {}
    for i = 1, math.min(maxCount, #candidates) do
        if candidates[i] then
            table.insert(results, {
                x = candidates[i].x,
                y = candidates[i].y,
                category = candidates[i].category or category,
                distance = math.sqrt(candidates[i].distanceSq),
            })
        end
    end

    return results
end

function SpotDatabase:GetNearestSpotByCategory(x, y, maxCount)
    if not x or not y then
        return {}
    end

    maxCount = maxCount or 1
    local results = {}

    for cat, _ in pairs(self.categories) do
        local nearest = self:GetNearestSpot(x, y, cat, 1)
        if nearest and nearest[1] then
            table.insert(results, nearest[1])
        end
    end

    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    return results
end

function SpotDatabase:GetSpotsInCategory(category)
    if not self.spots[category] then
        return {}
    end

    local result = {}
    for _, spot in ipairs(self.spots[category]) do
        table.insert(result, {
            x = spot.x,
            y = spot.y,
            category = category,
            distanceSq = 0,
        })
    end
    return result
end

function SpotDatabase:GetSpotsNear(x, y, radius, category)
    if not x or not y then
        return {}
    end

    radius = radius or 0.1
    local radiusSq = radius * radius
    local results = {}

    if category then
        self:CollectSpotsNear(x, y, radiusSq, category, results)
    else
        for cat, _ in pairs(self.categories) do
            self:CollectSpotsNear(x, y, radiusSq, cat, results)
        end
    end

    table.sort(results, function(a, b)
        return a.distanceSq < b.distanceSq
    end)

    for _, spot in ipairs(results) do
        spot.distance = math.sqrt(spot.distanceSq)
        spot.distanceSq = nil
    end

    return results
end

function SpotDatabase:CollectSpotsNear(x, y, radiusSq, category, results)
    if not self.spots[category] then
        return
    end

    for _, spot in ipairs(self.spots[category]) do
        local dx = spot.x - x
        local dy = spot.y - y
        local distSq = (dx * dx) + (dy * dy)
        if distSq <= radiusSq then
            table.insert(results, {
                x = spot.x,
                y = spot.y,
                category = category,
                distanceSq = distSq,
            })
        end
    end
end

function SpotDatabase:CalculateDistanceSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return (dx * dx) + (dy * dy)
end

function SpotDatabase:GetSpotCount(category)
    if category then
        return #(self.spots[category] or {})
    end

    local total = 0
    for cat, _ in pairs(self.categories) do
        total = total + #(self.spots[cat] or {})
    end
    return total
end

function SpotDatabase:Clear(category)
    if category then
        self.spots[category] = {}
    else
        for cat, _ in pairs(self.categories) do
            self.spots[cat] = {}
        end
    end
end

function SpotDatabase:Save()
    local data = {}
    for category, spots in pairs(self.spots) do
        data[category] = spots
    end
    return data
end

function SpotDatabase:Load(data)
    if not data then
        return
    end

    for category, spots in pairs(data) do
        if self.categories[category] or type(category) == "string" then
            self.spots[category] = spots or {}
        end
    end
end

function SpotDatabase:GetAllCategories()
    local result = {}
    for cat, _ in pairs(self.categories) do
        table.insert(result, cat)
    end
    return result
end

return SpotDatabase
