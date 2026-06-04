QuestMarker = {}

---Create a new QuestMarker instance.
---@param id string Unique marker identifier.
---@param definition table Marker visual definition from MARKER_DEFINITIONS.
---@param provider function|nil Callback returning (targetX, targetY).
---@param root table Parent UI control.
---@return table The new QuestMarker instance.
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

---Create a single UI control (texture or backdrop) with the given colour.
---@param controlName string Control name.
---@param controlType number CT_TEXTURE or CT_BACKDROP.
---@param texture string|nil Texture path (for CT_TEXTURE).
---@param color table|nil RGBA colour array.
---@return table The created control.
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

---Create the edge and/or inside controls based on the marker definition.
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

---Position a control at the minimap edge, rotated to point toward the target.
---@param control table The edge control.
---@param center number Minimap centre in pixels.
---@param radius number Minimap radius in pixels.
---@param dx number X offset from centre (world → local, unrotated).
---@param dy number Y offset from centre (world → local, unrotated).
---@param markerSize number Edge marker size in pixels.
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

---Place an inside-marker control at the given local pixel coordinates.
---@param control table The inside control.
---@param localX number Pixel X on the minimap.
---@param localY number Pixel Y on the minimap.
---@param size number Marker size in pixels.
function QuestMarker:UpdateMarkerControl(control, localX, localY, size)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.root, TOPLEFT, localX, localY)
    control:SetDimensions(size, size)
    control:SetHidden(false)
end

---Decide whether to show the edge indicator or the inside marker based on distance from centre.
---@param localX number Pixel X on the minimap.
---@param localY number Pixel Y on the minimap.
---@param distFromCenter number Distance from minimap centre in pixels.
---@param center number Minimap centre in pixels.
---@param radius number Minimap radius in pixels.
---@param margin number Edge margin in pixels.
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

---Override this marker's target with a shortcut position (e.g. wayshrine).
---@param x number World X.
---@param y number World Y.
function QuestMarker:SetShortcut(x, y)
    self.shortcutX = x
    self.shortcutY = y
end

---Remove any previously-set shortcut override.
function QuestMarker:ClearShortcut()
    self.shortcutX = nil
    self.shortcutY = nil
end

---Check whether this marker has a shortcut override set.
---@return boolean True if a shortcut is active.
function QuestMarker:HasShortcut()
    return self.shortcutX ~= nil
end

---Update marker position by querying the provider (or using the shortcut override).
---@param playerX number Player world X.
---@param playerY number Player world Y.
---@param mapRotation number Map rotation in radians.
---@param center number Minimap centre in pixels.
---@param radius number Minimap radius in pixels.
---@param margin number Edge margin in pixels.
---@param mapSize number Map texture size in pixels.
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

---Update marker position directly from explicit target coordinates.
---@param targetX number Target world X.
---@param targetY number Target world Y.
---@param playerX number Player world X.
---@param playerY number Player world Y.
---@param mapRotation number Map rotation in radians.
---@param center number Minimap centre in pixels.
---@param radius number Minimap radius in pixels.
---@param margin number Edge margin in pixels.
---@param mapSize number Map texture size in pixels.
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

---Recalculate marker sizes based on the minimap size.
---@param size number Minimap size in pixels.
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

---Hide both the edge and inside controls.
function QuestMarker:Hide()
    if self.edgeControl then
        self.edgeControl:SetHidden(true)
    end
    if self.insideControl then
        self.insideControl:SetHidden(true)
    end
end
