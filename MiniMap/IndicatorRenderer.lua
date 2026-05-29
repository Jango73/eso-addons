IndicatorRenderer = {}

local COMPASS_MARKERS = {
    MINIMAP_COMPASS_N,
    MINIMAP_COMPASS_S,
    MINIMAP_COMPASS_W,
    MINIMAP_COMPASS_E,
}

function IndicatorRenderer:Init(owner)
    self.owner = owner
    self.questMarkers = {}
    self.objectiveMarkers = {}
    self.compassMarkers = {}
    self.compassSize = 0

    for _, id in ipairs(COMPASS_MARKERS) do
        local def = MARKER_DEFINITIONS[id]
        if def then
            self.compassMarkers[id] = {
                definition = def,
                edgeControl = nil,
            }
        end
    end
end

function IndicatorRenderer:AddQuestMarker(id, definition, provider)
    local marker = QuestMarker:New(id, definition, provider, self.owner.root)
    table.insert(self.questMarkers, marker)
    return marker
end

function IndicatorRenderer:ReconcileQuestObjectives(objectives, playerX, playerY, mapRotation, center, radius, margin, mapSize, shortcutX, shortcutY)
    if not objectives then
        for _, marker in ipairs(self.objectiveMarkers) do
            marker:Hide()
        end
        return
    end

    local count = #objectives

    while #self.objectiveMarkers < count do
        local idx = #self.objectiveMarkers + 1
        local marker = QuestMarker:New("objective" .. idx, MARKER_DEFINITIONS[MINIMAP_EDGE_INDICATOR_QUEST], nil, self.owner.root)
        table.insert(self.objectiveMarkers, marker)
    end

    for i = count + 1, #self.objectiveMarkers do
        self.objectiveMarkers[i]:Hide()
    end

    for i, obj in ipairs(objectives) do
        local marker = self.objectiveMarkers[i]
        local tx, ty = obj.x, obj.y
        if shortcutX and shortcutY then
            tx, ty = shortcutX, shortcutY
        end
        marker:UpdateWithCoords(tx, ty, playerX, playerY, mapRotation, center, radius, margin, mapSize)
    end
end

function IndicatorRenderer:ApplyLayout(size)
    self.compassSize = MiniMapRenderUtils.Clamp(math.floor(size * 0.12), 12, 20)

    for _, marker in ipairs(self.questMarkers) do
        marker:ApplyLayout(size)
    end

    for _, marker in ipairs(self.objectiveMarkers) do
        marker:ApplyLayout(size)
    end

    for _, marker in pairs(self.compassMarkers) do
        if marker.edgeControl then
            marker.edgeControl:SetFont("ZoFontHeader")
            marker.edgeControl:SetDimensions(self.compassSize, self.compassSize)
        end
    end
end

function IndicatorRenderer:CreateCompassControl(marker, id)
    local def = marker.definition
    local control = WINDOW_MANAGER:CreateControl("MiniMapCompass" .. def.compassDirection, self.owner.root, CT_LABEL)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetFont("ZoFontHeader")
    control:SetColor(def.color[1], def.color[2], def.color[3], def.color[4] or 1)
    control:SetText(Locale.GetCompassDirection(def.compassDirection))
    control:SetAnchor(CENTER, self.owner.root, CENTER, 0, 0)
    control:SetHidden(true)
    marker.edgeControl = control
end

function IndicatorRenderer:PositionCompassMarker(marker, center, radius, direction, mapRotation)
    local offset = radius - (self.compassSize * 0.7)
    local x, y

    local baseAngle = 0
    if direction == "N" then
        baseAngle = -math.pi / 2
    elseif direction == "S" then
        baseAngle = math.pi / 2
    elseif direction == "W" then
        baseAngle = math.pi
    elseif direction == "E" then
        baseAngle = 0
    else
        return
    end

    local angle = baseAngle + mapRotation

    x = center + offset * math.cos(angle)
    y = center + offset * math.sin(angle)

    marker.edgeControl:ClearAnchors()
    marker.edgeControl:SetAnchor(CENTER, self.owner.root, TOPLEFT, x, y)
    marker.edgeControl:SetHidden(false)
end

function IndicatorRenderer:Update(playerX, playerY, mapRotation, center, radius, margin, mapSize, objectives, shortcutX, shortcutY)
    for _, marker in ipairs(self.questMarkers) do
        marker:Update(playerX, playerY, mapRotation, center, radius, margin, mapSize or self.owner.mapSize)
    end

    self:ReconcileQuestObjectives(objectives, playerX, playerY, mapRotation, center, radius, margin, mapSize or self.owner.mapSize, shortcutX, shortcutY)

    for id, marker in pairs(self.compassMarkers) do
        if not marker.edgeControl then
            self:CreateCompassControl(marker, id)
        end
        local direction = marker.definition.compassDirection
        self:PositionCompassMarker(marker, center, radius, direction, mapRotation)
    end
end
