IndicatorRenderer = {}

local MARKER_ORDER = {
    MINIMAP_EDGE_INDICATOR_ROUTE,
    MINIMAP_EDGE_INDICATOR_QUEST,
    MINIMAP_EDGE_INDICATOR_WAYSHRINE,
}

local COMPASS_MARKERS = {
    MINIMAP_COMPASS_N,
    MINIMAP_COMPASS_S,
    MINIMAP_COMPASS_W,
    MINIMAP_COMPASS_E,
}

function IndicatorRenderer:Init(owner, providers)
    self.owner = owner
    self.providers = providers or {}
    self.markers = {}
    self.compassMarkers = {}
    self.markerSize = 0
    self.insideMarkerSize = 0
    self.textureMarkerSize = 0

    for _, id in ipairs(MARKER_ORDER) do
        local def = MARKER_DEFINITIONS[id]
        if def then
            self.markers[id] = {
                definition = def,
                edgeControl = nil,
                insideControl = nil,
                color = def.color,
                provider = self.providers[id],
            }
        end
    end

    for _, id in ipairs(COMPASS_MARKERS) do
        local def = MARKER_DEFINITIONS[id]
        if def then
            self.compassMarkers[id] = {
                definition = def,
                edgeControl = nil,
            }
        end
    end
end

function IndicatorRenderer:ApplyLayout(size)
    self.markerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_EDGE_INDICATOR), 18, 32)
    self.insideMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_INSIDE_MARKER), 6, 12)
    self.textureMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER), 18, 40)
    self.compassSize = MiniMapRenderUtils.Clamp(math.floor(size * 0.12), 12, 20)

    for _, marker in pairs(self.markers) do
        if marker.edgeControl then
            marker.edgeControl:SetDimensions(self.markerSize, self.markerSize)
        end
        if marker.insideControl then
            marker.insideControl:SetDimensions(self.insideMarkerSize, self.insideMarkerSize)
        end
    end

    for _, marker in pairs(self.compassMarkers) do
        if marker.edgeControl then
            marker.edgeControl:SetFont("ZoFontHeader")
            marker.edgeControl:SetDimensions(self.compassSize, self.compassSize)
        end
    end
end

function IndicatorRenderer:CreateMarkerControl(controlName, controlType, texture, color)
    local control = WINDOW_MANAGER:CreateControl(controlName, self.owner.root, controlType)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetHidden(true)

    if controlType == CT_TEXTURE then
        if texture then
            control:SetTexture(texture)
        end
        if color then
            control:SetColor(color[1], color[2], color[3], color[4] or 1)
        end
    elseif controlType == CT_BACKDROP then
        if color then
            control:SetCenterColor(color[1], color[2], color[3], 1)
            control:SetEdgeColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 1)
            control:SetEdgeTexture(nil, 1, 1, 2)
        end
    end

    return control
end

function IndicatorRenderer:CreateMarkerControls(id, marker)
    local def = marker.definition
    local baseName = "MiniMapMarker" .. id

    if def.hasEdge then
        local edgeType = def.edgeType or (def.type == MINIMAP_MARKER_TYPE_TEXTURE and CT_TEXTURE or CT_BACKDROP)
        marker.edgeControl = self:CreateMarkerControl(baseName, edgeType, def.edgeTexture or def.texture, def.color)
    end

    if def.hasInside then
        local insideType = def.insideType or (def.type == MINIMAP_MARKER_TYPE_TEXTURE and CT_TEXTURE or CT_BACKDROP)
        marker.insideControl = self:CreateMarkerControl(baseName .. "Inside", insideType, def.insideTexture or def.texture, def.insideColor or def.color)
    end
end

function IndicatorRenderer:UpdateMarkerControl(control, localX, localY, size)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.owner.root, TOPLEFT, localX, localY)
    control:SetDimensions(size, size)
    control:SetHidden(false)
end

function IndicatorRenderer:UpdateMarker(marker, localX, localY, distFromCenter, radius, margin, center)
    local def = marker.definition

    if distFromCenter >= (radius - margin) and def.hasEdge then
        if marker.insideControl then
            marker.insideControl:SetHidden(true)
        end
        if marker.edgeControl then
            self:PositionMarkerAtEdge(marker.edgeControl, center, radius, localX - center, localY - center, self.markerSize)
        end
    elseif def.hasInside then
        if marker.edgeControl then
            marker.edgeControl:SetHidden(true)
        end
        if marker.insideControl then
            local size = self.insideMarkerSize
            if def.type == MINIMAP_MARKER_TYPE_TEXTURE then
                size = self.textureMarkerSize
            end
            self:UpdateMarkerControl(marker.insideControl, localX, localY, size)
        end
    end
end

function IndicatorRenderer:PositionMarkerAtEdge(control, center, radius, dx, dy, markerSize)
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length <= 0.0001 then
        control:SetHidden(true)
        return
    end

    local unitX = dx / length
    local unitY = dy / length
    local edgeRadius = radius - (markerSize * 0.34)

    control:SetDimensions(markerSize, markerSize)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.owner.root, TOPLEFT, center + (unitX * edgeRadius), center + (unitY * edgeRadius))

    if control.SetTextureRotation then
        control:SetTextureRotation(MiniMapRenderUtils.GetRotationFromUp(unitX, unitY))
    end

    control:SetHidden(false)
end

function IndicatorRenderer:CreateCompassControl(marker, id)
    local def = marker.definition
    local control = WINDOW_MANAGER:CreateControl("MiniMapCompass" .. def.compassDirection, self.owner.root, CT_LABEL)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetFont("ZoFontHeader")
    control:SetColor(def.color[1], def.color[2], def.color[3], def.color[4] or 1)
    control:SetText(Locale.GetCompassDirection(def.compassDirection))
    control:SetAnchor(CENTER, self.owner.root, CENTER, 0, 0)
    control:SetHidden(true)
    marker.edgeControl = control
end

function IndicatorRenderer:PositionCompassMarker(marker, center, radius, direction, mapRotation)
    local offset = radius - (self.compassSize * 0.7)
    local x, y

    local baseAngle = 0
    if direction == "N" then
        baseAngle = -math.pi / 2
    elseif direction == "S" then
        baseAngle = math.pi / 2
    elseif direction == "W" then
        baseAngle = math.pi
    elseif direction == "E" then
        baseAngle = 0
    else
        return
    end

    local angle = baseAngle + mapRotation

    x = center + offset * math.cos(angle)
    y = center + offset * math.sin(angle)

    marker.edgeControl:ClearAnchors()
    marker.edgeControl:SetAnchor(CENTER, self.owner.root, TOPLEFT, x, y)
    marker.edgeControl:SetHidden(false)
end

function IndicatorRenderer:Update(playerX, playerY, mapRotation, center, radius, margin)
    for id, marker in pairs(self.markers) do
        if marker.provider then
            local targetX, targetY = marker.provider()

            if not marker.edgeControl then
                self:CreateMarkerControls(id, marker)
            end

            if targetX and targetY then
                local localX, localY, distFromCenter = MiniMapRenderUtils.WorldToLocal(
                    targetX,
                    targetY,
                    playerX,
                    playerY,
                    self.owner.mapSize,
                    mapRotation,
                    center
                )
                self:UpdateMarker(marker, localX, localY, distFromCenter, radius, margin, center)
            else
                if marker.edgeControl then
                    marker.edgeControl:SetHidden(true)
                end
                if marker.insideControl then
                    marker.insideControl:SetHidden(true)
                end
            end
        end
    end

    for id, marker in pairs(self.compassMarkers) do
        if not marker.edgeControl then
            self:CreateCompassControl(marker, id)
        end
        local direction = marker.definition.compassDirection
        self:PositionCompassMarker(marker, center, radius, direction, mapRotation)
    end
end
