
-- ==============================================================================
-- NOTES
-- ==============================================================================
-- 2026-04-15: SetTextureRotation bug at ±90° with edge_indicator_triangle.dds
-- Cause: DDS with mipmaps caused wrong LOD selection in game engine
-- Fix: recreate DDS texture WITHOUT mipmaps (ImageMagick: -define dds:mipmaps=0)
-- 2026-04-16:
-- ZO_SavedVars:NewAccountWide returns a special object that cannot be iterated
-- directly (no pairs() or ipairs()). To store our tables, we must use a key of
-- this object, e.g.: savedVars["data"] = {}. See SpotDatabase:Init for the pattern.
-- ==============================================================================

---Convert a normalised UI slider value (0-1) into an actual zoom level.
---@param t number Normalised zoom in [0, 1].
---@return number Effective zoom level.
local function ZoomFromUI(t)
    return MINIMAP_ZOOM_MIN * (MINIMAP_ZOOM_MAX / MINIMAP_ZOOM_MIN) ^ t
end

MiniMap = {
    tiles = {},
    tileCount = 0,
    currentMapKey = nil,
    currentMapType = nil,
    nextMapRefreshMs = 0,
    nextLocationProbeMs = 0,
    nextQuestBreadcrumbRefreshMs = 0,
    nextWayshrineRouteUpdateMs = 0,
    isCityMap = false,
    nearestQuestShortcutX = nil,
    nearestQuestShortcutY = nil,
    nearestQuestDestX = nil,
    nearestQuestDestY = nil,
}

---Print a message to the chat frame.
---@param message string The message text to display.
local function Echo(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(message)
    end
end

---Show an alert that a resource spot was added.
---@param category string The resource category name.
local function PrintSpotAdded(category)
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, Locale.GetString("spotAdded"):format(category))
end

---Show an alert that resource spots were deleted.
---@param count number Number of spots removed.
local function PrintSpotDeleted(count)
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, Locale.GetString("spotsDeleted"):format(count))
end

---Get the player's current map-normalised position.
---@return number|nil x Normalised X coordinate.
---@return number|nil y Normalised Y coordinate.
local function GetPlayerMapPosition()
    local x, y, _ = GetMapPlayerPosition("player")
    return x, y
end

---Add a resource spot at the player's current position.
---@param category string Resource category key.
---@return boolean Whether the spot was added (or already existed).
function MiniMap:AddSpotAtPlayer(category)
    local x, y = GetPlayerMapPosition()
    if not x or not y then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, MiniMap:Text('spotAddNoPosition'))
        return false
    end
    local currentMap = MiniMap.currentMapKey
    if not currentMap then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, MiniMap:Text('spotAddNoMap'))
        return false
    end
    local added, isNew = SpotDatabase:AddSpot(x, y, category, currentMap)
    if not added then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, MiniMap:Text('spotAddNoMap'))
        return false
    end
    if not isNew then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, MiniMap:Text('spotAddDuplicate'))
        return true
    end
    PrintSpotAdded(category)
    return true
end

---Iterate over every resource category and invoke a callback.
---@param callback function Function receiving the category definition table.
local function ForEachCategory(callback)
    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        callback(cat)
    end
end

---Create all UI controls: minimap window, map tiles, player arrow, toolbar, zoom bar, renderers, world map overlay.
function MiniMap:CreateControls()
    local root = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapWindow")
    root:SetDrawTier(DT_HIGH)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    if root.SetClipsChildren then
        root:SetClipsChildren(true)
    end

    local background = WINDOW_MANAGER:CreateControl("MiniMapBackground", root, CT_BACKDROP)
    background:SetAnchorFill(root)
    background:SetCenterColor(0, 0, 0, 0.32)
    background:SetEdgeColor(0, 0, 0, 0)
    background:SetEdgeTexture("", 1, 1, 0)

    local map = WINDOW_MANAGER:CreateControl("MiniMapMap", root, CT_CONTROL)
    map:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    if map.SetTransformNormalizedOriginPoint then
        map:SetTransformNormalizedOriginPoint(0.5, 0.5)
    end

    local border = WINDOW_MANAGER:CreateControl("MiniMapBorder", root, CT_TEXTURE)
    border:SetAnchorFill(root)
    border:SetTexture(MINIMAP_BORDER_TEXTURE)
    border:SetDrawLayer(DL_CONTROLS)
    border:SetDrawLevel(5)

    local player = WINDOW_MANAGER:CreateControl("MiniMapPlayer", root, CT_TEXTURE)
    player:SetAnchor(CENTER, root, CENTER, 0, 0)
    player:SetDimensions(24, 24)
    player:SetTexture("EsoUI/Art/Icons/mapKey/mapKey_player.dds")
    player:SetDrawLayer(DL_OVERLAY)

    self.root = root
    self.background = background
    self.map = map
    self.border = border
    self.player = player

    local toolbar = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapToolbar")
    toolbar:SetDrawTier(DT_HIGH)
    toolbar:SetClampedToScreen(true)
    toolbar:SetMouseEnabled(true)
    toolbar:SetHidden(true)

    local toolbarBg = WINDOW_MANAGER:CreateControl("MiniMapToolbarBg", toolbar, CT_BACKDROP)
    toolbarBg:SetAnchorFill(toolbar)
    toolbarBg:SetCenterColor(0, 0, 0, 0.7)
    toolbarBg:SetEdgeColor(
        MINIMAP_ESO_BORDER_COLOR[1],
        MINIMAP_ESO_BORDER_COLOR[2],
        MINIMAP_ESO_BORDER_COLOR[3],
        MINIMAP_ESO_BORDER_COLOR[4]
    )
    toolbarBg:SetEdgeTexture("", MINIMAP_EDGE_INSET, MINIMAP_EDGE_INSET, MINIMAP_EDGE_BLEND_MODE)

    local buttonSize = 32
    local buttonSpacing = 6
    local totalWidth = (#RESOURCE_CATEGORIES + 1) * (buttonSize + buttonSpacing) - buttonSpacing
    toolbar:SetDimensions(totalWidth, buttonSize + 12)

    ---Set up mouse hover tooltip behaviour for a toolbar button.
    ---@param btn table The button control.
    ---@param btnBg table The button background backdrop.
    ---@param hoverColor table RGBA colour for hover state.
    ---@param normalColor table RGBA colour for normal state.
    ---@param tooltipText string Text to display in the tooltip.
    local function SetupButtonTooltip(btn, btnBg, hoverColor, normalColor, tooltipText)
        btn:SetHandler("OnMouseEnter", function()
            btnBg:SetCenterColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
            InitializeTooltip(InformationTooltip, btn, TOPLEFT, TOPLEFT, 0, 0)
            SetTooltipText(InformationTooltip, tooltipText)
        end)
        btn:SetHandler("OnMouseExit", function()
            btnBg:SetCenterColor(normalColor[1], normalColor[2], normalColor[3], normalColor[4])
            ClearTooltip(InformationTooltip)
        end)
    end

    ---Create a toolbar button for a resource category.
    ---@param index number Button position index.
    ---@param cat table Resource category definition.
    ---@return table The created button control.
    local function CreateToolButton(index, cat)
        local btn = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtn" .. cat.key, toolbar, CT_BUTTON)
        btn:SetDimensions(buttonSize, buttonSize)

        local btnBg = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtn" .. cat.key .. "Bg", btn, CT_BACKDROP)
        btnBg:SetAnchorFill(btn)
        btnBg:SetCenterColor(cat.color[1], cat.color[2], cat.color[3], 0.7)
        btnBg:SetEdgeColor(cat.color[1], cat.color[2], cat.color[3], 1)
        btnBg:SetEdgeTexture("", MINIMAP_EDGE_INSET, MINIMAP_EDGE_INSET, MINIMAP_EDGE_BLEND_MODE)

        local btnLabel = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtn" .. cat.key .. "Label", btn, CT_LABEL)
        btnLabel:SetAnchor(CENTER, btn, CENTER, 0, 0)
        btnLabel:SetFont("ZoFontGameBold")
        btnLabel:SetColor(0, 0, 0, 1)
        btnLabel:SetText(string.upper(string.sub(cat.key, 1, 1)))

        btn:SetMouseOverTexture("EsoUI/Art/Buttons/left_up.dds")
        btn:SetHandler("OnClicked", function()
            if IsShiftKeyDown() then
                self:HandleSlashCommand(MINIMAP_SLASH_ROUTE .. " " .. cat.key)
            else
                self:AddSpotAtPlayer(cat.key)
            end
        end)
        SetupButtonTooltip(btn, btnBg,
            { cat.color[1] * 0.7, cat.color[2] * 0.7, cat.color[3] * 0.7, 0.9 },
            { cat.color[1], cat.color[2], cat.color[3], 0.7 },
            self:Text('toolbarAddSpot'):format(cat.key))
        return btn
    end

    ---Create the delete-spots button for the toolbar.
    ---@return table The created delete button control.
    local function CreateDeleteButton()
        local btn = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtnDelete", toolbar, CT_BUTTON)
        btn:SetDimensions(buttonSize, buttonSize)
        btn:SetAnchor(LEFT, toolbar, LEFT, buttonSpacing, 0)

        local btnBg = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtnDeleteBg", btn, CT_BACKDROP)
        btnBg:SetAnchorFill(btn)
        btnBg:SetCenterColor(0.8, 0.2, 0.2, 0.8)
        btnBg:SetEdgeColor(1, 0.3, 0.3, 1)
        btnBg:SetEdgeTexture("", MINIMAP_EDGE_INSET, MINIMAP_EDGE_INSET, MINIMAP_EDGE_BLEND_MODE)

        local btnLabel = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtnDeleteLabel", btn, CT_LABEL)
        btnLabel:SetAnchor(CENTER, btn, CENTER, 0, 0)
        btnLabel:SetFont("ZoFontGameBold")
        btnLabel:SetColor(1, 1, 1, 1)
        btnLabel:SetText("X")

        btn:SetHandler("OnClicked", function()
            local x, y = GetPlayerMapPosition()
            if x and y then
                local deleted = 0
                ForEachCategory(function(cat)
                    local d = SpotDatabase:RemoveSpotsInRadius(x, y, MINIMAP_SPOT_DUPLICATE_THRESHOLD, cat.key, MiniMap.currentMapKey)
                    deleted = deleted + d
                end)
                PrintSpotDeleted(deleted)
            end
        end)
        SetupButtonTooltip(btn, btnBg,
            { 1, 0.3, 0.3, 0.9 },
            { 0.8, 0.2, 0.2, 0.8 },
            self:Text('toolbarDeleteSpots'))
        return btn
    end

    self.toolbarButtons = {}
    local prevBtn = nil
    for i, cat in ipairs(RESOURCE_CATEGORIES) do
        local btn = CreateToolButton(i, cat)
        self.toolbarButtons[cat.key] = btn
        if i == 1 then
            btn:ClearAnchors()
            btn:SetAnchor(LEFT, toolbar, LEFT, 4, 0)
        else
            btn:ClearAnchors()
            btn:SetAnchor(LEFT, prevBtn, RIGHT, 2, 0)
        end
        prevBtn = btn
    end
    self.toolbarDeleteButton = CreateDeleteButton()
    self.toolbarDeleteButton:ClearAnchors()
    self.toolbarDeleteButton:SetAnchor(LEFT, prevBtn, RIGHT, 8, 0)

    self.toolbar = toolbar
    self.toolbarBg = toolbarBg

    self.spotRenderer = SpotRenderer
    self.spotRenderer:Init(self, self.routeManager)

    self.noteRenderer = NoteRenderer
    self.noteRenderer:Init(self)

    self.routeRenderer = RouteRenderer
    self.routeRenderer:Init(self, self.routeManager)

    self.indicatorRenderer = IndicatorRenderer
    self.indicatorRenderer:Init(self)
    self.indicatorRenderer:AddQuestMarker(
        MINIMAP_EDGE_INDICATOR_WAYSHRINE,
        MARKER_DEFINITIONS[MINIMAP_EDGE_INDICATOR_WAYSHRINE],
        function()
            if self.nearestQuestShortcutX then
                return nil, nil
            end
            return self:GetNearestWayshrinePosition()
        end
    )
    self.indicatorRenderer:AddQuestMarker(
        MINIMAP_EDGE_INDICATOR_ROUTE,
        MARKER_DEFINITIONS[MINIMAP_EDGE_INDICATOR_ROUTE],
        function()
            return self.routeRenderer:GetNearestRoutePoint(self.playerMapX, self.playerMapY)
        end
    )

    local zoomSize = 28
    local zoomSpacing = 2

    self.zoomBar = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapZoomBar")
    self.zoomBar:SetDrawTier(DT_HIGH)
    self.zoomBar:SetClampedToScreen(true)
    self.zoomBar:SetMouseEnabled(true)
    self.zoomBar:SetHidden(true)
    self.zoomBar:SetDimensions(zoomSize * 2 + zoomSpacing, zoomSize)

    ---Create a zoom in/out button for the zoom bar.
    ---@param name string Control name prefix.
    ---@param text string Button label ("+" or "-").
    ---@param anchorTo table Control to anchor from.
    ---@param delta number Horizontal offset from anchor.
    ---@return table The created button control.
    local function MakeZoomButton(name, text, anchorTo, delta)
        local btn = WINDOW_MANAGER:CreateControl(name, self.zoomBar, CT_BUTTON)
        btn:SetDimensions(zoomSize, zoomSize)

        local bg = WINDOW_MANAGER:CreateControl(name .. "Bg", btn, CT_BACKDROP)
        bg:SetAnchorFill(btn)
        bg:SetCenterColor(0, 0, 0, 0.7)
        bg:SetEdgeColor(MINIMAP_ESO_BORDER_COLOR[1], MINIMAP_ESO_BORDER_COLOR[2], MINIMAP_ESO_BORDER_COLOR[3], MINIMAP_ESO_BORDER_COLOR[4])
        bg:SetEdgeTexture("", MINIMAP_EDGE_INSET, MINIMAP_EDGE_INSET, MINIMAP_EDGE_BLEND_MODE)

        local label = WINDOW_MANAGER:CreateControl(name .. "Label", btn, CT_LABEL)
        label:SetAnchor(CENTER, btn, CENTER, 0, 0)
        label:SetFont("ZoFontGameBold")
        label:SetColor(1, 1, 1, 1)
        label:SetText(text)

        btn:SetAnchor(LEFT, anchorTo, anchorTo == self.zoomBar and LEFT or RIGHT, delta, 0)
        btn:SetHandler("OnClicked", function()
            local step = (text == "+") and 1 or -1
            local newZoom = MiniMapRenderUtils.Clamp((MiniMap.saved.zoom or DEFAULTS.zoom) + step, MINIMAP_ZOOM_MIN, MINIMAP_ZOOM_MAX)
            if newZoom ~= MiniMap.saved.zoom then
                MiniMap.saved.zoom = newZoom
                MiniMap:RefreshMap(true)
            end
        end)

        btn:SetHandler("OnMouseEnter", function()
            bg:SetCenterColor(0.2, 0.2, 0.2, 0.9)
            InitializeTooltip(InformationTooltip, btn, TOPLEFT, TOPLEFT, 0, 0)
            SetTooltipText(InformationTooltip, (text == "+") and self:Text('zoomIn') or self:Text('zoomOut'))
        end)
        btn:SetHandler("OnMouseExit", function()
            bg:SetCenterColor(0, 0, 0, 0.7)
            ClearTooltip(InformationTooltip)
        end)
        return btn
    end

    self.zoomOut = MakeZoomButton("MiniMapZoomOut", "-", self.zoomBar, 0)
    self.zoomIn = MakeZoomButton("MiniMapZoomIn", "+", self.zoomOut, zoomSpacing)

    self.worldMapOverlay = WorldMapOverlay
    self.worldMapOverlay:Init()
end

---Recalculate minimap size, position, zoom, and relay out all child elements.
function MiniMap:ApplyLayout()
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local size = math.floor(math.min(screenWidth, screenHeight) * self.saved.sizePercent / 100)
    local corner = CORNERS[self.saved.corner] or CORNERS.topright

    self.size = MiniMapRenderUtils.Clamp(size, 96, 480)
    local zoomT = MiniMapRenderUtils.Clamp((self.saved.zoom - MINIMAP_ZOOM_MIN) / (MINIMAP_ZOOM_MAX - MINIMAP_ZOOM_MIN), 0, 1)
    local effectiveZoom = self.isCityMap and MINIMAP_CITY_ZOOM or ZoomFromUI(zoomT)
    self.mapSize = self.size * effectiveZoom

    self.root:ClearAnchors()
    self.root:SetAnchor(corner.anchor, GuiRoot, corner.relative, corner.x, corner.y)
    self.root:SetDimensions(self.size, self.size)
    self.border:SetDimensions(self.size, self.size)
    self.map:SetDimensions(self.mapSize, self.mapSize)
    self.root:SetAlpha(MiniMapRenderUtils.Clamp(self.saved.opacity or DEFAULTS.opacity, MINIMAP_OPACITY_MIN, MINIMAP_OPACITY_MAX) / 100)
    self:ApplyCircularClip()

    local playerSize = MiniMapRenderUtils.Clamp(math.floor(self.size * MINIMAP_SIZE_FACTOR_PLAYER), 18, 30)
    self.player:SetDimensions(playerSize, playerSize)

    if self.spotRenderer then
        self.spotRenderer:ApplyLayout(self.size)
    end
    if self.indicatorRenderer then
        self.indicatorRenderer:ApplyLayout(self.size)
    end

    self:ApplyToolbarLayout()
    self:ApplyZoomBarLayout()

    self:LayoutTiles()
    self:UpdatePlayer()

    self:UpdateToolbarVisibility()

    if self.noteRenderer then
        local noteCount = NoteDatabase:GetNoteCount()
        self.noteRenderer:ApplyLayout(noteCount)
        self.noteRenderer:Update(noteCount)
    end
end

---Apply a circular clip mask to the minimap root, if supported.
function MiniMap:ApplyCircularClip()
    if not self.root.SetCircularClip then
        return
    end

    local centerX, centerY = self.root:GetCenter()
    if centerX and centerY then
        self.root:SetCircularClip(centerX, centerY, self.size / 2)
    end
end

---Position the toolbar at the bottom centre of the screen.
function MiniMap:ApplyToolbarLayout()
    if not self.toolbar then
        return
    end

    self.toolbar:ClearAnchors()
    self.toolbar:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -84)
end

---Position the zoom bar above the minimap.
function MiniMap:ApplyZoomBarLayout()
    if not self.zoomBar then
        return
    end

    self.zoomBar:ClearAnchors()
    self.zoomBar:SetAnchor(BOTTOM, self.root, TOP, 0, -2)
    self.zoomBar:SetAlpha(MiniMapRenderUtils.Clamp(self.saved.opacity or DEFAULTS.opacity, 20, 100) / 100)
end

---Check whether the HUD (or HUD UI) scene is currently showing.
---@return boolean True if the HUD is visible.
function MiniMap:IsHudShowing()
    if not SCENE_MANAGER or not SCENE_MANAGER.GetScene then
        return true
    end

    local hudScene = SCENE_MANAGER:GetScene("hud")
    local huduiScene = SCENE_MANAGER:GetScene("hudui")
    local hudShown = hudScene and hudScene.IsShowing and hudScene:IsShowing()
    local huduiShown = huduiScene and huduiScene.IsShowing and huduiScene:IsShowing()
    return hudShown or huduiShown
end

---Show or hide the toolbar and zoom bar based on HUD and pointer mode state.
---@param isHudShowing boolean|nil Override for HUD visibility (auto-detected if nil).
function MiniMap:UpdateToolbarVisibility(isHudShowing)
    if not self.toolbar then
        return
    end

    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    isHudShowing = (isHudShowing ~= false)
    local isPointerMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive()
    local wantsVisible = self.saved.showToolbar and isPointerMode and isHudShowing and not self.saved.hidden

    if not wantsVisible then
        self.toolbarVisibleSinceMs = nil
        self.toolbar:SetHidden(true)
    else
        self.toolbarVisibleSinceMs = self.toolbarVisibleSinceMs or now
        self.toolbar:SetHidden(now - self.toolbarVisibleSinceMs < 150)
    end

    if self.zoomBar then
        self.zoomBar:SetHidden(not isHudShowing or self.saved.hidden)
    end
end

---Look up a localised string via the locale system.
---@param key string The locale string key.
---@return string The translated text.
function MiniMap:Text(key)
    return Locale.GetString(key)
end

---Get the nearest resource spot position for a given category.
---@param category string Resource category key.
---@return number|nil x World X coordinate of the spot.
---@return number|nil y World Y coordinate of the spot.
function MiniMap:GetNearestResourceSpot(category)
    if not self.saved.showResourceIndicators then
        return nil
    end

    local px, py = self.playerMapX, self.playerMapY
    if not px or not py then
        return nil
    end

    local spot = SpotDatabase:GetNearestSpot(px, py, category, 1, self.currentMapKey)
    if spot then
        return spot.x, spot.y
    end

    return nil
end

---Update all map overlays: resource spots, route, and edge indicators.
---@param playerX number Normalised player X.
---@param playerY number Normalised player Y.
---@param mapRotation number Map rotation in radians.
function MiniMap:UpdateMapOverlays(playerX, playerY, mapRotation)
    local radius = self.size / 2
    local center = radius
    local margin = self.spotRenderer:GetMargin()

    self.spotRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, self.currentMapKey)
    self.routeRenderer:Update(playerX, playerY, mapRotation, center, radius, self.currentMapKey)

    local objectives = self:GetAllQuestTargetPositions()
    self.indicatorRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, self.mapSize, objectives, self.nearestQuestShortcutX, self.nearestQuestShortcutY)
end

---Position and texture all map tiles, creating or hiding controls as needed.
function MiniMap:LayoutTiles()
    if not self.numHorizontalTiles or not self.numVerticalTiles then
        return
    end

    local tileWidth = self.mapSize / self.numHorizontalTiles
    local tileHeight = self.mapSize / self.numVerticalTiles
    local neededTiles = self.numHorizontalTiles * self.numVerticalTiles

    for index = 1, neededTiles do
        local tile = self.tiles[index]
        if not tile then
            tile = WINDOW_MANAGER:CreateControl("MiniMapTile" .. index, self.map, CT_TEXTURE)
            tile:SetDrawLayer(DL_BACKGROUND)
            self.tiles[index] = tile
        end

        local x = (index - 1) % self.numHorizontalTiles
        local y = math.floor((index - 1) / self.numHorizontalTiles)

        tile:ClearAnchors()
        tile:SetAnchor(TOPLEFT, self.map, TOPLEFT, x * tileWidth, y * tileHeight)
        tile:SetDimensions(tileWidth, tileHeight)
        tile:SetTexture(GetMapTileTexture(index))
        tile:SetHidden(false)
    end

    for index = neededTiles + 1, #self.tiles do
        self.tiles[index]:SetHidden(true)
    end
end

---Refresh the map tiles and layout. Optionally force a full reload even if nothing changed.
---@param force boolean If true, skip throttle and reload unconditionally.
---@return boolean True if the map was successfully displayed.
function MiniMap:RefreshMap(force)
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if not force and now < self.nextMapRefreshMs then
        return true
    end

    self.nextMapRefreshMs = now + MINIMAP_REFRESH_MS

    local mapType = GetMapType and GetMapType() or MAPTYPE_ZONE
    self.isCityMap = (mapType == MAPTYPE_SUBZONE or GetMapContentType and GetMapContentType() == MAP_CONTENT_HOUSE)

    local mapKey = MiniMapRenderUtils.GetCurrentMapKey()
    local numHorizontalTiles, numVerticalTiles = 0, 0

    if not mapKey then
        self.root:SetHidden(true)
        return false
    end

    if GetMapNumTiles then
        numHorizontalTiles, numVerticalTiles = GetMapNumTiles()
    end

    if not numHorizontalTiles or not numVerticalTiles or numHorizontalTiles == 0 or numVerticalTiles == 0 then
        self.root:SetHidden(true)
        return false
    end

    if force
        or mapKey ~= self.currentMapKey
        or mapType ~= self.currentMapType
        or numHorizontalTiles ~= self.numHorizontalTiles
        or numVerticalTiles ~= self.numVerticalTiles
    then
        self.currentMapKey = mapKey
        self.currentMapType = mapType
        self.numHorizontalTiles = numHorizontalTiles
        self.numVerticalTiles = numVerticalTiles
        self:LayoutTiles()
        self:ApplyLayout()
    end

    self.root:SetHidden(self.saved.hidden)
    return true
end

---Check whether the world map scene is currently showing.
---@return boolean True if the world map is open.
function MiniMap:IsWorldMapShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene("worldMap")
    return scene and scene:IsShowing()
end

---Set map to player location and refresh tiles.
---@param force boolean Passed through to RefreshMap.
---@return boolean True if refresh succeeded.
function MiniMap:RefreshMapToPlayerLocation(force)
    if SetMapToPlayerLocation and not self:IsWorldMapShowing() then
        local result = SetMapToPlayerLocation()
        if result == SET_MAP_RESULT_MAP_CHANGED and CALLBACK_MANAGER then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end

    return self:RefreshMap(force)
end

---Throttled check: refresh map only if enough time has passed since the last probe.
function MiniMap:RefreshMapIfPlayerLocationChanged()
    if self:IsWorldMapShowing() then
        return
    end

    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if now >= (self.nextLocationProbeMs or 0) then
        self.nextLocationProbeMs = now + MINIMAP_LOCATION_PROBE_MS
        self:RefreshMapToPlayerLocation(false)
    end
end

---Update player position, map pan, rotation, and all overlays every frame.
function MiniMap:UpdatePlayer()
    if not self.root or self.saved.hidden then
        return
    end

    if not self:RefreshMap(false) then
        return
    end

    local normalizedX, normalizedY, heading = GetMapPlayerPosition("player")
    if not normalizedX or normalizedX <= 0 or normalizedY <= 0 then
        self.root:SetHidden(true)
        return
    end

    self.root:SetHidden(false)
    self:ApplyCircularClip()
    self.playerMapX = normalizedX
    self.playerMapY = normalizedY

    local x = (0.5 * self.size) - (normalizedX * self.mapSize)
    local y = (0.5 * self.size) - (normalizedY * self.mapSize)
    self.map:ClearAnchors()
    self.map:SetAnchor(TOPLEFT, self.root, TOPLEFT, x, y)

    if self.map.SetTransformNormalizedOriginPoint then
        self.map:SetTransformNormalizedOriginPoint(normalizedX, normalizedY)
    end

    local mapRotation = 0
    if self.saved.orientation == "player" then
        mapRotation = -(GetPlayerCameraHeading and GetPlayerCameraHeading() or 0)
    end

    if self.map.SetTransformRotationZ then
        self.map:SetTransformRotationZ(mapRotation)
    elseif self.map.SetTextureRotation then
        self.map:SetTextureRotation(mapRotation, normalizedX, normalizedY)
    end

    local elementRotation = 0
    if self.saved.orientation == "player" then
        elementRotation = (GetPlayerCameraHeading and GetPlayerCameraHeading() or 0)
    end
    self:UpdateMapOverlays(normalizedX, normalizedY, elementRotation)

    if self.player.SetTextureRotation then
        if self.saved.orientation == "player" then
            self.player:SetTextureRotation(0)
        else
            self.player:SetTextureRotation(GetPlayerCameraHeading() or 0)
        end
    end
end

---Print the full help/command reference to chat.
function MiniMap:ShowHelp()
    local helpLines = {
        "helpHeader",
        "helpOverview",
        "helpResources",
        "helpRoutes",
        "helpNotes",
        "helpCommandsTitle",
        "helpSettings",
        "helpCorner",
        "helpSize",
        "helpOrientation",
        "helpOpacity",
        "helpZoom",
        "helpVisibility",
        "helpAdd",
        "helpSpots",
        "helpClear",
        "helpClean",
        "helpPosition",
        "helpRoute",
        "helpRouteClear",
        "helpRouteInfo",
        "helpClosestQuest",
        "helpResearch",
        "helpResearchSort",
    }

    for _, key in ipairs(helpLines) do
        Echo(self:Text(key))
    end
end
