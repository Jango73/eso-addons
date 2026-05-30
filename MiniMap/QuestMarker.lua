QuestMarker = {}

function QuestMarker:New(id, definition, provider, root)
    local obj = {
        id = id,
        definition = definition,
        provider = provider,
        root = root,
        edgeControl = nil,
        insideControl = nil,
        markerSize = 0,
        insideMarkerSize = 0,
        textureMarkerSize = 0,
        shortcutX = nil,
        shortcutY = nil,
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function QuestMarker:CreateControl(controlName, controlType, texture, color)
    local control = WINDOW_MANAGER:CreateControl(controlName, self.root, controlType)
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
            control:SetEdgeColor(color[1] * MINIMAP_EDGE_DARKEN_FACTOR, color[2] * MINIMAP_EDGE_DARKEN_FACTOR, color[3] * MINIMAP_EDGE_DARKEN_FACTOR, 1)
            control:SetEdgeTexture(nil, MINIMAP_EDGE_INSET, MINIMAP_EDGE_INSET, MINIMAP_EDGE_BLEND_MODE)
        end
    end

    return control
end

function QuestMarker:CreateControls()
    local def = self.definition
    local baseName = "MiniMapMarker" .. self.id

    if def.hasEdge then
        local edgeType = def.edgeType or (def.type == MINIMAP_MARKER_TYPE_TEXTURE and CT_TEXTURE or CT_BACKDROP)
        self.edgeControl = self:CreateControl(baseName, edgeType, def.edgeTexture or def.texture, def.color)
    end

    if def.hasInside then
        local insideType = def.insideType or (def.type == MINIMAP_MARKER_TYPE_TEXTURE and CT_TEXTURE or CT_BACKDROP)
        self.insideControl = self:CreateControl(baseName .. "Inside", insideType, def.insideTexture or def.texture, def.insideColor or def.color)
    end
end

function QuestMarker:PositionAtEdge(control, center, radius, dx, dy, markerSize)
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length <= MINIMAP_EPSILON then
        control:SetHidden(true)
        return
    end

    local unitX = dx / length
    local unitY = dy / length
    local edgeRadius = radius - (markerSize * 0.34)

    control:SetDimensions(markerSize, markerSize)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.root, TOPLEFT, center + (unitX * edgeRadius), center + (unitY * edgeRadius))

    if control.SetTextureRotation then
        control:SetTextureRotation(MiniMapRenderUtils.GetRotationFromUp(unitX, unitY))
    end

    control:SetHidden(false)
end

function QuestMarker:UpdateMarkerControl(control, localX, localY, size)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.root, TOPLEFT, localX, localY)
    control:SetDimensions(size, size)
    control:SetHidden(false)
end

function QuestMarker:UpdatePosition(localX, localY, distFromCenter, center, radius, margin)
    local def = self.definition

    if distFromCenter >= (radius - margin) and def.hasEdge then
        if self.insideControl then
            self.insideControl:SetHidden(true)
        end
        if self.edgeControl then
            self:PositionAtEdge(self.edgeControl, center, radius, localX - center, localY - center, self.markerSize)
        end
    elseif def.hasInside then
        if self.edgeControl then
            self.edgeControl:SetHidden(true)
        end
        if self.insideControl then
            local size = self.insideMarkerSize
            if def.type == MINIMAP_MARKER_TYPE_TEXTURE then
                size = self.textureMarkerSize
            end
            self:UpdateMarkerControl(self.insideControl, localX, localY, size)
        end
    end
end

function QuestMarker:SetShortcut(x, y)
    self.shortcutX = x
    self.shortcutY = y
end

function QuestMarker:ClearShortcut()
    self.shortcutX = nil
    self.shortcutY = nil
end

function QuestMarker:HasShortcut()
    return self.shortcutX ~= nil
end

function QuestMarker:Update(playerX, playerY, mapRotation, center, radius, margin, mapSize)
    if self.provider then
        local targetX, targetY
        if self.shortcutX then
            targetX, targetY = self.shortcutX, self.shortcutY
        else
            targetX, targetY = self.provider()
        end

        if targetX and targetY then
            if not self.edgeControl then
                self:CreateControls()
            end

            local localX, localY, distFromCenter = MiniMapRenderUtils.WorldToLocal(
                targetX, targetY,
                playerX, playerY,
                mapSize, mapRotation, center
            )
            self:UpdatePosition(localX, localY, distFromCenter, center, radius, margin)
        else
            self:Hide()
        end
    end
end

function QuestMarker:UpdateWithCoords(targetX, targetY, playerX, playerY, mapRotation, center, radius, margin, mapSize)
    if targetX and targetY then
        if not self.edgeControl then
            self:CreateControls()
        end

        local localX, localY, distFromCenter = MiniMapRenderUtils.WorldToLocal(
            targetX, targetY,
            playerX, playerY,
            mapSize, mapRotation, center
        )
        self:UpdatePosition(localX, localY, distFromCenter, center, radius, margin)
    else
        self:Hide()
    end
end

function QuestMarker:ApplyLayout(size)
    self.markerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_EDGE_INDICATOR), 18, 32)
    self.insideMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_INSIDE_MARKER), 6, 12)
    self.textureMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER), MINIMAP_SPOT_TEXTURE_MIN, MINIMAP_SPOT_TEXTURE_MAX)

    if self.edgeControl then
        self.edgeControl:SetDimensions(self.markerSize, self.markerSize)
    end
    if self.insideControl then
        self.insideControl:SetDimensions(self.insideMarkerSize, self.insideMarkerSize)
    end
end

function QuestMarker:Hide()
    if self.edgeControl then
        self.edgeControl:SetHidden(true)
    end
    if self.insideControl then
        self.insideControl:SetHidden(true)
    end
end
