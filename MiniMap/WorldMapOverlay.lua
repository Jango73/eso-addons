WorldMapOverlay = {}

local WORLD_MAP_OVERLAY_PIN_TYPE = "MiniMapQuestShrine"
local WORLD_MAP_OVERLAY_RING_COLOR = { 1, 1, 1, 1 }
local WORLD_MAP_OVERLAY_RING_SIZE = 40

function WorldMapOverlay:Init()
    self.pinCreated = false
    self.currentWayshrineX = nil
    self.currentWayshrineY = nil
end

function WorldMapOverlay:AddCustomPin()
    if self.pinCreated then
        return
    end

    local pinLayoutData = {
        level = 200,
        size = WORLD_MAP_OVERLAY_RING_SIZE,
        texture = "MiniMap/media/wayshrine_ring.dds",
        tint = ZO_ColorDef:New(
            WORLD_MAP_OVERLAY_RING_COLOR[1],
            WORLD_MAP_OVERLAY_RING_COLOR[2],
            WORLD_MAP_OVERLAY_RING_COLOR[3],
            WORLD_MAP_OVERLAY_RING_COLOR[4]
        ),
    }

    local function PinCallback(pinManager)
        if self.currentWayshrineX and self.currentWayshrineY then
            pinManager:RemovePins(WORLD_MAP_OVERLAY_PIN_TYPE)
            pinManager:CreatePin(_G[WORLD_MAP_OVERLAY_PIN_TYPE], "MiniMapShrine", self.currentWayshrineX, self.currentWayshrineY)
        end
    end

    ZO_WorldMap_AddCustomPin(WORLD_MAP_OVERLAY_PIN_TYPE, PinCallback, nil, pinLayoutData, nil)
    ZO_WorldMap_SetCustomPinEnabled(_G[WORLD_MAP_OVERLAY_PIN_TYPE], true)

    self.pinCreated = true
end

function WorldMapOverlay:Update(wayshrineX, wayshrineY)
    if not ZO_WorldMap_GetPinManager then
        return
    end

    if not self.pinCreated then
        self:AddCustomPin()
    end

    self.currentWayshrineX = wayshrineX
    self.currentWayshrineY = wayshrineY

    ZO_WorldMap_RefreshCustomPinsOfType(_G[WORLD_MAP_OVERLAY_PIN_TYPE])
end

function WorldMapOverlay:Hide()
    self.currentWayshrineX = nil
    self.currentWayshrineY = nil

    if self.pinCreated then
        local pinManager = ZO_WorldMap_GetPinManager()
        if pinManager then
            pinManager:RemovePins(WORLD_MAP_OVERLAY_PIN_TYPE)
        end
    end
end