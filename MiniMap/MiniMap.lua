
-- ==============================================================================
-- NOTES
-- ==============================================================================
-- 2026-04-15: SetTextureRotation bug at ±90° with edge_indicator_triangle.dds
-- Cause: DDS with mipmaps caused wrong LOD selection in game engine
-- Fix: recreate DDS texture WITHOUT mipmaps (ImageMagick: -define dds:mipmaps=0)
-- ==============================================================================

local ADDON_NAME = "MiniMap"
local SpotMarker_ = "SpotMarker"
local ROUTE_SEGMENT_MAX = 200

local MiniMap = {
    tiles = {},
    edgeIndicators = {},
    edgeIndicatorOrder = {},
    tileCount = 0,
    currentMapName = nil,
    nextMapRefreshMs = 0,
    nextQuestBreadcrumbRefreshMs = 0,
    isCityMap = false,
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
    if not MiniMap.debugLog then
        MiniMap.debugLog = {}
    end
    table.insert(MiniMap.debugLog, message)
    if #MiniMap.debugLog > 50 then
        table.remove(MiniMap.debugLog, 1)
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

local function PrintSpotAdded(category)
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, "Added a " .. category .. " spot")
end

local function PrintSpotDeleted(count)
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, string.format("%d spot(s) deleted", count))
end

local function IsValidCategory(cat)
    for _, c in ipairs(RESOURCE_CATEGORIES) do
        if c.key == cat then return true end
    end
    return false
end

local function GetPlayerMapPosition()
    local x, y, _ = GetMapPlayerPosition("player")
    return x, y
end

local function AddSpotAtPlayer(category)
    local x, y = GetPlayerMapPosition()
    if x and y then
        if SpotDatabase:AddSpot(x, y, category, MiniMap.currentMapName) then
            PrintSpotAdded(category)
            return true
        end
    end
    return false
end

local function ForEachCategory(callback)
    for _, cat in ipairs(RESOURCE_CATEGORIES) do
        callback(cat)
    end
end

local function WorldToLocal(targetX, targetY, playerX, playerY, mapSize, mapRotation, center)
    local dx = (targetX - playerX) * mapSize
    local dy = (targetY - playerY) * mapSize
    dx, dy = RotateVector(dx, dy, mapRotation)
    local localX = center + dx
    local localY = center + dy
    local distFromCenter = math.sqrt((localX - center) ^ 2 + (localY - center) ^ 2)
    return localX, localY, distFromCenter, dx, dy
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

    local toolbar = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapToolbar")
    toolbar:SetDrawTier(DT_HIGH)
    toolbar:SetClampedToScreen(true)
    toolbar:SetMouseEnabled(true)
    toolbar:SetHidden(true)

    local toolbarBg = WINDOW_MANAGER:CreateControl("MiniMapToolbarBg", toolbar, CT_BACKDROP)
    toolbarBg:SetAnchorFill(toolbar)
    toolbarBg:SetCenterColor(0, 0, 0, 0.7)
    toolbarBg:SetEdgeColor(0.5, 0.5, 0.5, 0.8)
    toolbarBg:SetEdgeTexture("", 1, 1, 2)

    local buttonSize = 32
    local buttonSpacing = 6
    local totalWidth = (#RESOURCE_CATEGORIES + 1) * (buttonSize + buttonSpacing) - buttonSpacing
    toolbar:SetDimensions(totalWidth, buttonSize + 12)

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

    local function CreateToolButton(index, cat)
        local btn = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtn" .. cat.key, toolbar, CT_BUTTON)
        btn:SetDimensions(buttonSize, buttonSize)

        local btnBg = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtn" .. cat.key .. "Bg", btn, CT_BACKDROP)
        btnBg:SetAnchorFill(btn)
        btnBg:SetCenterColor(cat.color[1], cat.color[2], cat.color[3], 0.7)
        btnBg:SetEdgeColor(cat.color[1], cat.color[2], cat.color[3], 1)
        btnBg:SetEdgeTexture("", 1, 1, 2)

        local btnLabel = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtn" .. cat.key .. "Label", btn, CT_LABEL)
        btnLabel:SetAnchor(CENTER, btn, CENTER, 0, 0)
        btnLabel:SetFont("ZoFontGameBold")
        btnLabel:SetColor(0, 0, 0, 1)
        btnLabel:SetText(string.upper(string.sub(cat.key, 1, 1)))

        btn:SetMouseOverTexture("EsoUI/Art/Buttons/left_up.dds")
        btn:SetHandler("OnClicked", function()
            AddSpotAtPlayer(cat.key)
        end)
        SetupButtonTooltip(btn, btnBg,
            { cat.color[1] * 0.7, cat.color[2] * 0.7, cat.color[3] * 0.7, 0.9 },
            { cat.color[1], cat.color[2], cat.color[3], 0.7 },
            "Add " .. cat.key .. " spot")
        return btn
    end

    local function CreateDeleteButton()
        local btn = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtnDelete", toolbar, CT_BUTTON)
        btn:SetDimensions(buttonSize, buttonSize)
        btn:SetAnchor(LEFT, toolbar, LEFT, buttonSpacing, 0)

        local btnBg = WINDOW_MANAGER:CreateControl("MiniMapToolbarBtnDeleteBg", btn, CT_BACKDROP)
        btnBg:SetAnchorFill(btn)
        btnBg:SetCenterColor(0.8, 0.2, 0.2, 0.8)
        btnBg:SetEdgeColor(1, 0.3, 0.3, 1)
        btnBg:SetEdgeTexture("", 1, 1, 2)

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
                    local d = SpotDatabase:RemoveSpotsInRadius(x, y, MINIMAP_SPOT_DUPLICATE_THRESHOLD, cat.key, MiniMap.currentMapName)
                    deleted = deleted + d
                end)
                PrintSpotDeleted(deleted)
            end
        end)
        SetupButtonTooltip(btn, btnBg,
            { 1, 0.3, 0.3, 0.9 },
            { 0.8, 0.2, 0.2, 0.8 },
            "Delete spots")
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

    self.spotMarkers = {}
    self.spotMarkersInitialized = false

    self.routeSegments = {}
    self.routeSegmentsInitialized = false
    self.routeMarker = nil

    self:RegisterEdgeIndicator(MINIMAP_EDGE_INDICATOR_QUEST, {
        color = MINIMAP_QUEST_COLOR,
        provider = function()
            return self:GetActiveQuestTargetPosition()
        end,
    })

    self:RegisterEdgeIndicator(MINIMAP_EDGE_INDICATOR_WAYSHRINE, {
        color = MINIMAP_WAYSHRINE_COLOR,
        provider = function()
            return self:GetNearestWayshrinePosition()
        end,
    })

    self:RegisterEdgeIndicator(MINIMAP_EDGE_INDICATOR_ROUTE, {
        color = MINIMAP_ROUTE_COLOR,
        provider = function()
            return self:GetNearestRoutePoint()
        end,
    })
end

function MiniMap:ApplyLayout()
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local size = math.floor(math.min(screenWidth, screenHeight) * self.saved.sizePercent / 100)
    local corner = CORNERS[self.saved.corner] or CORNERS.topright

    self.size = Clamp(size, 96, 480)
    local effectiveZoom = self.isCityMap and MINIMAP_CITY_ZOOM or self.saved.zoom
    self.mapSize = self.size * effectiveZoom

    self.root:ClearAnchors()
    self.root:SetAnchor(corner.anchor, GuiRoot, corner.relative, corner.x, corner.y)
    self.root:SetDimensions(self.size, self.size)
    self.map:SetDimensions(self.mapSize, self.mapSize)
    self.root:SetAlpha(Clamp(self.saved.opacity or DEFAULTS.opacity, 20, 100) / 100)
    self:ApplyDebugLayout()
    self:ApplyCircularClip()

    local playerSize = Clamp(math.floor(self.size * MINIMAP_SIZE_FACTOR_PLAYER), 18, 30)
    self.player:SetDimensions(playerSize, playerSize)

    self.spotMarkerSize = Clamp(math.floor(self.size * MINIMAP_SIZE_FACTOR_SPOT_MARKER), 9, 15)

    for _, indicator in pairs(self.edgeIndicators) do
        indicator.control:SetDimensions(playerSize, playerSize)
    end

    self:ApplyToolbarLayout()

    self:LayoutTiles()
    self:UpdatePlayer()

    if self.toolbar then
        self.toolbar:SetHidden(not self.saved.showToolbar)
    end
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

function MiniMap:ApplyToolbarLayout()
    if not self.toolbar then
        return
    end

    self.toolbar:ClearAnchors()
    self.toolbar:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -84)
end

function MiniMap:Text(key)
    local strings = STRINGS[self.language] or STRINGS.en
    return strings[key] or STRINGS.en[key] or key
end

function MiniMap:RegisterSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        Print(self:Text('settingsMissing'))
        return
    end

    local panelData = {
        type = 'panel',
        name = 'MiniMap',
        displayName = 'MiniMap',
        author = 'Codex',
        version = '1.0.0',
        slashCommand = '/minimapsettings',
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        {
            type = 'dropdown',
            name = self:Text('positionName'),
            tooltip = self:Text('positionTooltip'),
            choices = {
                self:Text('positionTopLeft'),
                self:Text('positionTopRight'),
                self:Text('positionBottomLeft'),
                self:Text('positionBottomRight'),
                self:Text('positionLeft'),
                self:Text('positionRight'),
                self:Text('positionTop'),
                self:Text('positionBottom'),
            },
            choicesValues = {
                'topleft',
                'topright',
                'bottomleft',
                'bottomright',
                'left',
                'right',
                'top',
                'bottom',
            },
            getFunc = function()
                return self.saved.corner
            end,
            setFunc = function(value)
                self.saved.corner = value
                self:ApplyLayout()
            end,
            default = DEFAULTS.corner,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('sizeName'),
            tooltip = self:Text('sizeTooltip'),
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
            width = 'full',
        },
        {
            type = 'dropdown',
            name = self:Text('orientationName'),
            tooltip = self:Text('orientationTooltip'),
            choices = { self:Text('orientationNorth'), self:Text('orientationPlayer') },
            choicesValues = { 'north', 'player' },
            getFunc = function()
                return self.saved.orientation
            end,
            setFunc = function(value)
                self.saved.orientation = value
                self:UpdatePlayer()
            end,
            default = DEFAULTS.orientation,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('opacityName'),
            tooltip = self:Text('opacityTooltip'),
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
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('autoSaveSpotsName'),
            tooltip = self:Text('autoSaveSpotsTooltip'),
            getFunc = function()
                return self.saved.autoSaveSpots
            end,
            setFunc = function(value)
                self.saved.autoSaveSpots = value
            end,
            default = DEFAULTS.autoSaveSpots,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('showToolbarName'),
            tooltip = self:Text('showToolbarTooltip'),
            getFunc = function()
                return self.saved.showToolbar
            end,
            setFunc = function(value)
                self.saved.showToolbar = value
                self:ApplyToolbarLayout()
            end,
            default = DEFAULTS.showToolbar,
            width = 'full',
        },
    }

    LAM:RegisterAddonPanel('MiniMapSettings', panelData)
    LAM:RegisterOptionControls('MiniMapSettings', optionsTable)
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
    ForEachCategory(function(cat)
        spotInfo = spotInfo .. string.format("%s=%d ", cat.key, SpotDatabase:GetSpotCount(cat.key))
    end)

    local routeInfo = ""
    if self.routeManager:IsRouteActive() then
        local route = self.routeManager:GetRoute()
        local segments = self.routeManager:GetRouteSegments()
        routeInfo = "\nRoute: " .. tostring(#route) .. " spots, " .. tostring(#segments) .. " segs"
    end

    local text = string.format(
        "MiniMap debug\nSpots: %s\nmap=%s\nquest=%s\nplayer=%.4f,%.4f target=%s%s",
        spotInfo,
        tostring(self.currentMapName or ""),
        tostring(debug.questIndex or "nil"),
        debug.playerX or 0,
        debug.playerY or 0,
        debug.target and string.format("%.4f,%.4f", debug.targetX, debug.targetY) or "nil",
        routeInfo
    )

    self.debugLabel:SetText(text)
    self.debugWindow:SetHidden(false)
end

function MiniMap:RegisterEdgeIndicator(id, options)
    local indicator = self.edgeIndicators[id]
    if not indicator then
        local control = WINDOW_MANAGER:CreateControl("MiniMapEdgeIndicator" .. id, self.root, CT_TEXTURE)
        control:SetTexture(MINIMAP_EDGE_INDICATOR_TEXTURE)
        control:SetDrawLayer(DL_OVERLAY)
        control:SetHidden(true)

        local insideControl = WINDOW_MANAGER:CreateControl("MiniMapEdgeIndicatorInside" .. id, self.root, CT_BACKDROP)
        insideControl:SetDrawLayer(DL_OVERLAY)
        insideControl:SetCenterColor(0, 0, 0, 1)
        insideControl:SetEdgeColor(0, 0, 0, 1)
        insideControl:SetEdgeTexture(nil, 1, 1, 2)
        insideControl:SetHidden(true)

        indicator = {
            control = control,
            insideControl = insideControl,
        }
        self.edgeIndicators[id] = indicator
        self.edgeIndicatorOrder[#self.edgeIndicatorOrder + 1] = id
    end

    indicator.provider = options.provider
    indicator.color = { options.color[1], options.color[2], options.color[3], options.color[4] }
    indicator.control:SetColor(indicator.color[1], indicator.color[2], indicator.color[3], indicator.color[4] or 1)
    indicator.insideControl:SetCenterColor(indicator.color[1], indicator.color[2], indicator.color[3], 1)
    indicator.insideControl:SetEdgeColor(indicator.color[1] * 0.5, indicator.color[2] * 0.5, indicator.color[3] * 0.5, 1)
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

function MiniMap:GetNearestWayshrinePosition()
    local px, py = self.playerMapX, self.playerMapY
    if not px or not py then
        return nil
    end

    local numNodes = GetNumFastTravelNodes()
    if not numNodes or numNodes == 0 then
        return nil
    end

    local nearestDist = math.huge
    local nearestX, nearestY

    for i = 1, numNodes do
        local icon, name, x, y, poiType, isAvailable = GetFastTravelNodeInfo(i)
        if x and y and isAvailable then
            local dx = x - px
            local dy = y - py
            local dist = dx * dx + dy * dy
            if dist < nearestDist then
                nearestDist = dist
                nearestX, nearestY = x, y
            end
        end
    end

    return nearestX, nearestY
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

function MiniMap:GetNearestRoutePoint()
    if not self.playerMapX or not self.playerMapY then
        return nil
    end

    local segments = self.routeManager:GetRouteSegments()
    if not segments or #segments == 0 then
        return nil
    end

    local px, py = self.playerMapX, self.playerMapY
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
            local t = ((px - x1) * dx + (py - y1) * dy) / lengthSq
            t = math.max(0, math.min(1, t))
            projX = x1 + t * dx
            projY = y1 + t * dy
        end

        local distDx = px - projX
        local distDy = py - projY
        local distSq = distDx * distDx + distDy * distDy

        if distSq < nearestDistSq then
            nearestDistSq = distSq
            nearestX, nearestY = projX, projY
        end
    end

    return nearestX, nearestY
end

local function PositionEdgeIndicatorAtEdge(indicator, root, center, radius, dx, dy, markerSize)
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length <= 0.0001 then
        indicator.control:SetHidden(true)
        return
    end

    local unitX = dx / length
    local unitY = dy / length
    local edgeRadius = radius - (markerSize * 0.34)

    indicator.control:SetDimensions(markerSize, markerSize)
    indicator.control:ClearAnchors()
    indicator.control:SetAnchor(CENTER, root, TOPLEFT, center + (unitX * edgeRadius), center + (unitY * edgeRadius))

    if indicator.control.SetTextureRotation then
        indicator.control:SetTextureRotation(GetRotationFromUp(unitX, unitY))
    end

    indicator.control:SetHidden(false)
end

function MiniMap:UpdateEdgeIndicators(playerX, playerY, mapRotation)
    local radius = self.size / 2
    local center = radius
    local markerSize = Clamp(math.floor(self.size * MINIMAP_SIZE_FACTOR_EDGE_INDICATOR), 18, 32)
    local insideMarkerSize = Clamp(math.floor(self.size * MINIMAP_SIZE_FACTOR_INSIDE_MARKER), 6, 12)
    local margin = self.spotMarkerSize

    self:UpdateSpotMarkers(playerX, playerY, mapRotation, center, radius, margin)
    self:UpdateRouteSegments(playerX, playerY, mapRotation, center, radius)

    for _, id in ipairs(self.edgeIndicatorOrder) do
        local indicator = self.edgeIndicators[id]
        local targetX, targetY = indicator.provider()

        if targetX and targetY then
            local localX, localY, distFromCenter, dx, dy = WorldToLocal(targetX, targetY, playerX, playerY, self.mapSize, mapRotation, center)

            if distFromCenter >= (radius - margin) then
                indicator.insideControl:SetHidden(true)
                PositionEdgeIndicatorAtEdge(indicator, self.root, center, radius, dx, dy, markerSize)
            else
                indicator.control:SetHidden(true)
                indicator.insideControl:ClearAnchors()
                indicator.insideControl:SetAnchor(CENTER, self.root, TOPLEFT, localX, localY)
                indicator.insideControl:SetDimensions(insideMarkerSize, insideMarkerSize)
                indicator.insideControl:SetHidden(false)
            end
        else
            indicator.control:SetHidden(true)
            indicator.insideControl:SetHidden(true)
        end
    end
end

function MiniMap:UpdateSpotMarkers(playerX, playerY, mapRotation, center, radius, margin)
    if not self.spotMarkersInitialized then
        local MAX_MARKERS_PER_CAT = 10
        ForEachCategory(function(cat)
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
        end)
        self.spotMarkersInitialized = true
    end

    local zoneSpots = SpotDatabase:GetSpotsByMap(self.currentMapName)
    if not zoneSpots then
        ForEachCategory(function(cat)
            local markers = self.spotMarkers[cat.key]
            for i = 1, #markers do
                markers[i]:SetHidden(true)
            end
        end)
        return
    end

    ForEachCategory(function(cat)
        local markers = self.spotMarkers[cat.key]
        local spots = zoneSpots[cat.key] or {}
        local markerIndex = 1

        for _, spot in ipairs(spots) do
            local localX, localY, distFromCenter = WorldToLocal(spot.x, spot.y, playerX, playerY, self.mapSize, mapRotation, center)

            if distFromCenter < (radius - margin) and markerIndex <= #markers then
                local marker = markers[markerIndex]
                marker:ClearAnchors()
                marker:SetAnchor(CENTER, self.root, TOPLEFT, localX, localY)
                marker:SetDimensions(self.spotMarkerSize, self.spotMarkerSize)
                marker:SetHidden(false)
                markerIndex = markerIndex + 1
            end
        end

        for i = markerIndex, #markers do
            markers[i]:SetHidden(true)
        end
    end)
end

function MiniMap:UpdateRouteSegments(playerX, playerY, mapRotation, center, radius)
    if not self.routeSegmentsInitialized then
        for i = 1, ROUTE_SEGMENT_MAX do
            local controlName = self.root:GetName() .. "RouteSegment" .. i
            local control = WINDOW_MANAGER:CreateControl(controlName, self.root, CT_TEXTURE)
            control:SetDrawLayer(DL_OVERLAY)
            control:SetTexture(MINIMAP_SEGMENT_TEXTURE)
            control:SetHidden(true)
            self.routeSegments[i] = control
        end
        self.routeSegmentsInitialized = true
    end

    self.routeManager:RecalculateIfNeeded(playerX, playerY, self.currentMapName)
    local segments = self.routeManager:GetRouteSegments()

    local debugText = "RouteSegs=" .. tostring(#segments)

    for i, segment in ipairs(segments) do
        local control = self.routeSegments[i]
        if not control then break end

        local x1 = (segment.x1 - playerX) * self.mapSize
        local y1 = (segment.y1 - playerY) * self.mapSize
        local x2 = (segment.x2 - playerX) * self.mapSize
        local y2 = (segment.y2 - playerY) * self.mapSize

        x1, y1 = RotateVector(x1, y1, mapRotation)
        x2, y2 = RotateVector(x2, y2, mapRotation)

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
            angle = GetRotationFromUp(unitX, unitY) + math.pi / 2
        end

        debugText = debugText .. " l" .. i .. "=" .. string.format("%.0f", length)

        if length > 3 then
            local midX = (localX1 + localX2) / 2
            local midY = (localY1 + localY2) / 2
            control:ClearAnchors()
            control:SetAnchor(CENTER, self.root, TOPLEFT, midX, midY)
            control:SetDimensions(math.max(length, 4), 4)
            control:SetColor(MINIMAP_ROUTE_COLOR[1], MINIMAP_ROUTE_COLOR[2], MINIMAP_ROUTE_COLOR[3], MINIMAP_ROUTE_COLOR[4])
            control:SetTextureRotation(angle)
            control:SetHidden(false)
        else
            control:SetHidden(true)
        end
    end

    for i = #segments + 1, ROUTE_SEGMENT_MAX do
        if self.routeSegments[i] then
            self.routeSegments[i]:SetHidden(true)
        end
    end

    if self.saved.debug then
        self.questDebug = self.questDebug or {}
        self.questDebug.route = debugText
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

    self.nextMapRefreshMs = now + MINIMAP_REFRESH_MS

    local mapType = GetMapType and GetMapType() or MAPTYPE_ZONE
    self.isCityMap = (mapType == MAPTYPE_SUBZONE)

    local mapName = GetMapName and GetMapName() or ""
    local numHorizontalTiles, numVerticalTiles = 0, 0

    if GetMapNumTiles then
        numHorizontalTiles, numVerticalTiles = GetMapNumTiles()
    end

    if not numHorizontalTiles or not numVerticalTiles or numHorizontalTiles == 0 or numVerticalTiles == 0 then
        self.root:SetHidden(true)
        return false
    end

    local previousMapName = self.currentMapName
    if force or mapName ~= self.currentMapName or numHorizontalTiles ~= self.numHorizontalTiles or numVerticalTiles ~= self.numVerticalTiles then
        self.currentMapName = mapName
        self.numHorizontalTiles = numHorizontalTiles
        self.numVerticalTiles = numVerticalTiles
        self:LayoutTiles()
        self:ApplyLayout()
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
    self:UpdateEdgeIndicators(normalizedX, normalizedY, elementRotation)

    if self.player.SetTextureRotation then
        if self.saved.orientation == "player" then
            self.player:SetTextureRotation(0)
        else
            self.player:SetTextureRotation(GetPlayerCameraHeading() or 0)
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
    Print("/minimap_add <category>")
    Print("/minimap_spots")
    Print("/minimap_clear <category>|all")
    Print("/minimap_log")
    Print("/minimap_log_clear")
    Print("/minimap_clean")
    Print("/minimap_pos")
    Print("/minimap_route <category1 category2 ...>")
    Print("/minimap_route_clear")
    Print("/minimap_route_info")
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

        self.saved.zoom = Clamp(zoom, 2, 16)
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
    ForEachCategory(function(cat)
        SPOT_DEFAULTS[cat.key] = {}
    end)
    self.spots = ZO_SavedVars:NewAccountWide("MiniMapSpots", 1, nil, SPOT_DEFAULTS)
    SpotDatabase:Init(self.spots)
    local count = SpotDatabase:GetSpotCount()

    self.routeManager = RouteManager
    self.routeManager:Init()

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
        
        local isPointerMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive()
        
        if sceneShown then
            MiniMap.root:SetHidden(true)
            if MiniMap.toolbar then MiniMap.toolbar:SetHidden(true) end
            lastMapOpen = true
        elseif not MiniMap.saved.hidden then
            local toolbarVisible = MiniMap.saved.showToolbar and isPointerMode
            if MiniMap.toolbar then MiniMap.toolbar:SetHidden(not toolbarVisible) end
            MiniMap.root:SetHidden(toolbarVisible)
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

    local lastLootTargetType = nil
    local lastLootTargetName = nil

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT_UPDATED", EVENT_LOOT_UPDATED, function()
        local lootName, actionName, isOwned = GetLootTargetInfo()
        
        local isMonster = IsGameCameraInteractableUnitMonster()
        
        if lootName and lootName ~= "" then
            if isMonster then
                lastLootTargetType = "MONSTER"
            else
                lastLootTargetType = "OBJECT"
            end
            lastLootTargetName = lootName
        elseif isMonster then
            lastLootTargetType = "MONSTER"
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT_CLOSED", EVENT_LOOT_CLOSED, function()
        lastLootTargetType = nil
        lastLootTargetName = nil
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT", EVENT_LOOT_RECEIVED, function(eventCode, characterName, itemName, quantity, lootType, lootedBySelf)
        if not MiniMap.saved.autoSaveSpots then
            return
        end
        if lastLootTargetType == "MONSTER" then
            return
        end
        
        local category = SpotDatabase:GetResourceCategory(lootType)
        if not category then
            return
        end

        AddSpotAtPlayer(category)
    end)

    SLASH_COMMANDS["/minimap_add"] = function(arguments)
        local category = zo_strlower(arguments or "")
        if IsValidCategory(category) then
            AddSpotAtPlayer(category)
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
        ForEachCategory(function(cat)
            Print("  " .. cat.key .. ": " .. SpotDatabase:GetSpotCount(cat.key))
        end)
    end

    local pendingClearConfirm = nil
    
    SLASH_COMMANDS["/minimap_clear"] = function(arguments)
        local category = zo_strlower(arguments or "")
        if category == "all" then
            if pendingClearConfirm then
                SpotDatabase:Clear()
                Print("All spots cleared")
                pendingClearConfirm = nil
            else
                pendingClearConfirm = "all"
                Print("Confirm: type /minimap_clear all again to clear ALL spots")
            end
        elseif IsValidCategory(category) then
            SpotDatabase:Clear(category)
            Print(category .. " spots cleared")
        elseif category == "cancel" then
            pendingClearConfirm = nil
            Print("Clear cancelled")
        else
            Print("Usage: /minimap_clear <category>|all|cancel")
        end
    end

    SLASH_COMMANDS["/minimap_log"] = function()
        if not MiniMap.debugLog or #MiniMap.debugLog == 0 then
            Print("No debug log")
            return
        end
        for i, msg in ipairs(MiniMap.debugLog) do
            d("[" .. i .. "] " .. msg)
        end
    end
    
    SLASH_COMMANDS["/minimap_log_clear"] = function()
        MiniMap.debugLog = {}
        Print("Debug log cleared")
    end

    SLASH_COMMANDS["/minimap_pos"] = function()
        local x, y = GetMapPlayerPosition("player")
        if x and y then
            Print("Position: " .. string.format("%.4f, %.4f", x, y))
        else
            Print("Position unknown")
        end
    end

    SLASH_COMMANDS["/minimap_clean"] = function()
        local removed = SpotDatabase:CleanDuplicates(true)
        Print(tostring(removed) .. " removed")
    end

    SLASH_COMMANDS["/minimap_route"] = function(arguments)
        local categories = {}
        for cat in string.gmatch(arguments or "", "%S+") do
            if IsValidCategory(cat) then
                table.insert(categories, cat)
            end
        end

        if #categories == 0 then
            Print("Usage: /minimap_route <category1 category2 ...>")
            Print("Available: chest jewelry ore plant poison rune silk thief_chest water wood")
            return
        end

        RouteManager:ClearCategories()
        for _, cat in ipairs(categories) do
            RouteManager:ToggleCategory(cat)
        end

        RouteManager:CalculateRoute(MiniMap.playerMapX, MiniMap.playerMapY, MiniMap.currentMapName)
        Print(RouteManager:GetRouteInfo())
    end

    SLASH_COMMANDS["/minimap_route_clear"] = function()
        RouteManager:ClearCategories()
        RouteManager:ClearRoute()
        Print("Route cleared")
    end

    SLASH_COMMANDS["/minimap_route_info"] = function()
        if RouteManager:IsRouteActive() then
            Print(RouteManager:GetRouteInfo())
        else
            Print("No route active")
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
