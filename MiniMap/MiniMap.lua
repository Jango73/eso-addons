
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

local ADDON_NAME = "MiniMap"

local MiniMap = {
    tiles = {},
    tileCount = 0,
    currentMapName = nil,
    currentMapType = nil,
    nextMapRefreshMs = 0,
    nextLocationProbeMs = 0,
    nextQuestBreadcrumbRefreshMs = 0,
    isCityMap = false,
    foundNpc = nil,
}

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

local function Echo(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function ParseArgument(arg)
    if not arg or arg == "" then return nil, nil end
    local command, rest = zo_strmatch(arg, "^(%S*)%s*(.*)$")
    command = zo_strlower(command or "")
    
    if rest and rest ~= "" then
        if rest:sub(1, 1) == '"' then
            local quoted = rest:match('^"(.-)"')
            if quoted then
                return command, quoted
            end
        end
        local firstWord = zo_strmatch(rest, "^(%S*)")
        local after = rest:match("^%S*%s+(.+)$")
        return firstWord, after
    end
    return command, nil
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

local function PrintNpcAdded(npcName)
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, "NPC added: " .. npcName)
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
        local added, isNew = SpotDatabase:AddSpot(x, y, category, MiniMap.currentMapName)
        if added and isNew then
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
    self.border = border
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
    toolbarBg:SetEdgeColor(
        MINIMAP_ESO_BORDER_COLOR[1],
        MINIMAP_ESO_BORDER_COLOR[2],
        MINIMAP_ESO_BORDER_COLOR[3],
        MINIMAP_ESO_BORDER_COLOR[4]
    )
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
            if IsShiftKeyDown() then
                self:HandleSlashCommand("route " .. cat.key)
            else
                AddSpotAtPlayer(cat.key)
            end
        end)
        SetupButtonTooltip(btn, btnBg,
            { cat.color[1] * 0.7, cat.color[2] * 0.7, cat.color[3] * 0.7, 0.9 },
            { cat.color[1], cat.color[2], cat.color[3], 0.7 },
            self:Text('toolbarAddSpot'):format(cat.key))
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
    self.spotRenderer:Init(self)

    self.noteRenderer = NoteRenderer
    self.noteRenderer:Init(self)

    self.routeRenderer = RouteRenderer
    self.routeRenderer:Init(self, self.routeManager)

    self.indicatorRenderer = IndicatorRenderer
    self.indicatorRenderer:Init(self, {
        [MINIMAP_EDGE_INDICATOR_QUEST] = function()
            return self:GetActiveQuestTargetPosition()
        end,
        [MINIMAP_EDGE_INDICATOR_WAYSHRINE] = function()
            return self:GetNearestWayshrinePosition()
        end,
        [MINIMAP_EDGE_INDICATOR_ROUTE] = function()
            return self.routeRenderer:GetNearestRoutePoint(self.playerMapX, self.playerMapY)
        end,
        [MINIMAP_EDGE_INDICATOR_NPC] = function()
            return self:GetFoundNpcPosition()
        end,
    })
end

function MiniMap:ApplyLayout()
    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    local size = math.floor(math.min(screenWidth, screenHeight) * self.saved.sizePercent / 100)
    local corner = CORNERS[self.saved.corner] or CORNERS.topright

    self.size = MiniMapRenderUtils.Clamp(size, 96, 480)
    local effectiveZoom = self.isCityMap and MINIMAP_CITY_ZOOM or self.saved.zoom
    self.mapSize = self.size * effectiveZoom

    self.root:ClearAnchors()
    self.root:SetAnchor(corner.anchor, GuiRoot, corner.relative, corner.x, corner.y)
    self.root:SetDimensions(self.size, self.size)
    self.border:SetDimensions(self.size, self.size)
    self.map:SetDimensions(self.mapSize, self.mapSize)
    self.root:SetAlpha(MiniMapRenderUtils.Clamp(self.saved.opacity or DEFAULTS.opacity, 20, 100) / 100)
    self:ApplyDebugLayout()
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

    self:LayoutTiles()
    self:UpdatePlayer()

    if self.toolbar then
        self.toolbar:SetHidden(not self.saved.showToolbar)
    end

    if self.noteRenderer then
        local noteCount = NoteDatabase:GetNoteCount()
        self.noteRenderer:ApplyLayout(noteCount)
        self.noteRenderer:Update(noteCount)
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
    return Locale.GetString(key)
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
        author = 'Jango73',
        version = '1.0.0',
        slashCommand = '/minimapsettings',
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
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
                self.saved.sizePercent = MiniMapRenderUtils.Clamp(value, 10, 40)
                self:ApplyLayout()
            end,
            default = DEFAULTS.sizePercent,
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
                self.saved.opacity = MiniMapRenderUtils.Clamp(value, 20, 100)
                self.root:SetAlpha(self.saved.opacity / 100)
            end,
            default = DEFAULTS.opacity,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('refreshRateName'),
            tooltip = self:Text('refreshRateTooltip'),
            getFunc = function()
                return self.saved.refreshRate or DEFAULTS.refreshRate
            end,
            setFunc = function(value)
                self.saved.refreshRate = value
                self.refreshRateDirty = true
            end,
            min = 50,
            max = 1000,
            step = 100,
            default = DEFAULTS.refreshRate,
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
            name = self:Text('autoSaveNpcsName'),
            tooltip = self:Text('autoSaveNpcsTooltip'),
            getFunc = function()
                return self.saved.autoSaveNpcs
            end,
            setFunc = function(value)
                self.saved.autoSaveNpcs = value
            end,
            default = DEFAULTS.autoSaveNpcs,
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
        {
            type = 'checkbox',
            name = self:Text('showNotesName'),
            tooltip = self:Text('showNotesTooltip'),
            getFunc = function()
                return self.saved.showNotes
            end,
            setFunc = function(value)
                self.saved.showNotes = value
                self:ApplyLayout()
            end,
            default = DEFAULTS.showNotes,
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

local POI_TYPE_WAYSHRINE = 1

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
        local known, name, x, y, icon, glowIcon, poiType, isShown, linkedLocked = GetFastTravelNodeInfo(i)
        if x and y and poiType == POI_TYPE_WAYSHRINE then
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

function MiniMap:GetFoundNpcPosition()
    if not self.foundNpc then return nil end
    local npcData = NPCDatabase:GetNPCByName(self.foundNpc, self.currentMapName)
    if not npcData then return nil end
    return npcData.x, npcData.y
end

function MiniMap:ClearFoundNpc()
    self.foundNpc = nil
end

function MiniMap:UpdateMapOverlays(playerX, playerY, mapRotation)
    local radius = self.size / 2
    local center = radius
    local margin = self.spotRenderer:GetMargin()

    self.spotRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, self.currentMapName)
    self.routeRenderer:Update(playerX, playerY, mapRotation, center, radius, self.currentMapName)
    if self.saved.debug then
        self.questDebug = self.questDebug or {}
        self.questDebug.route = self.routeRenderer:GetDebugText()
    end

    self.indicatorRenderer:Update(playerX, playerY, mapRotation, center, radius, margin)
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

    if force
        or mapName ~= self.currentMapName
        or mapType ~= self.currentMapType
        or numHorizontalTiles ~= self.numHorizontalTiles
        or numVerticalTiles ~= self.numVerticalTiles
    then
        self.currentMapName = mapName
        self.currentMapType = mapType
        self.numHorizontalTiles = numHorizontalTiles
        self.numVerticalTiles = numVerticalTiles
        self:LayoutTiles()
        self:ApplyLayout()
    end

    self.root:SetHidden(self.saved.hidden)
    return true
end

function MiniMap:IsWorldMapShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene("worldMap")
    return scene and scene:IsShowing()
end

function MiniMap:RefreshMapToPlayerLocation(force)
    if SetMapToPlayerLocation and not self:IsWorldMapShowing() then
        local result = SetMapToPlayerLocation()
        if result == SET_MAP_RESULT_MAP_CHANGED and CALLBACK_MANAGER then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end

    return self:RefreshMap(force)
end

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

function MiniMap:ShowHelp()
    Echo(self:Text("helpCorner"))
    Echo(self:Text("helpSize"))
    Echo(self:Text("helpOrientation"))
    Echo(self:Text("helpOpacity"))
    Echo(self:Text("helpZoom"))
    Echo(self:Text("helpVisibility"))
    Echo("/minimap add <category>")
    Echo("/minimap spots")
    Echo("/minimap find <name>")
    Echo("/minimap npc search <name>")
    Echo("/minimap npc list")
    Echo("/minimap npc clear")
    Echo("/minimap clear <category>|all")
    Echo("/minimap log clear")
    Echo("/minimap clean")
    Echo("/minimap pos")
    Echo("/minimap route <category1 category2 ...>|all")
    Echo("/minimap route clear")
    Echo("/minimap route info")
end

local pendingClearConfirm = nil

function MiniMap:HandleSlashCommand(arguments)
    local command, value = zo_strmatch(arguments or "", "^(%S*)%s*(.*)$")
    command = zo_strlower(command or "")
    
    if command ~= "clear" and command ~= "npc" then
        pendingClearConfirm = nil
    end

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

        self.saved.sizePercent = MiniMapRenderUtils.Clamp(sizePercent, 10, 40)
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

        self.saved.opacity = MiniMapRenderUtils.Clamp(opacity, 20, 100)
        self.root:SetAlpha(self.saved.opacity / 100)
        Print(string.format(self:Text("opacityChanged"), self.saved.opacity))
    elseif command == "zoom" then
        local zoom = tonumber(value)
        if not zoom then
            Print(self:Text("invalidZoom"))
            return
        end

        self.saved.zoom = MiniMapRenderUtils.Clamp(zoom, 2, 16)
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
    elseif command == "add" then
        if IsValidCategory(value) then
            AddSpotAtPlayer(value)
        else
            local valid = ""
            for _, c in ipairs(RESOURCE_CATEGORIES) do
                valid = valid .. c.key .. "|"
            end
            Echo("Usage: /minimap add " .. valid:sub(1, -2))
        end
    elseif command == "spots" then
        local total = SpotDatabase:GetSpotCount()
        Print(string.format(self:Text("totalSpots"), total))
        ForEachCategory(function(cat)
            Print(string.format(self:Text("spotsCount"), cat.key, SpotDatabase:GetSpotCount(cat.key)))
        end)
    elseif command == "clear" then
        if value == "all" then
            if pendingClearConfirm == "all" then
                SpotDatabase:Clear()
                Print(self:Text("allSpotsCleared"))
                pendingClearConfirm = nil
            else
                pendingClearConfirm = "all"
                Print(self:Text("confirmClearSpots"))
            end
        elseif IsValidCategory(value) then
            SpotDatabase:Clear(value)
            Print(string.format(self:Text("spotsCleared"), value))
        elseif value == "cancel" then
            pendingClearConfirm = nil
            Print(self:Text("clearCancelled"))
        else
            Echo("Usage: /minimap clear <category>|all|cancel")
        end
    elseif command == "log" then
        if value == "clear" then
            MiniMap.debugLog = {}
            Print(self:Text("debugLogCleared"))
        elseif not MiniMap.debugLog or #MiniMap.debugLog == 0 then
            Print(self:Text("noDebugLog"))
            return
        else
            for i, msg in ipairs(MiniMap.debugLog) do
                d("[" .. i .. "] " .. msg)
            end
        end
    elseif command == "clean" then
        local removed = SpotDatabase:CleanDuplicates(true)
        Print(string.format(self:Text("removed"), removed))
    elseif command == "pos" then
        local x, y = GetMapPlayerPosition("player")
        if x and y then
            Print(string.format(self:Text("position"), x, y))
        else
            Print(self:Text("positionUnknown"))
        end
    elseif command == "route" then
        local routeCommand = zo_strlower(zo_strmatch(value or "", "^(%S*)") or "")
        if routeCommand == "clear" then
            RouteManager:ClearCategories()
            RouteManager:ClearRoute()
            Print(self:Text("routeCleared"))
            return
        elseif routeCommand == "info" then
            if RouteManager:IsRouteActive() then
                Print(RouteManager:GetRouteInfo())
            else
                Print(self:Text("noRouteActive"))
            end
            return
        elseif routeCommand == "all" then
            RouteManager:SetAllCategories()
            RouteManager:CalculateRoute(self.playerMapX, self.playerMapY, self.currentMapName)
            Print(RouteManager:GetRouteInfo())
            return
        end

        local categories = {}
        for cat in string.gmatch(value, "%S+") do
            if IsValidCategory(cat) then
                table.insert(categories, cat)
            end
        end

        if #categories == 0 then
            Echo("Usage: /minimap route <category1 category2 ...>|all")
            Echo("Available: all book chest home jewelry ore plant rune shard silk thief_chest water wood")
            return
        end

        RouteManager:ClearCategories()
        for _, cat in ipairs(categories) do
            RouteManager:ToggleCategory(cat)
        end

        RouteManager:CalculateRoute(self.playerMapX, self.playerMapY, self.currentMapName)
        Print(RouteManager:GetRouteInfo())
    elseif command == "routeclear" then
        RouteManager:ClearCategories()
        RouteManager:ClearRoute()
        Print(self:Text("routeCleared"))
    elseif command == "routeinfo" then
        if RouteManager:IsRouteActive() then
            Print(RouteManager:GetRouteInfo())
        else
            Print(self:Text("noRouteActive"))
        end
    elseif command == "find" then
        local npcName = nil
        if value and value ~= "" then
            if value:sub(1, 1) == '"' then
                npcName = value:match('^"(.-)"')
            else
                npcName = zo_strmatch(value, "^(%S+)")
            end
        end
        if not npcName or npcName == "" then
            self:ClearFoundNpc()
            Print(self:Text("npcTargetCleared"))
            return
        end
        local results = NPCDatabase:SearchNPCs(npcName, self.currentMapName)
        if #results > 0 then
            local match = results[1]
            self.foundNpc = match.name
            if #results > 1 then
                Print(string.format(self:Text("tracking"), match.name, match.x, match.y, #results))
            else
                Print(string.format(self:Text("trackingSingle"), match.name, match.x, match.y))
            end
        else
            self:ClearFoundNpc()
            local allResults = NPCDatabase:SearchNPCs(npcName)
            if #allResults > 0 then
                local zones = {}
                for _, npc in ipairs(allResults) do
                    if not zones[npc.map] then
                        zones[npc.map] = 0
                    end
                    zones[npc.map] = zones[npc.map] + 1
                end
                local zoneList = {}
                for zone, count in pairs(zones) do
                    table.insert(zoneList, zone .. " (" .. count .. ")")
                end
                Print(string.format(self:Text("npcNotFoundZone"), table.concat(zoneList, ", ")))
            else
                Print(string.format(self:Text("npcNotFound"), npcName))
            end
        end
    elseif command == "npc" then
        local subCmd, npcQuery = zo_strmatch(value or "", "^(%S+)%s*(.*)$")
        subCmd = zo_strlower(subCmd or "")
        
        if subCmd == "search" or subCmd == "find" then
            if npcQuery and npcQuery ~= "" then
                if npcQuery:sub(1, 1) == '"' then
                    npcQuery = npcQuery:match('^"(.-)"')
                else
                    npcQuery = zo_strmatch(npcQuery, "^(%S+)")
                end
            end
            if not npcQuery or npcQuery == "" then
                Echo("Usage: /minimap npc search <name>")
                return
            end
            local results = NPCDatabase:SearchNPCs(npcQuery)
            if #results == 0 then
                Print(string.format(self:Text("noNpcsFound"), npcQuery))
            else
                Print(string.format(self:Text("foundNpcs"), #results))
                for i, npc in ipairs(results) do
                    if i > 20 then
                        Print(string.format(self:Text("moreNpcs"), #results - 20))
                        break
                    end
                    Print(string.format(self:Text("npcEntry"), npc.map, npc.name, npc.x, npc.y))
                end
            end
        elseif subCmd == "list" or subCmd == "ls" then
            local maps = NPCDatabase:GetAllMaps()
            local mapCount = 0
            local npcCount = 0
            for mapName, count in pairs(maps) do
                mapCount = mapCount + 1
                npcCount = npcCount + count
            end
            Print(string.format(self:Text("npcDatabaseInfo"), mapCount, npcCount))
            if mapCount > 0 then
                for mapName, count in pairs(maps) do
                    Print(string.format(self:Text("npcsInZone"), mapName, count))
                end
            end
        elseif subCmd == "clear" then
            if pendingClearConfirm == "npc" then
                NPCDatabase:Clear()
                Print(self:Text("allNpcsCleared"))
                pendingClearConfirm = nil
            else
                pendingClearConfirm = "npc"
                Print(self:Text("confirmClearNpcs"))
            end
        elseif subCmd == "here" then
            local npcs = NPCDatabase:GetNPCsByMap(self.currentMapName)
            local count = 0
            for _ in pairs(npcs) do count = count + 1 end
            Print(string.format(self:Text("npcsInMap"), count, self.currentMapName or "unknown"))
            for name, data in pairs(npcs) do
                Print(string.format(self:Text("npcDataEntry"), name, data.x, data.y))
            end
        else
            Echo("NPC commands:")
            Echo("  /minimap npc search <name>")
            Echo("  /minimap npc list")
            Echo("  /minimap npc here")
            Echo("  /minimap npc clear")
        end
    else
        self:ShowHelp()
    end
end

function MiniMap:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("MiniMapSavedVariables", 1, nil, DEFAULTS)

    self.spots = ZO_SavedVars:NewAccountWide("MiniMapSpots", 1, nil, {})
    SpotDatabase:Init(self.spots)

    self.npcs = ZO_SavedVars:NewAccountWide("MiniMapNPCs", 1, nil, {})
    NPCDatabase:Init(self.npcs)

    self.notes = ZO_SavedVars:NewAccountWide("MiniMapNotes", 1, nil, {})
    NoteDatabase:Init(self.notes)

    self.routeManager = RouteManager
    self.routeManager:Init()

    self.language = Locale.GetLanguage()

    self:CreateControls()
    self:ApplyLayout()
    self:RefreshMapToPlayerLocation(true)
    self:RegisterSettingsMenu()

    SLASH_COMMANDS["/minimap"] = function(arguments)
        self:HandleSlashCommand(arguments)
    end

    local lastLootTargetType = nil
    local lastLootTargetName = nil

    local updateCounter = 0
    local lastMapOpen = false
    local function OnMinimapUpdate()
        if MiniMap.refreshRateDirty then
            MiniMap.refreshRateDirty = false
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "Update")
            EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", MiniMap.saved.refreshRate or 500, OnMinimapUpdate)
        end

        local sceneShown = MiniMap:IsWorldMapShowing()

        if not sceneShown then
            MiniMap:RefreshMapIfPlayerLocationChanged()
        end

        MiniMap:UpdatePlayer()

        if sceneShown then
            MiniMap.root:SetHidden(true)
            if MiniMap.toolbar then MiniMap.toolbar:SetHidden(true) end
            if MiniMap.noteRenderer then MiniMap.noteRenderer:CloseEditor() end
            if MiniMap.noteRenderer and MiniMap.noteRenderer.notesPanel then MiniMap.noteRenderer.notesPanel:SetHidden(true) end
            lastMapOpen = true
        elseif not MiniMap.saved.hidden then
            local isHudShowing = true
            if SCENE_MANAGER and SCENE_MANAGER.GetScene then
                local hudScene = SCENE_MANAGER:GetScene("hud")
                local huduiScene = SCENE_MANAGER:GetScene("hudui")
                isHudShowing = (hudScene and hudScene.state and hudScene.state ~= "hidden") or (huduiScene and huduiScene.state and huduiScene.state ~= "hidden")
            end
            local isPointerMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive()
            local toolbarVisible = MiniMap.saved.showToolbar and isPointerMode and isHudShowing
            if MiniMap.toolbar then MiniMap.toolbar:SetHidden(not toolbarVisible) end
            MiniMap.root:SetHidden(not isHudShowing)
            if MiniMap.noteRenderer and MiniMap.noteRenderer.notesPanel then
                local notesVisible = MiniMap.saved.showNotes and isHudShowing
                MiniMap.noteRenderer.notesPanel:SetHidden(not notesVisible)
            end
            if lastMapOpen then
                lastMapOpen = false
                MiniMap:RefreshMapToPlayerLocation(true)
            end
        end
    end

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", self.saved.refreshRate or 500, OnMinimapUpdate)

    local function RefreshMapAfterLocationChange()
        MiniMap:RefreshMapToPlayerLocation(true)
        if zo_callLater then
            zo_callLater(function()
                MiniMap:RefreshMapToPlayerLocation(true)
                MiniMap:UpdatePlayer()
            end, 250)
        end
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, RefreshMapAfterLocationChange)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZONE_CHANGED", EVENT_ZONE_CHANGED, function()
        RefreshMapAfterLocationChange()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_CHATTER", EVENT_CHATTER_BEGIN, function()
        if not MiniMap.saved.autoSaveNpcs then
            return
        end
        local name = GetUnitName("interact")
        local x, y, heading = GetMapPlayerPosition("player")
        if name and name ~= "" and x and y then
            if not NPCDatabase:Exists(name, MiniMap.currentMapName) then
                NPCDatabase:AddNPC(name, x, y, MiniMap.currentMapName, {})
                PrintNpcAdded(name)
            else
                NPCDatabase:UpdateNPCPosition(name, x, y, MiniMap.currentMapName)
            end
        end
    end)

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
end

local function SetupNoteEvents()
    if not MiniMap.noteRenderer then
        return
    end

    local addBtn = MiniMap.noteRenderer:GetAddButton()
    if addBtn then
        addBtn:SetHandler("OnClicked", function()
            local count = NoteDatabase:GetNoteCount()
            if count >= NoteRenderer.MAX_NOTES then
                ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, "Maximum notes reached (" .. NoteRenderer.MAX_NOTES .. ")")
                return
            end
            local noteName = "Note " .. (count + 1)
            MiniMap.noteRenderer:AddNewNote(noteName, "")
            local noteCount = NoteDatabase:GetNoteCount()
            MiniMap.noteRenderer:ShowEditor(noteCount)
        end)
    end

    local closeBtn = MiniMap.noteRenderer:GetCloseButton()
    if closeBtn then
        closeBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:CloseEditor()
        end)
    end

    local prevBtn = MiniMap.noteRenderer:GetPrevButton()
    if prevBtn then
        prevBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:GoToPrevNote()
        end)
    end

    local nextBtn = MiniMap.noteRenderer:GetNextButton()
    if nextBtn then
        nextBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:GoToNextNote()
        end)
    end

    local deleteBtn = MiniMap.noteRenderer:GetDeleteButton()
    if deleteBtn then
        deleteBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:DeleteCurrentNote()
            local noteCount = NoteDatabase:GetNoteCount()
            MiniMap.noteRenderer:ApplyLayout(noteCount)
            MiniMap.noteRenderer:Update(noteCount)
        end)
    end

    local noteItems = MiniMap.noteRenderer:GetNoteItems()
    if noteItems then
        for i, item in ipairs(noteItems) do
            local btn = item.control
            if btn then
                btn:SetHandler("OnClicked", function()
                    if item.index > 0 then
                        MiniMap.noteRenderer:ShowEditor(item.index)
                    end
                end)
            end
        end
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    MiniMap:Initialize()
    SetupNoteEvents()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
