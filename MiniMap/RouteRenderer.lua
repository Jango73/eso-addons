RouteRenderer = {}

local ROUTE_SEGMENT_MAX = 200

function RouteRenderer:Init(owner, routeManager)
    self.owner = owner
    self.routeManager = routeManager
    self.segments = {}
    self.initialized = false
    self.debugText = ""
end

function RouteRenderer:EnsureInitialized()
    if self.initialized then
        return
    end

    for i = 1, ROUTE_SEGMENT_MAX do
        local controlName = self.owner.root:GetName() .. "RouteSegment" .. i
        local control = WINDOW_MANAGER:CreateControl(controlName, self.owner.root, CT_TEXTURE)
        control:SetDrawLayer(DL_OVERLAY)
        control:SetTexture(MINIMAP_SEGMENT_TEXTURE)
        control:SetHidden(true)
        self.segments[i] = control
    end

    self.initialized = true
end

function RouteRenderer:HideAll()
    if not self.initialized then
        return
    end

    for i = 1, ROUTE_SEGMENT_MAX do
        if self.segments[i] then
            self.segments[i]:SetHidden(true)
        end
    end
end

function RouteRenderer:Update(playerX, playerY, mapRotation, center, radius, currentMapName)
    self:EnsureInitialized()

    self.routeManager:RecalculateIfNeeded(playerX, playerY, currentMapName)
    local segments = self.routeManager:GetRouteSegments()
    self.debugText = "RouteSegs=" .. tostring(#segments)

    for i, segment in ipairs(segments) do
        local control = self.segments[i]
        if not control then break end

        local x1 = (segment.x1 - playerX) * self.owner.mapSize
        local y1 = (segment.y1 - playerY) * self.owner.mapSize
        local x2 = (segment.x2 - playerX) * self.owner.mapSize
        local y2 = (segment.y2 - playerY) * self.owner.mapSize

        x1, y1 = MiniMapRenderUtils.RotateVector(x1, y1, mapRotation)
        x2, y2 = MiniMapRenderUtils.RotateVector(x2, y2, mapRotation)

        local localX1 = center + x1
        local localY1 = center + y1
        local localX2 = center + x2
        local localY2 = center + y2

        local dx = localX2 - localX1
        local dy = localY2 - localY1
        local length = math.sqrt(dx * dx + dy * dy)
        local angle = 0
        if length > 0.0001 then
            local unitX = dx / length
            local unitY = dy / length
            angle = MiniMapRenderUtils.GetRotationFromUp(unitX, unitY) + math.pi / 2
        end

        self.debugText = self.debugText .. " l" .. i .. "=" .. string.format("%.0f", length)

        if length > 3 then
            local midX = (localX1 + localX2) / 2
            local midY = (localY1 + localY2) / 2
            control:ClearAnchors()
            control:SetAnchor(CENTER, self.owner.root, TOPLEFT, midX, midY)
            control:SetDimensions(math.max(length, 4), 3)
            control:SetColor(MINIMAP_ROUTE_COLOR[1], MINIMAP_ROUTE_COLOR[2], MINIMAP_ROUTE_COLOR[3], MINIMAP_ROUTE_COLOR[4])
            control:SetTextureRotation(angle)
            control:SetHidden(false)
        else
            control:SetHidden(true)
        end
    end

    for i = #segments + 1, ROUTE_SEGMENT_MAX do
        if self.segments[i] then
            self.segments[i]:SetHidden(true)
        end
    end
end

function RouteRenderer:GetNearestRoutePoint(playerX, playerY)
    if not playerX or not playerY then
        return nil
    end

    local segments = self.routeManager:GetRouteSegments()
    if not segments or #segments == 0 then
        return nil
    end

    local nearestX, nearestY
    local nearestDistSq = math.huge

    for _, segment in ipairs(segments) do
        local x1, y1, x2, y2 = segment.x1, segment.y1, segment.x2, segment.y2

        local dx = x2 - x1
        local dy = y2 - y1
        local lengthSq = dx * dx + dy * dy

        local projX, projY
        if lengthSq < 0.00000001 then
            projX, projY = x1, y1
        else
            local t = ((playerX - x1) * dx + (playerY - y1) * dy) / lengthSq
            t = math.max(0, math.min(1, t))
            projX = x1 + t * dx
            projY = y1 + t * dy
        end

        local distDx = playerX - projX
        local distDy = playerY - projY
        local distSq = distDx * distDx + distDy * distDy

        if distSq < nearestDistSq then
            nearestDistSq = distSq
            nearestX, nearestY = projX, projY
        end
    end

    return nearestX, nearestY
end

function RouteRenderer:GetDebugText()
    return self.debugText
end
