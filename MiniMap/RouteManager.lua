RouteManager = {
    _data = nil,
    _currentRoute = nil,
    _selectedCategories = {},
    _useAllCategories = false,
    _lastMapName = nil,
}
RouteManager.__index = RouteManager

---Euclidean distance between two points.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number Distance.
local function Distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

---Calculate the total round-trip distance of a route (including return to start).
---@param route table List of {x, y} points.
---@return number Total distance.
local function CalculateTotalDistance(route)
    if not route or #route < 2 then return 0 end
    local total = 0
    for i = 1, #route - 1 do
        total = total + Distance(route[i].x, route[i].y, route[i + 1].x, route[i + 1].y)
    end
    total = total + Distance(route[#route].x, route[#route].y, route[1].x, route[1].y)
    return total
end

---Solve a travelling-salesman route using nearest-neighbour heuristic with 2-opt refinement.
---@param spots table List of {x, y} spot tables.
---@param startX number Starting X.
---@param startY number Starting Y.
---@return table Optimised route (list of spot tables).
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

    local n = #route
    local improved = true
    local maxIter = 50
    local iter = 0
    while improved and iter < maxIter do
        improved = false
        iter = iter + 1
        for i = 1, n - 2 do
            for j = i + 2, n - 1 do
                local xi, yi = route[i].x, route[i].y
                local xip1, yip1 = route[i + 1].x, route[i + 1].y
                local xj, yj = route[j].x, route[j].y
                local xjp1, yjp1 = route[j + 1].x, route[j + 1].y

                local oldDist = Distance(xi, yi, xip1, yip1) + Distance(xj, yj, xjp1, yjp1)
                local newDist = Distance(xi, yi, xj, yj) + Distance(xip1, yip1, xjp1, yjp1)

                if newDist + 0.0001 < oldDist then
                    local t = {}
                    for k = 1, i do t[k] = route[k] end
                    for k = j, i + 1, -1 do t[#t + 1] = route[k] end
                    for k = j + 1, n do t[#t + 1] = route[k] end
                    route = t
                    improved = true
                end
            end
        end
    end

    return route
end

---Initialise the route manager with saved variables.
---@param savedVars table The saved variables table.
function RouteManager:Init(savedVars)
    self._data = savedVars
    self._selectedCategories = {}
    self._useAllCategories = false
end

---Get the list of selected category keys (or {"all"} if all categories are active).
---@return table List of category key strings.
function RouteManager:GetSelectedCategories()
    if self._useAllCategories then
        return { "all" }
    end

    local result = {}
    for cat, _ in pairs(self._selectedCategories) do
        if _ then table.insert(result, cat) end
    end
    return result
end

---Check whether a specific category is selected.
---@param category string Category key.
---@return boolean True if selected.
function RouteManager:IsCategorySelected(category)
    return self._selectedCategories[category] == true
end

---Toggle a category on/off in the selection (disables "all" mode).
---@param category string Category key.
function RouteManager:ToggleCategory(category)
    self._useAllCategories = false
    if self._selectedCategories[category] then
        self._selectedCategories[category] = nil
    else
        self._selectedCategories[category] = true
    end
end

---Replace the selected categories with a specific list (disables "all" mode).
---@param categories table List of category key strings.
function RouteManager:SetSelectedCategories(categories)
    self._useAllCategories = false
    self._selectedCategories = {}
    for _, cat in ipairs(categories) do
        self._selectedCategories[cat] = true
    end
end

---Select all resource categories for routing.
function RouteManager:SetAllCategories()
    self._selectedCategories = {}
    self._useAllCategories = true
end

---Deselect all resource categories.
function RouteManager:ClearCategories()
    self._selectedCategories = {}
    self._useAllCategories = false
end

---Get the current calculated route.
---@return table|nil List of {x, y} spot tables.
function RouteManager:GetRoute()
    return self._currentRoute
end

---Check whether a route has been calculated and has points.
---@return boolean True if a route exists with at least one point.
function RouteManager:IsRouteActive()
    return self._currentRoute and #self._currentRoute > 0
end

---Clear the current route.
function RouteManager:ClearRoute()
    self._currentRoute = nil
end

---Calculate a TSP-optimised route through selected spots, starting from the player.
---@param playerX number Player world X.
---@param playerY number Player world Y.
---@param mapName string Current map key.
---@return table|nil The calculated route (list of {x, y}), or nil if no spots.
function RouteManager:CalculateRoute(playerX, playerY, mapName)
    if not playerX or not playerY then
        return nil
    end

    local allSpots = {}
    local zoneSpots = SpotDatabase:GetSpotsByMap(mapName)
    if zoneSpots then
        if self._useAllCategories then
            for _, spots in pairs(zoneSpots) do
                if type(spots) == "table" then
                    for _, spot in ipairs(spots) do
                        table.insert(allSpots, spot)
                    end
                end
            end
        else
            for cat, _ in pairs(self._selectedCategories) do
                if _ and type(cat) == "string" then
                    local spots = zoneSpots[cat]
                    if spots then
                        for _, spot in ipairs(spots) do
                            table.insert(allSpots, spot)
                        end
                    end
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

---Recalculate the route only if the spot counts or map have changed since last calculation.
---@param playerX number Player world X.
---@param playerY number Player world Y.
---@param mapName string Current map key.
---@return table|nil The current or newly-calculated route.
function RouteManager:RecalculateIfNeeded(playerX, playerY, mapName)
    local categoriesChanged = false
    self._lastCategoryCounts = self._lastCategoryCounts or {}

    if self._useAllCategories then
        local oldCount = self._lastCategoryCounts.all or 0
        local newCount = SpotDatabase:GetSpotCount(nil, mapName)
        if oldCount ~= newCount then
            categoriesChanged = true
        end
        self._lastCategoryCounts.all = newCount
    else
        self._lastCategoryCounts.all = nil
        for cat, _ in pairs(self._selectedCategories) do
            if _ then
                local oldCount = self._lastCategoryCounts[cat] or 0
                local newCount = SpotDatabase:GetSpotCount(cat, mapName)
                if oldCount ~= newCount then
                    categoriesChanged = true
                end
                self._lastCategoryCounts[cat] = newCount
            end
        end
    end

    local mapChanged = mapName ~= self._lastMapName

    if categoriesChanged or mapChanged then
        return self:CalculateRoute(playerX, playerY, mapName)
    end

    return self._currentRoute
end

---Get the list of line segments that make up the route (including closing segment).
---@return table List of {x1, y1, x2, y2} segment tables.
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

---Get a human-readable summary of the current route.
---@return string Route info string.
function RouteManager:GetRouteInfo()
    if not self._currentRoute then
        return "No route"
    end

    local count = #self._currentRoute
    local totalDist = CalculateTotalDistance(self._currentRoute)
    local cats = {}
    if self._useAllCategories then
        table.insert(cats, "all")
    else
        for cat, _ in pairs(self._selectedCategories) do
            if _ then table.insert(cats, cat) end
        end
    end

    return string.format("Route: %d spots, %.2f distance, categories: %s", count, totalDist, table.concat(cats, ", "))
end

return RouteManager
