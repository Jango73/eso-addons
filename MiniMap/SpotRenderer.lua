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
    self.textureMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER), 18, 40)
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
            control:SetEdgeColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 1)
            control:SetEdgeTexture(nil, 1, 1, 2)
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

function SpotRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, currentMapName)
    self:EnsureInitialized()

    local zoneSpots = SpotDatabase:GetSpotsByMap(currentMapName)
    if not zoneSpots then
        self:HideAll()
        return
    end

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
                markerIndex = markerIndex + 1
            end
        end

        for i = markerIndex, #markers do
            markers[i].control:SetHidden(true)
        end
    end)
end
