IndicatorRenderer = {}

local MARKER_ORDER = {
    MINIMAP_EDGE_INDICATOR_ROUTE,
    MINIMAP_EDGE_INDICATOR_QUEST,
    MINIMAP_EDGE_INDICATOR_WAYSHRINE,
    MINIMAP_EDGE_INDICATOR_NPC,
}

function IndicatorRenderer:Init(owner, providers)
    self.owner = owner
    self.providers = providers or {}
    self.markers = {}
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
end

function IndicatorRenderer:ApplyLayout(size)
    self.markerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_EDGE_INDICATOR), 18, 32)
    self.insideMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_INSIDE_MARKER), 6, 12)
    self.textureMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER), 18, 40)

    for _, marker in pairs(self.markers) do
        if marker.edgeControl then
            marker.edgeControl:SetDimensions(self.markerSize, self.markerSize)
        end
        if marker.insideControl then
            marker.insideControl:SetDimensions(self.insideMarkerSize, self.insideMarkerSize)
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
end
