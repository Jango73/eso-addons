local ADDON_NAME = "MiniMap"

local DEFAULTS = {
    corner = "bottomright",
    sizePercent = 22,
    orientation = "north",
    zoom = 6,
    hidden = false,
}

local CORNERS = {
    topleft = { anchor = TOPLEFT, relative = TOPLEFT, x = 24, y = 24 },
    topright = { anchor = TOPRIGHT, relative = TOPRIGHT, x = -24, y = 24 },
    bottomleft = { anchor = BOTTOMLEFT, relative = BOTTOMLEFT, x = 24, y = -24 },
    bottomright = { anchor = BOTTOMRIGHT, relative = BOTTOMRIGHT, x = -24, y = -24 },
}

local MiniMap = {
    tiles = {},
    tileCount = 0,
    currentMapName = nil,
    nextMapRefreshMs = 0,
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
    player:SetTexture("EsoUI/Art/MapPins/Map_Pin_player.dds")
    player:SetDrawLayer(DL_OVERLAY)

    local centerDot = WINDOW_MANAGER:CreateControl("MiniMapCenterDot", root, CT_BACKDROP)
    centerDot:SetAnchor(CENTER, root, CENTER, 0, 0)
    centerDot:SetDimensions(8, 8)
    centerDot:SetCenterColor(0.1, 0.75, 1, 1)
    centerDot:SetEdgeColor(0, 0, 0, 1)
    centerDot:SetEdgeTexture("", 1, 1, 1)
    centerDot:SetDrawLayer(DL_OVERLAY)

    self.root = root
    self.background = background
    self.map = map
    self.player = player
    self.centerDot = centerDot
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
    self:ApplyCircularClip()

    local playerSize = Clamp(math.floor(self.size * 0.12), 18, 32)
    self.player:SetDimensions(playerSize, playerSize)

    self:LayoutTiles()
    self:UpdatePlayer()
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

    if SetMapToPlayerLocation then
        SetMapToPlayerLocation()
    end

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

    if self.player.SetTextureRotation then
        if self.saved.orientation == "player" then
            self.player:SetTextureRotation(0)
        else
            self.player:SetTextureRotation(heading or 0)
        end
    end
end

function MiniMap:ShowHelp()
    Print("/minimap corner tl|tr|bl|br")
    Print("/minimap size 10-40")
    Print("/minimap orientation north|player")
    Print("/minimap zoom 2-8")
    Print("/minimap hide | /minimap show")
    Print("/minimapsettings")
end

function MiniMap:RegisterSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        Print("LibAddonMenu-2.0 est introuvable: le menu de settings ne sera pas cree.")
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
            name = "Position",
            tooltip = "Coin de l'ecran ou afficher la minimap.",
            choices = { "Haut gauche", "Haut droite", "Bas gauche", "Bas droite" },
            choicesValues = { "topleft", "topright", "bottomleft", "bottomright" },
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
            name = "Taille",
            tooltip = "Pourcentage de la plus petite dimension de l'ecran.",
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
            name = "Orientation",
            tooltip = "Choisit si le nord ou la direction du joueur reste en haut.",
            choices = { "Nord en haut", "Direction du joueur en haut" },
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
            Print("Coin invalide. Utilise tl, tr, bl ou br.")
            return
        end

        self.saved.corner = corner
        self:ApplyLayout()
        Print("Coin: " .. corner)
    elseif command == "size" or command == "taille" then
        local sizePercent = tonumber(value)
        if not sizePercent then
            Print("Taille invalide. Exemple: /minimap size 22")
            return
        end

        self.saved.sizePercent = Clamp(sizePercent, 10, 40)
        self:ApplyLayout()
        Print("Taille: " .. self.saved.sizePercent .. "%")
    elseif command == "orientation" or command == "orient" then
        if value ~= "north" and value ~= "player" and value ~= "nord" and value ~= "joueur" then
            Print("Orientation invalide. Utilise north ou player.")
            return
        end

        self.saved.orientation = (value == "player" or value == "joueur") and "player" or "north"
        self:UpdatePlayer()
        Print("Orientation: " .. self.saved.orientation)
    elseif command == "zoom" then
        local zoom = tonumber(value)
        if not zoom then
            Print("Zoom invalide. Exemple: /minimap zoom 6")
            return
        end

        self.saved.zoom = Clamp(zoom, 2, 8)
        self:ApplyLayout()
        Print("Zoom: " .. self.saved.zoom)
    elseif command == "hide" or command == "masquer" then
        self.saved.hidden = true
        self.root:SetHidden(true)
        Print("Masquee.")
    elseif command == "show" or command == "afficher" then
        self.saved.hidden = false
        self:UpdatePlayer()
        Print("Affichee.")
    else
        self:ShowHelp()
    end
end

function MiniMap:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("MiniMapSavedVariables", 1, nil, DEFAULTS)

    self:CreateControls()
    self:ApplyLayout()
    self:RefreshMap(true)
    self:RegisterSettingsMenu()

    SLASH_COMMANDS["/minimap"] = function(arguments)
        self:HandleSlashCommand(arguments)
    end

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", 150, function()
        self:UpdatePlayer()
    end)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    MiniMap:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
