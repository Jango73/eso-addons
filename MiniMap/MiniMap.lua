
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
    currentMapKey = nil,
    currentMapType = nil,
    nextMapRefreshMs = 0,
    nextLocationProbeMs = 0,
    nextQuestBreadcrumbRefreshMs = 0,
    nextWayshrineRouteUpdateMs = 0,
    isCityMap = false,
    questIndicatorWayshrineX = nil,
    questIndicatorWayshrineY = nil,
}

local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
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
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, Locale.GetString("spotAdded"):format(category))
end

local function PrintSpotDeleted(count)
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, Locale.GetString("spotsDeleted"):format(count))
end

local function IsValidCategory(cat)
    for _, c in ipairs(RESOURCE_CATEGORIES) do
        if c.key == cat then return true end
    end
    return false
end

local function GetCategoryList(separator)
    local categories = {}
    for _, c in ipairs(RESOURCE_CATEGORIES) do
        table.insert(categories, c.key)
    end
    return table.concat(categories, separator or "|")
end

local function GetPlayerMapPosition()
    local x, y, _ = GetMapPlayerPosition("player")
    return x, y
end

local function AddSpotAtPlayer(category)
    local x, y = GetPlayerMapPosition()
    if x and y then
        local added, isNew = SpotDatabase:AddSpot(x, y, category, MiniMap.currentMapKey)
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
    self.spotRenderer:Init(self)

    self.noteRenderer = NoteRenderer
    self.noteRenderer:Init(self)

    self.routeRenderer = RouteRenderer
    self.routeRenderer:Init(self, self.routeManager)

    self.indicatorRenderer = IndicatorRenderer
    self.indicatorRenderer:Init(self, {
        [MINIMAP_EDGE_INDICATOR_QUEST] = function()
            if self.questIndicatorWayshrineX then
                return self.questIndicatorWayshrineX, self.questIndicatorWayshrineY
            end
            return self:GetActiveQuestTargetPosition()
        end,
        [MINIMAP_EDGE_INDICATOR_WAYSHRINE] = function()
            if self.questIndicatorWayshrineX then
                return nil, nil
            end
            return self:GetNearestWayshrinePosition()
        end,
        [MINIMAP_EDGE_INDICATOR_ROUTE] = function()
            return self.routeRenderer:GetNearestRoutePoint(self.playerMapX, self.playerMapY)
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

    self:UpdateToolbarVisibility()

    if self.noteRenderer then
        local noteCount = NoteDatabase:GetNoteCount()
        self.noteRenderer:ApplyLayout(noteCount)
        self.noteRenderer:Update(noteCount)
    end
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
        return
    end

    self.toolbarVisibleSinceMs = self.toolbarVisibleSinceMs or now
    if now - self.toolbarVisibleSinceMs >= 150 then
        self.toolbar:SetHidden(false)
    else
        self.toolbar:SetHidden(true)
    end
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
        version = '1.2.0',
        slashCommand = '/minimapsettings',
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        {
            type = 'header',
            name = self:Text('helpHeader'),
            width = 'full',
        },
        {
            type = 'description',
            text = self:Text('helpOverview') .. "\n\n"
                .. self:Text('helpResources') .. "\n\n"
                .. self:Text('helpRoutes') .. "\n\n"
                .. self:Text('helpNotes') .. "\n\n"
                .. self:Text('helpCommandsTitle') .. "\n"
                .. self:Text('helpSettings') .. "\n"
                .. self:Text('helpVisibility') .. "\n"
                .. self:Text('helpRoute'),
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
            name = self:Text('zoomName'),
            tooltip = self:Text('zoomTooltip'),
            min = 2,
            max = 16,
            step = 1,
            getFunc = function()
                return self.saved.zoom or DEFAULTS.zoom
            end,
            setFunc = function(value)
                self.saved.zoom = MiniMapRenderUtils.Clamp(value, 1, 16)
                self:RefreshMap(true)
            end,
            default = DEFAULTS.zoom,
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
            name = self:Text('showToolbarName'),
            tooltip = self:Text('showToolbarTooltip'),
            getFunc = function()
                return self.saved.showToolbar
            end,
            setFunc = function(value)
                self.saved.showToolbar = value
                self:ApplyToolbarLayout()
                self:UpdateToolbarVisibility()
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
        {
            type = 'header',
            name = self:Text('researchFiltersHeader'),
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchIncludeRareName'),
            tooltip = self:Text('researchIncludeRareTooltip'),
            getFunc = function()
                return self.saved.researchIncludeRare ~= false
            end,
            setFunc = function(value)
                self.saved.researchIncludeRare = value
            end,
            default = DEFAULTS.researchIncludeRare,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchIncludeEpicName'),
            tooltip = self:Text('researchIncludeEpicTooltip'),
            getFunc = function()
                return self.saved.researchIncludeEpic == true
            end,
            setFunc = function(value)
                self.saved.researchIncludeEpic = value
            end,
            default = DEFAULTS.researchIncludeEpic,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchIncludeLegendaryName'),
            tooltip = self:Text('researchIncludeLegendaryTooltip'),
            getFunc = function()
                return self.saved.researchIncludeLegendary == true
            end,
            setFunc = function(value)
                self.saved.researchIncludeLegendary = value
            end,
            default = DEFAULTS.researchIncludeLegendary,
            width = 'full',
        },
    }

    LAM:RegisterAddonPanel('MiniMapSettings', panelData)
    LAM:RegisterOptionControls('MiniMapSettings', optionsTable)
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
    if not questIndex or not WORLD_MAP_QUEST_BREADCRUMBS or not self.playerMapX or not self.playerMapY then
        return nil
    end

    local bestX, bestY
    local bestDistanceSq
    local mainStepIndex = QUEST_MAIN_STEP_INDEX or 1
    local numSteps = GetJournalQuestNumSteps and GetJournalQuestNumSteps(questIndex) or mainStepIndex

    for stepIndex = mainStepIndex, numSteps do
        local numPositions = WORLD_MAP_QUEST_BREADCRUMBS:GetNumQuestConditionPositions(questIndex, stepIndex)
        if numPositions then
            for conditionIndex = 1, numPositions do
                local positionData = WORLD_MAP_QUEST_BREADCRUMBS:GetQuestConditionPosition(questIndex, stepIndex, conditionIndex)
                if positionData and positionData.insideCurrentMapWorld and positionData.xLoc and positionData.yLoc then
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
        return bestX, bestY
    end

    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if WORLD_MAP_QUEST_BREADCRUMBS.RefreshQuest and now >= self.nextQuestBreadcrumbRefreshMs then
        self.nextQuestBreadcrumbRefreshMs = now + 3000
        WORLD_MAP_QUEST_BREADCRUMBS:RefreshQuest(questIndex)
    end

    return nil
end

local POI_TYPE_WAYSHRINE = 1

function MiniMap:GetNearestWayshrinePosition()
    local px, py = self.playerMapX, self.playerMapY
    if not px or not py then
        return nil
    end
    return self:GetNearestWayshrineToPosition(px, py)
end

function MiniMap:GetNearestWayshrineToPosition(px, py)
    if not px or not py then
        return nil, nil, nil
    end

    local numNodes = GetNumFastTravelNodes()
    if not numNodes or numNodes == 0 then
        return nil, nil, nil
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

    if nearestX then
        return nearestX, nearestY, math.sqrt(nearestDist)
    end
    return nil, nil, nil
end

function MiniMap:GetNearestKnownWayshrineToPosition(px, py)
    if not px or not py then
        return nil, nil, nil
    end

    local numNodes = GetNumFastTravelNodes()
    if not numNodes or numNodes == 0 then
        return nil, nil, nil
    end

    local nearestDist = math.huge
    local nearestX, nearestY

    for i = 1, numNodes do
        local known, name, x, y, icon, glowIcon, poiType, isShown, linkedLocked = GetFastTravelNodeInfo(i)
        if known and x and y and poiType == POI_TYPE_WAYSHRINE then
            local dx = x - px
            local dy = y - py
            local dist = dx * dx + dy * dy
            if dist < nearestDist then
                nearestDist = dist
                nearestX, nearestY = x, y
            end
        end
    end

    if nearestX then
        return nearestX, nearestY, math.sqrt(nearestDist)
    end
    return nil, nil, nil
end

function MiniMap:UpdateQuestIndicatorWayshrine()
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if now < self.nextWayshrineRouteUpdateMs then
        return
    end
    self.nextWayshrineRouteUpdateMs = now + 1000

    local px, py = self.playerMapX, self.playerMapY
    local qx, qy = self:GetActiveQuestTargetPosition()

    if not px or not py or not qx or not qy then
        self.questIndicatorWayshrineX = nil
        self.questIndicatorWayshrineY = nil
        return
    end

    local dxD = qx - px
    local dyD = qy - py
    local distD = math.sqrt(dxD * dxD + dyD * dyD)

    local wayshrinePlayerX, wayshrinePlayerY, distA = self:GetNearestWayshrineToPosition(px, py)
    if not wayshrinePlayerX then
        self.questIndicatorWayshrineX = nil
        self.questIndicatorWayshrineY = nil
        return
    end

    local wayshrineQuestX, wayshrineQuestY, distB = self:GetNearestKnownWayshrineToPosition(qx, qy)
    if not wayshrineQuestX then
        self.questIndicatorWayshrineX = nil
        self.questIndicatorWayshrineY = nil
        return
    end

    local sameWayshrine = (wayshrinePlayerX == wayshrineQuestX and wayshrinePlayerY == wayshrineQuestY)
    if sameWayshrine then
        self.questIndicatorWayshrineX = nil
        self.questIndicatorWayshrineY = nil
    elseif distA + distB < distD then
        self.questIndicatorWayshrineX = wayshrinePlayerX
        self.questIndicatorWayshrineY = wayshrinePlayerY
    else
        self.questIndicatorWayshrineX = nil
        self.questIndicatorWayshrineY = nil
    end
end

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

function MiniMap:UpdateMapOverlays(playerX, playerY, mapRotation)
    local radius = self.size / 2
    local center = radius
    local margin = self.spotRenderer:GetMargin()

    self.spotRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, self.currentMapKey)
    self.routeRenderer:Update(playerX, playerY, mapRotation, center, radius, self.currentMapKey)

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
        "helpResearch",
    }

    for _, key in ipairs(helpLines) do
        Echo(self:Text(key))
    end
end

function MiniMap:ShowResearchDupes()
    local items = {}
    local bags = { BAG_BACKPACK }
    local rareQuality = ITEM_QUALITY_ARCANE or 3
    local epicQuality = ITEM_QUALITY_ARTIFACT or 4
    local legendaryQuality = ITEM_QUALITY_LEGENDARY or 5
    if IsBankOpen then
        table.insert(bags, BAG_BANK)
    end

    for _, bag in ipairs(bags) do
        local bagName = (bag == BAG_BANK) and "bank" or "backpack"
        for slot = 0, GetBagSize(bag) - 1 do
            local link = GetItemLink(bag, slot)
            if link and link ~= "" then
                local itemType = GetItemLinkItemType(link)
                local equipType = GetItemLinkEquipType(link)
                local name = GetItemLinkName(link)
                local isHeavy = (itemType == 2 and GetItemLinkArmorType(link) == 3)
                local isMedium = (itemType == 2 and GetItemLinkArmorType(link) == 2)
                local isLight = (itemType == 2 and GetItemLinkArmorType(link) == 1)
                local isWeapon = itemType == 1
                local isJewelry = (itemType == 3) or (equipType == EQUIP_TYPE_RING) or (equipType == EQUIP_TYPE_NECK)

                if isLight or isMedium or isHeavy or isWeapon or isJewelry then
                    local itemId = GetItemLinkItemId(link)
                    local armorType = GetItemLinkArmorType(link)
                    local traitType = GetItemLinkTraitType(link)
                    local quality = GetItemLinkQuality(link)
                    local includeQuality = true

                    if quality == rareQuality then
                        includeQuality = self.saved.researchIncludeRare ~= false
                    elseif quality == epicQuality then
                        includeQuality = self.saved.researchIncludeEpic == true
                    elseif quality == legendaryQuality then
                        includeQuality = self.saved.researchIncludeLegendary == true
                    end

                    if includeQuality then
                        local key
                        if isWeapon then
                            key = "w|" .. GetItemLinkWeaponType(link) .. "|" .. traitType
                        elseif isJewelry then
                            key = "j|" .. equipType .. "|" .. traitType
                        else
                            key = "a|" .. armorType .. "|" .. equipType .. "|" .. traitType
                        end

                        if not items[key] then
                            items[key] = { name = name, itemId = itemId, traitType = traitType, quality = quality, count = 0, slots = {}, itemNames = {} }
                        end

                        items[key].count = items[key].count + 1
                        table.insert(items[key].itemNames, name)

                        if quality > items[key].quality then
                            items[key].quality = quality
                            items[key].name = name
                        end

                        table.insert(items[key].slots, bagName .. ":" .. slot)
                    end
                end
            end
        end
    end

    local dupes = {}
    for _, data in pairs(items) do
        if data.count > 1 then
            table.insert(dupes, data)
        end
    end

    if #dupes == 0 then
        Print(self:Text("noResearchDupes"))
        return
    end

    table.sort(dupes, function(a, b) return a.count > b.count end)

    Print("--------------------")
    Print(string.format(self:Text("researchDupesFound"), #dupes))
    for _, data in ipairs(dupes) do
        local traitName = Locale.GetTraitName(data.traitType)
        local keepStr = data.name .. " (" .. traitName .. ")"
        local dupeCount = data.count - 1
        local junkNames = {}
        for _, n in ipairs(data.itemNames) do
            if n ~= data.name then
                table.insert(junkNames, n)
            end
        end
        local junkStr = table.concat(junkNames, ", ")
        Print(string.format("Can sell: %s (have %s)", junkStr, keepStr))
    end
end

function MiniMap:HandleSlashCommand(arguments)
    local command, value = zo_strmatch(arguments or "", "^(%S*)%s*(.*)$")
    command = zo_strlower(command or "")
    
    if command ~= "clear" then
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

        self.saved.zoom = MiniMapRenderUtils.Clamp(zoom, 1, 16)
        self:ApplyLayout()
        Print(string.format(self:Text("zoomChanged"), self.saved.zoom))
    elseif command == "hide" or command == "masquer" then
        self.saved.hidden = true
        self.root:SetHidden(true)
        self:UpdateToolbarVisibility(false)
        Print(self:Text("hidden"))
    elseif command == "show" or command == "afficher" then
        self.saved.hidden = false
        self:UpdatePlayer()
        Print(self:Text("shown"))
    elseif command == "add" then
        if IsValidCategory(value) then
            AddSpotAtPlayer(value)
        else
            Echo(string.format(self:Text("usageAdd"), GetCategoryList("|")))
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
            Echo(self:Text("usageClear"))
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
            RouteManager:CalculateRoute(self.playerMapX, self.playerMapY, self.currentMapKey)
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
            Echo(self:Text("usageRoute"))
            Echo(string.format(self:Text("usageRouteAvailable"), "all " .. GetCategoryList(" ")))
            return
        end

        RouteManager:ClearCategories()
        for _, cat in ipairs(categories) do
            RouteManager:ToggleCategory(cat)
        end

        RouteManager:CalculateRoute(self.playerMapX, self.playerMapY, self.currentMapKey)
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
    elseif command == "research" or command == "dupes" then
        self:ShowResearchDupes()
    else
        self:ShowHelp()
    end
end

function MiniMap:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("MiniMapSavedVariables", 1, nil, DEFAULTS)

    self.spots = ZO_SavedVars:NewAccountWide("MiniMapSpots", 1, nil, {})
    SpotDatabase:Init(self.spots)

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
        MiniMap:UpdateQuestIndicatorWayshrine()

        if sceneShown then
            MiniMap.root:SetHidden(true)
            MiniMap:UpdateToolbarVisibility(false)
            if MiniMap.noteRenderer then MiniMap.noteRenderer:CloseEditor() end
            if MiniMap.noteRenderer and MiniMap.noteRenderer.notesPanel then MiniMap.noteRenderer.notesPanel:SetHidden(true) end
            lastMapOpen = true
        elseif not MiniMap.saved.hidden then
            local isHudShowing = MiniMap:IsHudShowing()
            MiniMap:UpdateToolbarVisibility(isHudShowing)
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
