
---Print a formatted MiniMap debug message.
---@param message string The message to print.
local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
    end
end

---Print a message to the chat frame.
---@param message string The message text to display.
local function Echo(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(message)
    end
end

---Normalise a corner/position string (supports short aliases and French names).
---@param value string Raw user input.
---@return string|nil Normalised corner key, or nil if invalid.
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

---Check whether a string is a valid resource category key.
---@param cat string The category key to test.
---@return boolean True if the category exists in RESOURCE_CATEGORIES.
local function IsValidCategory(cat)
    for _, c in ipairs(RESOURCE_CATEGORIES) do
        if c.key == cat then return true end
    end
    return false
end

---Get a comma-separated list of all resource category keys.
---@param separator string|nil Separator between keys (default ", ").
---@return string The category list string.
local function GetCategoryList(separator)
    local categories = {}
    for _, c in ipairs(RESOURCE_CATEGORIES) do
        table.insert(categories, c.key)
    end
    return table.concat(categories, separator or ", ")
end

local pendingClearConfirm = nil

---Process a /minimap slash command and dispatch to the appropriate handler.
---@param arguments string The full argument string after "/minimap".
function MiniMap:HandleSlashCommand(arguments)
    local command, value = zo_strmatch(arguments or "", "^(%S*)%s*(.*)$")
    command = zo_strlower(command or "")
    
    if command ~= MINIMAP_SLASH_CLEAR then
        pendingClearConfirm = nil
    end

    if command == MINIMAP_SLASH_CORNER or command == MINIMAP_SLASH_POSITION then
        local corner = NormalizeCorner(value)
        if not corner then
            Print(self:Text("invalidPosition"))
            return
        end

        self.saved.corner = corner
        self:ApplyLayout()
        Print(string.format(self:Text("positionChanged"), corner))
    elseif command == MINIMAP_SLASH_SIZE then
        local sizePercent = tonumber(value)
        if not sizePercent then
            Print(self:Text("invalidSize"))
            return
        end

        self.saved.sizePercent = MiniMapRenderUtils.Clamp(sizePercent, MINIMAP_SIZE_PERCENT_MIN, MINIMAP_SIZE_PERCENT_MAX)
        self:ApplyLayout()
        Print(string.format(self:Text("sizeChanged"), self.saved.sizePercent))
    elseif command == MINIMAP_SLASH_ORIENTATION or command == MINIMAP_SLASH_ORIENT then
        if value ~= MINIMAP_ORIENTATION_NORTH and value ~= MINIMAP_ORIENTATION_PLAYER then
            Print(self:Text("invalidOrientation"))
            return
        end

        self.saved.orientation = (value == MINIMAP_ORIENTATION_PLAYER) and MINIMAP_ORIENTATION_PLAYER or MINIMAP_ORIENTATION_NORTH
        self:UpdatePlayer()
        Print(string.format(self:Text("orientationChanged"), self.saved.orientation))
    elseif command == MINIMAP_SLASH_OPACITY or command == MINIMAP_SLASH_ALPHA then
        local opacity = tonumber(value)
        if not opacity then
            Print(self:Text("invalidOpacity"))
            return
        end

        self.saved.opacity = MiniMapRenderUtils.Clamp(opacity, MINIMAP_OPACITY_MIN, MINIMAP_OPACITY_MAX)
        self.root:SetAlpha(self.saved.opacity / 100)
        Print(string.format(self:Text("opacityChanged"), self.saved.opacity))
    elseif command == MINIMAP_SLASH_ZOOM then
        local zoom = tonumber(value)
        if not zoom then
            Print(self:Text("invalidZoom"))
            return
        end

        self.saved.zoom = MiniMapRenderUtils.Clamp(zoom, MINIMAP_ZOOM_MIN, MINIMAP_ZOOM_MAX)
        self:ApplyLayout()
        Print(string.format(self:Text("zoomChanged"), self.saved.zoom))
    elseif command == MINIMAP_SLASH_HIDE then
        self.saved.hidden = true
        self.root:SetHidden(true)
        self:UpdateToolbarVisibility(false)
        Print(self:Text("hidden"))
    elseif command == MINIMAP_SLASH_SHOW then
        self.saved.hidden = false
        self:UpdatePlayer()
        Print(self:Text("shown"))
    elseif command == MINIMAP_SLASH_ADD then
        if IsValidCategory(value) then
            self:AddSpotAtPlayer(value)
        else
            Echo(string.format(self:Text("usageAdd"), GetCategoryList(", ")))
        end
    elseif command == MINIMAP_SLASH_SPOTS then
        local total = SpotDatabase:GetSpotCount()
        Print(string.format(self:Text("totalSpots"), total))
        for _, cat in ipairs(RESOURCE_CATEGORIES) do
            Print(string.format(self:Text("spotsCount"), cat.key, SpotDatabase:GetSpotCount(cat.key)))
        end
    elseif command == MINIMAP_SLASH_CLEAR then
        if value == MINIMAP_SLASH_ALL then
            if pendingClearConfirm == MINIMAP_SLASH_ALL then
                SpotDatabase:Clear()
                Print(self:Text("allSpotsCleared"))
                pendingClearConfirm = nil
            else
                pendingClearConfirm = MINIMAP_SLASH_ALL
                Print(self:Text("confirmClearSpots"))
            end
        elseif IsValidCategory(value) then
            SpotDatabase:Clear(value)
            Print(string.format(self:Text("spotsCleared"), value))
        else
            Echo(self:Text("usageClear"))
        end
    elseif command == MINIMAP_SLASH_CLEAN then
        local removed = SpotDatabase:CleanDuplicates(true)
        Print(string.format(self:Text("removed"), removed))
    elseif command == MINIMAP_SLASH_POS then
        local x, y = GetMapPlayerPosition("player")
        if x and y then
            Print(string.format(self:Text("position"), x, y))
        else
            Print(self:Text("positionUnknown"))
        end
    elseif command == MINIMAP_SLASH_ROUTE then
        local routeCommand = zo_strlower(zo_strmatch(value or "", "^(%S*)") or "")
        if routeCommand == MINIMAP_SLASH_CLEAR then
            RouteManager:ClearCategories()
            RouteManager:ClearRoute()
            Print(self:Text("routeCleared"))
            return
        elseif routeCommand == MINIMAP_SLASH_INFO then
            if RouteManager:IsRouteActive() then
                Print(RouteManager:GetRouteInfo())
            else
                Print(self:Text("noRouteActive"))
            end
            return
        elseif routeCommand == MINIMAP_SLASH_ALL then
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
    elseif command == MINIMAP_SLASH_ROUTECLEAR then
        RouteManager:ClearCategories()
        RouteManager:ClearRoute()
        Print(self:Text("routeCleared"))
    elseif command == MINIMAP_SLASH_ROUTEINFO then
        if RouteManager:IsRouteActive() then
            Print(RouteManager:GetRouteInfo())
        else
            Print(self:Text("noRouteActive"))
        end
    elseif command == MINIMAP_SLASH_RESEARCH or command == MINIMAP_SLASH_DUPES then
        self:ShowResearchDupes()
    elseif command == MINIMAP_SLASH_CLOSEST_QUEST then
        self:ActivateClosestQuest()
    else
        self:ShowHelp()
    end
end

---Keybind handler to activate the closest quest.
function MINIMAP_CLOSEST_QUEST_KEYBIND()
    MiniMap:ActivateClosestQuest()
end
