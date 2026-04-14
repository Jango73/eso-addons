local ADDON_NAME = "MiniMap"

local DEFAULTS = {
    corner = "bottomright",
    sizePercent = 22,
    orientation = "north",
    zoom = 6,
    opacity = 100,
    debug = false,
    hidden = false,
    showResourceIndicators = true,
}

local SpotMarker_ = "SpotMarker"

local SIZE_FACTOR_PLAYER = 0.1
local SIZE_FACTOR_SPOT_MARKER = 0.045
local SIZE_FACTOR_EDGE_INDICATOR = 0.08

local SpotDatabase = {
    _data = nil,
}
SpotDatabase.__index = SpotDatabase

local RESOURCE_CATEGORIES = {
    { key = "blacksmithing", color = { 1, 0.5, 0, 1 } },
    { key = "clothier", color = { 0.8, 0.6, 0.4, 1 } },
    { key = "woodworking", color = { 0.6, 0.4, 0.2, 1 } },
    { key = "jewelrycrafter", color = { 0.9, 0.7, 0.2, 1 } },
    { key = "wood", color = { 0.5, 0.35, 0.15, 1 } },
    { key = "rune_refreme", color = { 0.5, 0.2, 1, 1 } },
    { key = "alchemy", color = { 0.2, 0.8, 0.2, 1 } },
    { key = "poison", color = { 0.4, 0.8, 0.4, 1 } },
    { key = "treasure", color = { 1, 0.84, 0, 1 } },
}

local EDGE_INDICATOR_TEXTURE = "MiniMap\\media\\edge_indicator_triangle.dds"

function SpotDatabase:Init(savedVars)
    self._data = savedVars
end

function SpotDatabase:AddSpot(x, y, category, mapName)
    if not self._data then
        Print("ERROR: SpotDatabase not initialized!")
        return false
    end
    if not x or not y or not category then return false end
    if not self._data[category] then self._data[category] = {} end

    local threshold = 0.0001
    local thresholdSq = threshold * threshold
    local currentMap = mapName or GetMapName()

    for i, s in ipairs(self._data[category]) do
        if s.map == currentMap then
            local dx = s.x - x
            local dy = s.y - y
            if (dx * dx + dy * dy) <= thresholdSq then
                self._data[category][i] = { x = x, y = y, map = currentMap, ts = GetTimeStamp() }
                return true
            end
        end
    end

    table.insert(self._data[category], { x = x, y = y, map = currentMap, ts = GetTimeStamp() })
    return true
end

function SpotDatabase:GetNearestSpot(px, py, category, maxCount, mapName)
    if not px or not py then return nil end
    maxCount = maxCount or 1
    local spots = self._data[category] or {}
    local currentMap = mapName or GetMapName()

    local best = nil
    local bestDistSq = nil

    for _, s in ipairs(spots) do
        if s.map == currentMap then
            local dx, dy = s.x - px, s.y - py
            local distSq = (dx * dx) + (dy * dy)
            if not bestDistSq or distSq < bestDistSq then
                best = s
                bestDistSq = distSq
            end
        end
    end

    if best then
        return { x = best.x, y = best.y, category = category, distance = math.sqrt(bestDistSq) }
    end
    return nil
end

function SpotDatabase:GetNearestSpotByCategory(px, py, maxCount, mapName)
    if not px or not py then return {} end
    maxCount = maxCount or 1
    local currentMap = mapName or GetMapName()
    local results = {}
    for cat, _ in pairs(self._data) do
        if type(cat) == "string" then
            local nearest = self:GetNearestSpot(px, py, cat, 1, currentMap)
            if nearest then table.insert(results, nearest) end
        end
    end
    table.sort(results, function(a, b) return (a.distance or 0) < (b.distance or 0) end)
    return results
end

function SpotDatabase:Clear(category)
    if category then self._data[category] = {}
    else for k in pairs(self._data) do if type(k) == "string" then self._data[k] = {} end end end
end

function SpotDatabase:GetSpotCount(category)
    if category then return #(self._data[category] or {}) end
    local t = 0
    for k, v in pairs(self._data) do
        if type(k) == "string" and type(v) == "table" then t = t + #v end
    end
    return t
end

local CORNERS = {
    topleft = { anchor = TOPLEFT, relative = TOPLEFT, x = 24, y = 24 },
    topright = { anchor = TOPRIGHT, relative = TOPRIGHT, x = -24, y = 24 },
    bottomleft = { anchor = BOTTOMLEFT, relative = BOTTOMLEFT, x = 24, y = -24 },
    bottomright = { anchor = BOTTOMRIGHT, relative = BOTTOMRIGHT, x = -24, y = -24 },
    left = { anchor = LEFT, relative = LEFT, x = 24, y = 0 },
    right = { anchor = RIGHT, relative = RIGHT, x = -24, y = 0 },
    top = { anchor = TOP, relative = TOP, x = 0, y = 24 },
    bottom = { anchor = BOTTOM, relative = BOTTOM, x = 0, y = -24 },
}

local STRINGS = {
    en = {
        helpCorner = "/minimap corner tl|tr|bl|br|left|right|top|bottom",
        helpSize = "/minimap size 10-40",
        helpOrientation = "/minimap orientation north|player",
        helpOpacity = "/minimap opacity 20-100",
        helpZoom = "/minimap zoom 2-8",
        helpVisibility = "/minimap hide | /minimap show",
        settingsMissing = "LibAddonMenu-2.0 is missing: the settings menu will not be created.",
        positionName = "Position",
        positionTooltip = "Minimap position on the screen.",
        positionTopLeft = "Top left",
        positionTopRight = "Top right",
        positionBottomLeft = "Bottom left",
        positionBottomRight = "Bottom right",
        positionLeft = "Center left",
        positionRight = "Center right",
        positionTop = "Top center",
        positionBottom = "Bottom center",
        sizeName = "Size",
        sizeTooltip = "Percentage of the screen's smallest dimension.",
        orientationName = "Orientation",
        orientationTooltip = "Choose whether north or the player direction stays at the top.",
        orientationNorth = "North up",
        orientationPlayer = "Player direction up",
        opacityName = "Opacity",
        opacityTooltip = "Minimap opacity.",
        invalidPosition = "Invalid position. Use tl, tr, bl, br, left, right, top or bottom.",
        positionChanged = "Position: %s",
        invalidSize = "Invalid size. Example: /minimap size 22",
        sizeChanged = "Size: %s%%",
        invalidOrientation = "Invalid orientation. Use north or player.",
        orientationChanged = "Orientation: %s",
        invalidOpacity = "Invalid opacity. Example: /minimap opacity 80",
        opacityChanged = "Opacity: %s%%",
        invalidZoom = "Invalid zoom. Example: /minimap zoom 6",
        zoomChanged = "Zoom: %s",
        hidden = "Hidden.",
        shown = "Shown.",
    },
    fr = {
        helpCorner = "/minimap corner tl|tr|bl|br|left|right|top|bottom",
        helpSize = "/minimap size 10-40",
        helpOrientation = "/minimap orientation north|player",
        helpOpacity = "/minimap opacity 20-100",
        helpZoom = "/minimap zoom 2-8",
        helpVisibility = "/minimap hide | /minimap show",
        settingsMissing = "LibAddonMenu-2.0 est introuvable: le menu de settings ne sera pas cree.",
        positionName = "Position",
        positionTooltip = "Position de la minimap sur l'ecran.",
        positionTopLeft = "Haut gauche",
        positionTopRight = "Haut droite",
        positionBottomLeft = "Bas gauche",
        positionBottomRight = "Bas droite",
        positionLeft = "Centre gauche",
        positionRight = "Centre droite",
        positionTop = "Centre haut",
        positionBottom = "Centre bas",
        sizeName = "Taille",
        sizeTooltip = "Pourcentage de la plus petite dimension de l'ecran.",
        orientationName = "Orientation",
        orientationTooltip = "Choisit si le nord ou la direction du joueur reste en haut.",
        orientationNorth = "Nord en haut",
        orientationPlayer = "Direction du joueur en haut",
        opacityName = "Transparence",
        opacityTooltip = "Opacite de la minimap.",
        invalidPosition = "Position invalide. Utilise tl, tr, bl, br, left, right, top ou bottom.",
        positionChanged = "Position: %s",
        invalidSize = "Taille invalide. Exemple: /minimap size 22",
        sizeChanged = "Taille: %s%%",
        invalidOrientation = "Orientation invalide. Utilise north ou player.",
        orientationChanged = "Orientation: %s",
        invalidOpacity = "Opacite invalide. Exemple: /minimap opacity 80",
        opacityChanged = "Opacite: %s%%",
        invalidZoom = "Zoom invalide. Exemple: /minimap zoom 6",
        zoomChanged = "Zoom: %s",
        hidden = "Masquee.",
        shown = "Affichee.",
    },
}

local MiniMap = {
    tiles = {},
    edgeIndicators = {},
    edgeIndicatorOrder = {},
    tileCount = 0,
    currentMapName = nil,
    nextMapRefreshMs = 0,
    nextQuestBreadcrumbRefreshMs = 0,
}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
end

local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
    end
end

local function GetLanguage()
    local language = GetCVar and GetCVar("Language.2") or nil
    language = zo_strlower(language or "")

    if string.sub(language, 1, 2) == "fr" then
        return "fr"
    end

    return "en"
end

local function GetRotationFromUp(dx, dy)
    if math.atan2 then
        return math.atan2(dx, dy)
    end

    return math.atan(dx, dy)
end

local function RotateVector(x, y, radians)
    if radians == 0 then
        return x, y
    end

    local cos = math.cos(radians)
    local sin = math.sin(radians)
    return (x * cos) - (y * sin), (x * sin) + (y * cos)
end

local function NormalizeCorner(value)
    value = zo_strlower(value or "")

    if value == "tl" or value == "hg" or value == "hautgauche" or value == "top-left" then
        return "topleft"
    elseif value == "tr" or value == "hd" or value == "hautdroite" or value == "top-right" then
        return "topright"
    elseif value == "bl" or value == "bg" or value == "basgauche" or value == "bottom-left" then
        return "bottomleft"
    elseif value == "br" or value == "bd" or value == "basdroite" or value == "bottom-right" then
        return "bottomright"
    elseif value == "left" or value == "gauche" or value == "milieugauche" or value == "centre-gauche" then
        return "left"
    elseif value == "right" or value == "droite" or value == "milieudroite" or value == "centre-droite" then
        return "right"
    elseif value == "top" or value == "haut" or value == "milieuhaut" or value == "centre-haut" then
        return "top"
    elseif value == "bottom" or value == "bas" or value == "milieubas" or value == "centre-bas" then
        return "bottom"
    end

    return CORNERS[value] and value or nil
end

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
    background:SetEdgeColor(0, 0, 0, 0.85)
    background:SetEdgeTexture("", 1, 1, 2)

    local map = WINDOW_MANAGER:CreateControl("MiniMapMap", root, CT_CONTROL)
    map:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    if map.SetTransformNormalizedOriginPoint then
        map:SetTransformNormalizedOriginPoint(0.5, 0.5)
    end

    local player = WINDOW_MANAGER:CreateControl("MiniMapPlayer", root, CT_TEXTURE)
    player:SetAnchor(CENTER, root, CENTER, 0, 0)
    player:SetDimensions(24, 24)
    player:SetTexture("EsoUI/Art/Icons/mapKey/mapKey_player.dds")
    player:SetDrawLayer(DL_OVERLAY)

    local debugWindow = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapDebugWindow")
    debugWindow:SetDrawTier(DT_HIGH)
    debugWindow:SetMouseEnabled(false)
    debugWindow:SetHidden(true)

    local debugBackground = WINDOW_MANAGER:CreateControl("MiniMapDebugBackground", debugWindow, CT_BACKDROP)
    debugBackground:SetAnchorFill(debugWindow)
    debugBackground:SetCenterColor(0, 0, 0, 0.78)
    debugBackground:SetEdgeColor(1, 1, 1, 0.6)
    debugBackground:SetEdgeTexture("", 1, 1, 1)

    local debugLabel = WINDOW_MANAGER:CreateControl("MiniMapDebugLabel", debugWindow, CT_LABEL)
    debugLabel:SetAnchor(TOPLEFT, debugWindow, TOPLEFT, 8, 8)
    debugLabel:SetFont("ZoFontGame")
    debugLabel:SetColor(1, 1, 1, 1)
    debugLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    debugLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)

    self.root = root
    self.background = background
    self.map = map
    self.player = player
    self.debugWindow = debugWindow
    self.debugBackground = debugBackground
    self.debugLabel = debugLabel

    self.spotMarkers = {}
    self.spotMarkersInitialized = false

    self:RegisterEdgeIndicator("activeQuest", {
        color = { 1, 1, 1, 1 },
        provider = function()
            return self:GetActiveQuestTargetPosition()
        end,
    })

    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        self:RegisterEdgeIndicator(cat.key, {
            color = cat.color,
            provider = (function(category)
                return function()
                    return self:GetNearestResourceSpot(category)
                end
            end)(cat.key),
        })
    end
end

function MiniMap:ApplyLayout()
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local size = math.floor(math.min(screenWidth, screenHeight) * self.saved.sizePercent / 100)
    local corner = CORNERS[self.saved.corner] or CORNERS.topright

    self.size = Clamp(size, 96, 480)
    self.mapSize = self.size * self.saved.zoom

    self.root:ClearAnchors()
    self.root:SetAnchor(corner.anchor, GuiRoot, corner.relative, corner.x, corner.y)
    self.root:SetDimensions(self.size, self.size)
    self.map:SetDimensions(self.mapSize, self.mapSize)
    self.root:SetAlpha(Clamp(self.saved.opacity or DEFAULTS.opacity, 20, 100) / 100)
    self:ApplyDebugLayout()
    self:ApplyCircularClip()

    local playerSize = Clamp(math.floor(self.size * SIZE_FACTOR_PLAYER), 18, 30)
    self.player:SetDimensions(playerSize, playerSize)

    self.spotMarkerSize = Clamp(math.floor(self.size * SIZE_FACTOR_SPOT_MARKER), 9, 15)

    for _, indicator in pairs(self.edgeIndicators) do
        indicator.control:SetDimensions(playerSize, playerSize)
    end

    self:LayoutTiles()
    self:UpdatePlayer()
end

function MiniMap:ApplyDebugLayout()
    if not self.debugWindow then
        return
    end

    self.debugWindow:ClearAnchors()
    self.debugWindow:SetAnchor(TOPRIGHT, self.root, BOTTOMRIGHT, 0, 12)
    self.debugWindow:SetDimensions(760, 260)
    self.debugLabel:SetDimensions(744, 244)
end

function MiniMap:ApplyCircularClip()
    if not self.root.SetCircularClip then
        return
    end

    local centerX, centerY = self.root:GetCenter()
    if centerX and centerY then
        self.root:SetCircularClip(centerX, centerY, self.size / 2)
    end
end

function MiniMap:Text(key)
    local strings = STRINGS[self.language] or STRINGS.en
    return strings[key] or STRINGS.en[key] or key
end

function MiniMap:SetQuestDebug(values)
    self.questDebug = values
    self:UpdateDebugLabel()
end

function MiniMap:UpdateDebugLabel()
    if not self.debugWindow or not self.debugLabel then
        return
    end

    if not self.saved or not self.saved.debug then
        self.debugWindow:SetHidden(true)
        return
    end

    local debug = self.questDebug or {}
    local spotInfo = ""
    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        spotInfo = spotInfo .. string.format("%s=%d ", cat.key, SpotDatabase:GetSpotCount(cat.key))
    end
    local text = string.format(
        "MiniMap debug\nSpots: %s\nmap=%s\nquest=%s\nplayer=%.4f,%.4f target=%s",
        spotInfo,
        tostring(self.currentMapName or ""),
        tostring(debug.questIndex or "nil"),
        debug.playerX or 0,
        debug.playerY or 0,
        debug.target and string.format("%.4f,%.4f", debug.targetX, debug.targetY) or "nil"
    )

    self.debugLabel:SetText(text)
    self.debugWindow:SetHidden(false)
end

function MiniMap:RegisterEdgeIndicator(id, options)
    local indicator = self.edgeIndicators[id]
    if not indicator then
        local control = WINDOW_MANAGER:CreateControl("MiniMapEdgeIndicator" .. id, self.root, CT_TEXTURE)
        control:SetTexture(EDGE_INDICATOR_TEXTURE)
        control:SetDrawLayer(DL_OVERLAY)
        control:SetHidden(true)

        indicator = {
            control = control,
        }
        self.edgeIndicators[id] = indicator
        self.edgeIndicatorOrder[#self.edgeIndicatorOrder + 1] = id
    end

    indicator.provider = options.provider
    indicator.color = options.color or { 1, 1, 1, 1 }

    indicator.control:SetColor(indicator.color[1], indicator.color[2], indicator.color[3], indicator.color[4] or 1)
end

function MiniMap:GetFocusedQuestIndex()
    if QUEST_JOURNAL_MANAGER and QUEST_JOURNAL_MANAGER.GetFocusedQuestIndex then
        local questIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
        if questIndex then
            return questIndex
        end
    end

    if GetNumTracked and GetTrackedByIndex and GetTrackedIsAssisted then
        local numTracked = GetNumTracked()
        for index = 1, numTracked do
            local trackType, arg1, arg2 = GetTrackedByIndex(index)
            if GetTrackedIsAssisted(trackType, arg1, arg2) then
                return arg1
            end
        end
    end

    return nil
end

function MiniMap:GetActiveQuestTargetPosition()
    local questIndex = self:GetFocusedQuestIndex()
    local debug = {
        questIndex = questIndex,
        hasBreadcrumbs = WORLD_MAP_QUEST_BREADCRUMBS ~= nil,
        playerX = self.playerMapX or 0,
        playerY = self.playerMapY or 0,
        steps = 0,
        positions = 0,
        inside = 0,
        refreshed = false,
        target = false,
    }

    if not questIndex or not WORLD_MAP_QUEST_BREADCRUMBS or not self.playerMapX or not self.playerMapY then
        self:SetQuestDebug(debug)
        return nil
    end

    local bestX, bestY
    local bestDistanceSq
    local mainStepIndex = QUEST_MAIN_STEP_INDEX or 1
    local numSteps = GetJournalQuestNumSteps and GetJournalQuestNumSteps(questIndex) or mainStepIndex
    debug.steps = numSteps

    for stepIndex = mainStepIndex, numSteps do
        local numPositions = WORLD_MAP_QUEST_BREADCRUMBS:GetNumQuestConditionPositions(questIndex, stepIndex)
        if numPositions then
            debug.positions = debug.positions + numPositions
            for conditionIndex = 1, numPositions do
                local positionData = WORLD_MAP_QUEST_BREADCRUMBS:GetQuestConditionPosition(questIndex, stepIndex, conditionIndex)
                if positionData and positionData.insideCurrentMapWorld and positionData.xLoc and positionData.yLoc then
                    debug.inside = debug.inside + 1
                    local dx = positionData.xLoc - self.playerMapX
                    local dy = positionData.yLoc - self.playerMapY
                    local distanceSq = (dx * dx) + (dy * dy)
                    if not bestDistanceSq or distanceSq < bestDistanceSq then
                        bestDistanceSq = distanceSq
                        bestX = positionData.xLoc
                        bestY = positionData.yLoc
                    end
                end
            end
        end
    end

    if bestX and bestY then
        debug.target = true
        debug.targetX = bestX
        debug.targetY = bestY
        self:SetQuestDebug(debug)
        return bestX, bestY
    end

    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if WORLD_MAP_QUEST_BREADCRUMBS.RefreshQuest and now >= self.nextQuestBreadcrumbRefreshMs then
        self.nextQuestBreadcrumbRefreshMs = now + 3000
        WORLD_MAP_QUEST_BREADCRUMBS:RefreshQuest(questIndex)
        debug.refreshed = true
    end

    self:SetQuestDebug(debug)
    return nil
end

function MiniMap:GetNearestResourceSpot(category)
    if not self.saved.showResourceIndicators then
        return nil
    end

    local px, py = self.playerMapX, self.playerMapY
    if not px or not py then
        return nil
    end

    local spot = SpotDatabase:GetNearestSpot(px, py, category, 1, self.currentMapName)
    if spot then
        return spot.x, spot.y
    end

    return nil
end

function MiniMap:UpdateEdgeIndicators(playerX, playerY, mapRotation)
    local radius = self.size / 2
    local center = radius
    local markerSize = Clamp(math.floor(self.size * SIZE_FACTOR_EDGE_INDICATOR), 18, 32)
    local margin = self.spotMarkerSize

    self:UpdateSpotMarkers(playerX, playerY, mapRotation, center, radius, margin)

    for _, id in ipairs(self.edgeIndicatorOrder) do
        local indicator = self.edgeIndicators[id]
        local targetX, targetY = indicator.provider()

        if targetX and targetY then
            local dx = (targetX - playerX) * self.mapSize
            local dy = (targetY - playerY) * self.mapSize
            dx, dy = RotateVector(dx, dy, mapRotation)

            local localX = center + dx
            local localY = center + dy
            local distFromCenter = math.sqrt((localX - center) ^ 2 + (localY - center) ^ 2)

            if distFromCenter < (radius - margin) then
                indicator.control:SetHidden(true)
            else
                local length = math.sqrt((dx * dx) + (dy * dy))
                if length > 0.0001 then
                    local unitX = dx / length
                    local unitY = dy / length
                    local edgeRadius = radius - (markerSize * 0.34)

                    indicator.control:SetDimensions(markerSize, markerSize)
                    indicator.control:ClearAnchors()
                    indicator.control:SetAnchor(CENTER, self.root, TOPLEFT, center + (unitX * edgeRadius), center + (unitY * edgeRadius))

                    if indicator.control.SetTextureRotation then
                        indicator.control:SetTextureRotation(GetRotationFromUp(unitX, unitY))
                    end

                    indicator.control:SetHidden(false)
                else
                    indicator.control:SetHidden(true)
                end
            end
        else
            indicator.control:SetHidden(true)
        end
    end
end

function MiniMap:UpdateSpotMarkers(playerX, playerY, mapRotation, center, radius, margin)
    if not self.spotMarkersInitialized then
        local MAX_MARKERS_PER_CAT = 10
        for _, cat in ipairs(RESOURCE_CATEGORIES) do
            self.spotMarkers[cat.key] = {}
            for i = 1, MAX_MARKERS_PER_CAT do
                local controlName = self.root:GetName() .. SpotMarker_ .. cat.key .. i
                local control = WINDOW_MANAGER:CreateControl(controlName, self.root, CT_BACKDROP)
                control:SetDrawLayer(DL_OVERLAY)
                control:SetCenterColor(cat.color[1], cat.color[2], cat.color[3], 1)
                control:SetEdgeColor(0, 0, 0, 1)
                control:SetEdgeTexture(nil, 1, 1, 2)
                control:SetHidden(true)
                self.spotMarkers[cat.key][i] = control
            end
        end
        self.spotMarkersInitialized = true
    end

    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        local markers = self.spotMarkers[cat.key]
        local spots = SpotDatabase._data[cat.key] or {}
        local markerIndex = 1
        local currentMap = self.currentMapName

        for _, spot in ipairs(spots) do
            if spot.map == currentMap then
                local dx = (spot.x - playerX) * self.mapSize
                local dy = (spot.y - playerY) * self.mapSize
                dx, dy = RotateVector(dx, dy, mapRotation)

                local localX = center + dx
                local localY = center + dy
                local distFromCenter = math.sqrt((localX - center) ^ 2 + (localY - center) ^ 2)

                if distFromCenter < (radius - margin) and markerIndex <= #markers then
                    local marker = markers[markerIndex]
                    marker:ClearAnchors()
                    marker:SetAnchor(CENTER, self.root, TOPLEFT, localX, localY)
                    marker:SetDimensions(self.spotMarkerSize, self.spotMarkerSize)
                    marker:SetHidden(false)
                    markerIndex = markerIndex + 1
                end
            end
        end

        for i = markerIndex, #markers do
            markers[i]:SetHidden(true)
        end
    end
end

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

function MiniMap:RefreshMap(force)
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if not force and now < self.nextMapRefreshMs then
        return true
    end

    self.nextMapRefreshMs = now + 1000

    local mapName = GetMapName and GetMapName() or ""
    local numHorizontalTiles, numVerticalTiles = 0, 0

    if GetMapNumTiles then
        numHorizontalTiles, numVerticalTiles = GetMapNumTiles()
    end

    if not numHorizontalTiles or not numVerticalTiles or numHorizontalTiles == 0 or numVerticalTiles == 0 then
        self.root:SetHidden(true)
        return false
    end

    if force or mapName ~= self.currentMapName or numHorizontalTiles ~= self.numHorizontalTiles or numVerticalTiles ~= self.numVerticalTiles then
        self.currentMapName = mapName
        self.numHorizontalTiles = numHorizontalTiles
        self.numVerticalTiles = numVerticalTiles
        self:LayoutTiles()
    end

    self.root:SetHidden(self.saved.hidden)
    return true
end

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
        mapRotation = -(heading or GetPlayerCameraHeading and GetPlayerCameraHeading() or 0)
    end

    if self.map.SetTransformRotationZ then
        self.map:SetTransformRotationZ(mapRotation)
    elseif self.map.SetTextureRotation then
        self.map:SetTextureRotation(mapRotation, normalizedX, normalizedY)
    end

    self:UpdateEdgeIndicators(normalizedX, normalizedY, mapRotation)

    if self.player.SetTextureRotation then
        if self.saved.orientation == "player" then
            self.player:SetTextureRotation(0)
        else
            self.player:SetTextureRotation(heading or 0)
        end
    end
end

function MiniMap:ShowHelp()
    Print(self:Text("helpCorner"))
    Print(self:Text("helpSize"))
    Print(self:Text("helpOrientation"))
    Print(self:Text("helpOpacity"))
    Print(self:Text("helpZoom"))
    Print(self:Text("helpVisibility"))
    Print("/minimap debug")
    Print("/minimapsettings")
end

function MiniMap:RegisterSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        Print(self:Text("settingsMissing"))
        return
    end

    local panelData = {
        type = "panel",
        name = "MiniMap",
        displayName = "MiniMap",
        author = "Codex",
        version = "1.0.0",
        slashCommand = "/minimapsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        {
            type = "dropdown",
            name = self:Text("positionName"),
            tooltip = self:Text("positionTooltip"),
            choices = {
                self:Text("positionTopLeft"),
                self:Text("positionTopRight"),
                self:Text("positionBottomLeft"),
                self:Text("positionBottomRight"),
                self:Text("positionLeft"),
                self:Text("positionRight"),
                self:Text("positionTop"),
                self:Text("positionBottom"),
            },
            choicesValues = {
                "topleft",
                "topright",
                "bottomleft",
                "bottomright",
                "left",
                "right",
                "top",
                "bottom",
            },
            getFunc = function()
                return self.saved.corner
            end,
            setFunc = function(value)
                self.saved.corner = value
                self:ApplyLayout()
            end,
            default = DEFAULTS.corner,
            width = "full",
        },
        {
            type = "slider",
            name = self:Text("sizeName"),
            tooltip = self:Text("sizeTooltip"),
            min = 10,
            max = 40,
            step = 1,
            getFunc = function()
                return self.saved.sizePercent
            end,
            setFunc = function(value)
                self.saved.sizePercent = Clamp(value, 10, 40)
                self:ApplyLayout()
            end,
            default = DEFAULTS.sizePercent,
            width = "full",
        },
        {
            type = "dropdown",
            name = self:Text("orientationName"),
            tooltip = self:Text("orientationTooltip"),
            choices = { self:Text("orientationNorth"), self:Text("orientationPlayer") },
            choicesValues = { "north", "player" },
            getFunc = function()
                return self.saved.orientation
            end,
            setFunc = function(value)
                self.saved.orientation = value
                self:UpdatePlayer()
            end,
            default = DEFAULTS.orientation,
            width = "full",
        },
        {
            type = "slider",
            name = self:Text("opacityName"),
            tooltip = self:Text("opacityTooltip"),
            min = 20,
            max = 100,
            step = 5,
            getFunc = function()
                return self.saved.opacity or DEFAULTS.opacity
            end,
            setFunc = function(value)
                self.saved.opacity = Clamp(value, 20, 100)
                self.root:SetAlpha(self.saved.opacity / 100)
            end,
            default = DEFAULTS.opacity,
            width = "full",
        },
    }

    LAM:RegisterAddonPanel("MiniMapSettings", panelData)
    LAM:RegisterOptionControls("MiniMapSettings", optionsTable)
end

function MiniMap:HandleSlashCommand(arguments)
    local command, value = zo_strmatch(arguments or "", "^(%S*)%s*(.-)$")
    command = zo_strlower(command or "")
    value = zo_strlower(value or "")

    if command == "corner" or command == "position" then
        local corner = NormalizeCorner(value)
        if not corner then
            Print(self:Text("invalidPosition"))
            return
        end

        self.saved.corner = corner
        self:ApplyLayout()
        Print(string.format(self:Text("positionChanged"), corner))
    elseif command == "size" or command == "taille" then
        local sizePercent = tonumber(value)
        if not sizePercent then
            Print(self:Text("invalidSize"))
            return
        end

        self.saved.sizePercent = Clamp(sizePercent, 10, 40)
        self:ApplyLayout()
        Print(string.format(self:Text("sizeChanged"), self.saved.sizePercent))
    elseif command == "orientation" or command == "orient" then
        if value ~= "north" and value ~= "player" and value ~= "nord" and value ~= "joueur" then
            Print(self:Text("invalidOrientation"))
            return
        end

        self.saved.orientation = (value == "player" or value == "joueur") and "player" or "north"
        self:UpdatePlayer()
        Print(string.format(self:Text("orientationChanged"), self.saved.orientation))
    elseif command == "opacity" or command == "opacite" or command == "alpha" then
        local opacity = tonumber(value)
        if not opacity then
            Print(self:Text("invalidOpacity"))
            return
        end

        self.saved.opacity = Clamp(opacity, 20, 100)
        self.root:SetAlpha(self.saved.opacity / 100)
        Print(string.format(self:Text("opacityChanged"), self.saved.opacity))
    elseif command == "zoom" then
        local zoom = tonumber(value)
        if not zoom then
            Print(self:Text("invalidZoom"))
            return
        end

        self.saved.zoom = Clamp(zoom, 2, 8)
        self:ApplyLayout()
        Print(string.format(self:Text("zoomChanged"), self.saved.zoom))
    elseif command == "hide" or command == "masquer" then
        self.saved.hidden = true
        self.root:SetHidden(true)
        Print(self:Text("hidden"))
    elseif command == "show" or command == "afficher" then
        self.saved.hidden = false
        self:UpdatePlayer()
        Print(self:Text("shown"))
    elseif command == "debug" then
        self.saved.debug = not self.saved.debug
        self:UpdateDebugLabel()
        Print("Debug: " .. tostring(self.saved.debug))
    else
        self:ShowHelp()
    end
end

function MiniMap:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("MiniMapSavedVariables", 1, nil, DEFAULTS)

    local SPOT_DEFAULTS = {}
    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        SPOT_DEFAULTS[cat.key] = {}
    end
    self.spots = ZO_SavedVars:NewAccountWide("MiniMapSpots", 1, nil, SPOT_DEFAULTS)
    SpotDatabase:Init(self.spots)
    local count = SpotDatabase:GetSpotCount()

    self.language = GetLanguage()

    self:CreateControls()
    self:ApplyLayout()
    self:RefreshMap(true)
    self:RegisterSettingsMenu()

    SLASH_COMMANDS["/minimap"] = function(arguments)
        self:HandleSlashCommand(arguments)
    end

    local updateCounter = 0
    local lastMapOpen = false
    local function OnMinimapUpdate()
        MiniMap:UpdatePlayer()
        
        local sceneShown = false
        local scene = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene("worldMap")
        if scene then
            sceneShown = scene:IsShowing()
        end
        
        if sceneShown then
            MiniMap.root:SetHidden(true)
            lastMapOpen = true
        elseif not MiniMap.saved.hidden then
            MiniMap.root:SetHidden(false)
            if lastMapOpen then
                lastMapOpen = false
                SetMapToPlayerLocation()
                MiniMap:RefreshMap(true)
            end
        end
    end

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", 150, OnMinimapUpdate)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZONE_CHANGED", EVENT_ZONE_CHANGED, function()
        MiniMap:RefreshMap(true)
    end)

    local function GetResourceCategory(lootType)
        if lootType == 26 then return "blacksmithing"
        elseif lootType == 40 then return "clothier"
        elseif lootType == 37 then return "woodworking"
        elseif lootType == 0 then return "jewelrycrafter"
        elseif lootType == 15 then return "rune_refreme"
        elseif lootType == 23 then return "alchemy"
        elseif lootType == 0 then return "poison"
        elseif lootType == 0 then return "treasure"
        end
        return nil
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT", EVENT_LOOT_RECEIVED, function(eventCode, itemName, quantity, itemSound, lootType, lootedBySelf)
        Print("LOOT type=" .. lootType)
        local category = GetResourceCategory(lootType)
        Print("category=" .. tostring(category))
        if category then
            local x, y, _ = GetMapPlayerPosition("player")
            if x and y then
                SpotDatabase:AddSpot(x, y, category, self.currentMapName)
                Print("Saved " .. category .. " spot")
            end
        end
    end)

    local function AddCurrentSpot(category)
        local x, y, _ = GetMapPlayerPosition("player")
        if x and y then
            SpotDatabase:AddSpot(x, y, category, self.currentMapName)
            Print("Added " .. category .. " spot at " .. string.format("%.4f, %.4f", x, y))
        else
            Print("Cannot add spot: position unknown")
        end
    end

    local function IsValidCategory(cat)
        for _, c in ipairs(RESOURCE_CATEGORIES) do
            if c.key == cat then return true end
        end
        return false
    end

    SLASH_COMMANDS["/minimap_add"] = function(arguments)
        local category = zo_strlower(arguments or "")
        if IsValidCategory(category) then
            AddCurrentSpot(category)
        else
            local valid = ""
            for _, c in ipairs(RESOURCE_CATEGORIES) do
                valid = valid .. c.key .. "|"
            end
            Print("Usage: /minimap_add " .. valid:sub(1, -2))
        end
    end

    SLASH_COMMANDS["/minimap_spots"] = function(arguments)
        local total = SpotDatabase:GetSpotCount()
        Print("Total spots: " .. total)
        for _, cat in ipairs(RESOURCE_CATEGORIES) do
            local count = SpotDatabase:GetSpotCount(cat.key)
            Print("  " .. cat.key .. ": " .. count)
        end
    end

    SLASH_COMMANDS["/minimap_clear"] = function(arguments)
        local category = zo_strlower(arguments or "")
        if category == "all" then
            SpotDatabase:Clear()
            Print("All spots cleared")
        elseif IsValidCategory(category) then
            SpotDatabase:Clear(category)
            Print(category .. " spots cleared")
        else
            Print("Usage: /minimap_clear <category>|all")
        end
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    MiniMap:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
