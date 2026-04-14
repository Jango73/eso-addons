RouteManager = {
    _data = nil,
    _currentRoute = nil,
    _selectedCategories = {},
    _lastMapName = nil,
}
RouteManager.__index = RouteManager

local function Distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function CalculateTotalDistance(route)
    if not route or #route < 2 then return 0 end
    local total = 0
    for i = 1, #route - 1 do
        total = total + Distance(route[i].x, route[i].y, route[i + 1].x, route[i + 1].y)
    end
    total = total + Distance(route[#route].x, route[#route].y, route[1].x, route[1].y)
    return total
end

local function SolveTSP(spots, startX, startY)
    if not spots or #spots == 0 then return {} end
    if #spots == 1 then return spots end

    local visited = {}
    local route = {}
    local currentX, currentY = startX, startY

    for i = 1, #spots do
        local nearestIdx = nil
        local nearestDist = nil

        for j = 1, #spots do
            if not visited[j] then
                local dist = Distance(currentX, currentY, spots[j].x, spots[j].y)
                if not nearestDist or dist < nearestDist then
                    nearestDist = dist
                    nearestIdx = j
                end
            end
        end

        if nearestIdx then
            visited[nearestIdx] = true
            table.insert(route, spots[nearestIdx])
            currentX, currentY = spots[nearestIdx].x, spots[nearestIdx].y
        end
    end

    return route
end

function RouteManager:Init(savedVars)
    self._data = savedVars
    self._selectedCategories = {}
end

function RouteManager:GetSelectedCategories()
    local result = {}
    for cat, _ in pairs(self._selectedCategories) do
        if _ then table.insert(result, cat) end
    end
    return result
end

function RouteManager:IsCategorySelected(category)
    return self._selectedCategories[category] == true
end

function RouteManager:ToggleCategory(category)
    if self._selectedCategories[category] then
        self._selectedCategories[category] = nil
    else
        self._selectedCategories[category] = true
    end
end

function RouteManager:SetSelectedCategories(categories)
    self._selectedCategories = {}
    for _, cat in ipairs(categories) do
        self._selectedCategories[cat] = true
    end
end

function RouteManager:ClearCategories()
    self._selectedCategories = {}
end

function RouteManager:GetRoute()
    return self._currentRoute
end

function RouteManager:IsRouteActive()
    return self._currentRoute and #self._currentRoute > 0
end

function RouteManager:ClearRoute()
    self._currentRoute = nil
end

function RouteManager:CalculateRoute(playerX, playerY, mapName)
    if not playerX or not playerY then
        return nil
    end

    local allSpots = {}
    for cat, _ in pairs(self._selectedCategories) do
        if _ and type(cat) == "string" then
            local spots = SpotDatabase:GetSpots(cat)
            for _, spot in ipairs(spots) do
                if spot.map == mapName then
                    table.insert(allSpots, spot)
                end
            end
        end
    end

    if #allSpots == 0 then
        self._currentRoute = nil
        return nil
    end

    self._currentRoute = SolveTSP(allSpots, playerX, playerY)
    self._lastMapName = mapName

    return self._currentRoute
end

function RouteManager:RecalculateIfNeeded(playerX, playerY, mapName)
    local categoriesChanged = false
    for cat, _ in pairs(self._selectedCategories) do
        if _ then
            local oldCount = self._lastCategoryCounts and self._lastCategoryCounts[cat] or 0
            local newCount = SpotDatabase:GetSpotCount(cat)
            if oldCount ~= newCount then
                categoriesChanged = true
            end
            self._lastCategoryCounts = self._lastCategoryCounts or {}
            self._lastCategoryCounts[cat] = newCount
        end
    end

    local mapChanged = mapName ~= self._lastMapName

    if categoriesChanged or mapChanged then
        return self:CalculateRoute(playerX, playerY, mapName)
    end

    return self._currentRoute
end

function RouteManager:GetRouteSegments()
    if not self._currentRoute or #self._currentRoute < 2 then
        return {}
    end

    local segments = {}
    for i = 1, #self._currentRoute - 1 do
        table.insert(segments, {
            x1 = self._currentRoute[i].x,
            y1 = self._currentRoute[i].y,
            x2 = self._currentRoute[i + 1].x,
            y2 = self._currentRoute[i + 1].y,
        })
    end

    table.insert(segments, {
        x1 = self._currentRoute[#self._currentRoute].x,
        y1 = self._currentRoute[#self._currentRoute].y,
        x2 = self._currentRoute[1].x,
        y2 = self._currentRoute[1].y,
    })

    return segments
end

function RouteManager:GetRouteInfo()
    if not self._currentRoute then
        return "No route"
    end

    local count = #self._currentRoute
    local totalDist = CalculateTotalDistance(self._currentRoute)
    local cats = {}
    for cat, _ in pairs(self._selectedCategories) do
        if _ then table.insert(cats, cat) end
    end

    return string.format("Route: %d spots, %.2f distance, categories: %s", count, totalDist, table.concat(cats, ", "))
end

return RouteManager