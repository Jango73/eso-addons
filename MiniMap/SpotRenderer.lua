SpotRenderer = {}

local MAX_MARKERS_PER_CAT = 20
local SPOT_MARKER_PREFIX = "SpotMarker"

local function ForEachCategory(callback)
    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        callback(cat)
    end
end

function SpotRenderer:Init(owner)
    self.owner = owner
    self.markers = {}
    self.initialized = false
    self.backdropMarkerSize = 0
    self.textureMarkerSize = 0
end

function SpotRenderer:ApplyLayout(size)
    self.backdropMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_BACKDROP_MARKER), 9, 30)
    self.textureMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER), MINIMAP_SPOT_TEXTURE_MIN, MINIMAP_SPOT_TEXTURE_MAX)
end

function SpotRenderer:GetMargin()
    return self.backdropMarkerSize
end

function SpotRenderer:CreateMarkerControl(controlName, controlType, texture, color)
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
            control:SetEdgeColor(color[1] * MINIMAP_EDGE_DARKEN_FACTOR, color[2] * MINIMAP_EDGE_DARKEN_FACTOR, color[3] * MINIMAP_EDGE_DARKEN_FACTOR, 1)
            control:SetEdgeTexture(nil, MINIMAP_EDGE_INSET, MINIMAP_EDGE_INSET, MINIMAP_EDGE_BLEND_MODE)
        end
    end

    return control
end

function SpotRenderer:UpdateMarkerControl(control, localX, localY, size)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.owner.root, TOPLEFT, localX, localY)
    control:SetDimensions(size, size)
    control:SetHidden(false)
end

function SpotRenderer:EnsureInitialized()
    if self.initialized then
        return
    end

    ForEachCategory(function(cat)
        self.markers[cat.key] = {}
        for i = 1, MAX_MARKERS_PER_CAT do
            local controlName = self.owner.root:GetName() .. SPOT_MARKER_PREFIX .. cat.key .. i
            local texture = MINIMAP_SPOT_TEXTURES[cat.key]
            local controlType = texture and CT_TEXTURE or CT_BACKDROP
            local color = texture and {1, 1, 1, 1} or cat.color
            local control = self:CreateMarkerControl(controlName, controlType, texture, color)
            self.markers[cat.key][i] = {
                control = control,
                texture = texture,
                color = cat.color,
            }
        end
    end)

    self.initialized = true
end

function SpotRenderer:HideAll()
    if not self.initialized then
        return
    end

    ForEachCategory(function(cat)
        local markers = self.markers[cat.key]
        for i = 1, #markers do
            markers[i].control:SetHidden(true)
        end
    end)
end

local function GetSpotAlpha(spot, categoryKey, now, respawnTime)
    if MINIMAP_NON_RESPAWNING_CATEGORIES[categoryKey] then
        return MINIMAP_SPOT_ALPHA_AVAILABLE
    end
    if not spot.collectedTs then
        return MINIMAP_SPOT_ALPHA_AVAILABLE
    end
    local elapsed = now - spot.collectedTs
    local half = respawnTime * 0.5
    if elapsed < half then
        return MINIMAP_SPOT_ALPHA_COLLECTED
    elseif elapsed < respawnTime then
        return MINIMAP_SPOT_ALPHA_RECHARGING
    end
    return MINIMAP_SPOT_ALPHA_AVAILABLE
end

function SpotRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, currentMapKey)
    self:EnsureInitialized()

    local zoneSpots = SpotDatabase:GetSpotsByMap(currentMapKey)
    if not zoneSpots then
        self:HideAll()
        return
    end

    local respawnTime = (MiniMap.saved and MiniMap.saved.respawnTime) or MINIMAP_DEFAULT_RESPAWN_TIME
    local now = GetTimeStamp()

    ForEachCategory(function(cat)
        local markers = self.markers[cat.key]
        local spots = zoneSpots[cat.key] or {}
        local markerIndex = 1
        local isTexture = MINIMAP_SPOT_TEXTURES[cat.key] ~= nil

        for _, spot in ipairs(spots) do
            local localX, localY, distFromCenter = MiniMapRenderUtils.WorldToLocal(
                spot.x,
                spot.y,
                playerX,
                playerY,
                self.owner.mapSize,
                mapRotation,
                center
            )

            if distFromCenter < (radius - margin) and markerIndex <= #markers then
                local markerData = markers[markerIndex]
                local markerSize = isTexture and self.textureMarkerSize or self.backdropMarkerSize
                self:UpdateMarkerControl(markerData.control, localX, localY, markerSize)
                local alpha = GetSpotAlpha(spot, cat.key, now, respawnTime)
                markerData.control:SetAlpha(alpha)
                markerIndex = markerIndex + 1
            end
        end

        for i = markerIndex, #markers do
            markers[i].control:SetHidden(true)
        end
    end)
end
