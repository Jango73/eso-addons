SpotRenderer = {}

local MAX_MARKERS_PER_CAT = 20
local SPOT_MARKER_PREFIX = "SpotMarker"

---Iterate over every resource category and invoke a callback.
---@param callback function Function receiving the category definition table.
local function ForEachCategory(callback)
    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        callback(cat)
    end
end

---Initialise the spot renderer with its owner and route manager.
---@param owner table The owning MiniMap object.
---@param routeManager table The RouteManager instance.
function SpotRenderer:Init(owner, routeManager)
    self.owner = owner
    self.routeManager = routeManager
    self.markers = {}
    self.initialized = false
    self.backdropMarkerSize = 0
    self.textureMarkerSize = 0
end

---Recalculate marker sizes based on the minimap size.
---@param size number Minimap size in pixels.
function SpotRenderer:ApplyLayout(size)
    self.backdropMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_BACKDROP_MARKER), 9, 30)
    self.textureMarkerSize = MiniMapRenderUtils.Clamp(math.floor(size * MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER), MINIMAP_SPOT_TEXTURE_MIN, MINIMAP_SPOT_TEXTURE_MAX)
end

---Get the edge margin (equals the backdrop marker size).
---@return number Margin in pixels.
function SpotRenderer:GetMargin()
    return self.backdropMarkerSize
end

---Create a single spot marker control (texture or backdrop).
---@param controlName string Control name.
---@param controlType number CT_TEXTURE or CT_BACKDROP.
---@param texture string|nil Texture path.
---@param color table|nil RGBA colour.
---@return table The created control.
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

---Position and show a marker control at the given local pixel coordinates.
---@param control table The control to update.
---@param localX number Pixel X on the minimap.
---@param localY number Pixel Y on the minimap.
---@param size number Marker size in pixels.
function SpotRenderer:UpdateMarkerControl(control, localX, localY, size)
    control:ClearAnchors()
    control:SetAnchor(CENTER, self.owner.root, TOPLEFT, localX, localY)
    control:SetDimensions(size, size)
    control:SetHidden(false)
end

---Lazily create the pool of spot marker controls for every category.
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

---Hide all spot marker controls across all categories.
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

---Determine the alpha for a spot marker based on its collection time and respawn timer.
---@param spot table The spot {collectedTs}.
---@param categoryKey string Category key.
---@param now number Current timestamp.
---@param respawnTime number Respawn duration in seconds.
---@return number Alpha value (0-1).
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

---Get the set of categories that are part of an active route, or nil if all should show.
---@param routeManager table The RouteManager instance.
---@return table|nil Set of category keys to show, or nil for all.
local function GetCategoriesForRoute(routeManager)
    if not routeManager or not routeManager:IsRouteActive() then
        return nil
    end

    local selected = routeManager:GetSelectedCategories()
    if #selected == 1 and selected[1] == "all" then
        return nil
    end

    local catSet = {}
    for _, catKey in ipairs(selected) do
        catSet[catKey] = true
    end
    return catSet
end

---Render all resource spot markers on the minimap, applying alpha for respawn state.
---@param playerX number Player world X.
---@param playerY number Player world Y.
---@param mapRotation number Map rotation in radians.
---@param center number Minimap centre in pixels.
---@param radius number Minimap radius in pixels.
---@param margin number Edge margin in pixels.
---@param currentMapKey string Current map identifier.
function SpotRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, currentMapKey)
    self:EnsureInitialized()

    local zoneSpots = SpotDatabase:GetSpotsByMap(currentMapKey)
    if not zoneSpots then
        self:HideAll()
        return
    end

    local routeCategories = GetCategoriesForRoute(self.routeManager)

    local respawnTime = (MiniMap.saved and MiniMap.saved.respawnTime) or MINIMAP_DEFAULT_RESPAWN_TIME
    local now = GetTimeStamp()

    ForEachCategory(function(cat)
        if routeCategories and not routeCategories[cat.key] then
            local markers = self.markers[cat.key]
            for i = 1, #markers do
                markers[i].control:SetHidden(true)
            end
            return
        end

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
