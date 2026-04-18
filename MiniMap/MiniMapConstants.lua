
MINIMAP_SIZE_FACTOR_PLAYER = 0.1
MINIMAP_SIZE_FACTOR_SPOT_BACKDROP_MARKER = 0.05
MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER = 0.1
MINIMAP_SIZE_FACTOR_EDGE_INDICATOR = 0.2
MINIMAP_SIZE_FACTOR_INSIDE_MARKER = 0.04
MINIMAP_SEGMENT_TEXTURE = "MiniMap/media/segment.dds"
MINIMAP_BORDER_TEXTURE = "MiniMap/media/minimap_compass_border.dds"
MINIMAP_SPOT_DUPLICATE_THRESHOLD = 0.0005
MINIMAP_CITY_ZOOM = 4
MINIMAP_REFRESH_MS = 500
MINIMAP_LOCATION_PROBE_MS = 1000

MINIMAP_TEXTURE_QUEST = "/esoui/art/compass/quest_icon_assisted.dds"
MINIMAP_TEXTURE_WAYSHRINE = "/esoui/art/icons/mapkey/mapkey_wayshrine.dds"
MINIMAP_TEXTURE_NPC = "/esoui/art/icons/mapkey/mapkey_groupmember.dds"

MINIMAP_EDGE_INDICATOR_QUEST = "activeQuest"
MINIMAP_EDGE_INDICATOR_WAYSHRINE = "wayshrine"
MINIMAP_EDGE_INDICATOR_ROUTE = "activeRoute"
MINIMAP_EDGE_INDICATOR_NPC = "npcFind"

MINIMAP_ESO_BORDER_COLOR = { 0.57, 0.56, 0.45, 1 }
MINIMAP_QUEST_COLOR = { 1, 1, 1, 1 }
MINIMAP_WAYSHRINE_COLOR = { 0.5, 0.8, 1, 1 }
MINIMAP_ROUTE_COLOR = { 0.25, 0.25, 0.25, 1 }
MINIMAP_NPC_FIND_COLOR = { 1, 0.2, 0.2, 1 }

MINIMAP_SPOT_TEXTURES = {
    book = nil,
    chest = nil,
    jewelry = "/esoui/art/icons/mapkey/mapkey_jewelrycrafting.dds",
    ore = "/esoui/art/icons/mapkey/mapkey_smithy.dds",
    plant = "/esoui/art/icons/mapkey/mapkey_alchemist.dds",
    rune = "/esoui/art/icons/mapkey/mapkey_enchanter.dds",
    shard = "/esoui/art/icons/mapkey/mapkey_icboneshard.dds",
    silk = "/esoui/art/icons/mapkey/mapkey_clothier.dds",
    thief_chest = nil,
    water = nil,
    wood = "/esoui/art/icons/mapkey/mapkey_woodworker.dds",
    npc = "/esoui/art/icons/mapkey/mapkey_groupmember.dds",
}

MINIMAP_MARKER_TYPE_TEXTURE = "texture"
MINIMAP_MARKER_TYPE_BACKDROP = "backdrop"

MARKER_DEFINITIONS = {
    [MINIMAP_EDGE_INDICATOR_QUEST] = {
        type = MINIMAP_MARKER_TYPE_TEXTURE,
        texture = MINIMAP_TEXTURE_QUEST,
        color = MINIMAP_QUEST_COLOR,
        sizeFactor = MINIMAP_SIZE_FACTOR_EDGE_INDICATOR,
        insideSizeFactor = MINIMAP_SIZE_FACTOR_INSIDE_MARKER,
        hasEdge = true,
        hasInside = true,
    },
    [MINIMAP_EDGE_INDICATOR_WAYSHRINE] = {
        type = MINIMAP_MARKER_TYPE_TEXTURE,
        texture = MINIMAP_TEXTURE_WAYSHRINE,
        color = MINIMAP_WAYSHRINE_COLOR,
        sizeFactor = MINIMAP_SIZE_FACTOR_EDGE_INDICATOR,
        insideSizeFactor = MINIMAP_SIZE_FACTOR_INSIDE_MARKER,
        hasEdge = true,
        hasInside = true,
    },
    [MINIMAP_EDGE_INDICATOR_NPC] = {
        type = MINIMAP_MARKER_TYPE_TEXTURE,
        texture = MINIMAP_TEXTURE_NPC,
        color = MINIMAP_NPC_FIND_COLOR,
        sizeFactor = MINIMAP_SIZE_FACTOR_EDGE_INDICATOR,
        insideSizeFactor = MINIMAP_SIZE_FACTOR_INSIDE_MARKER,
        hasEdge = true,
        hasInside = true,
    },
    [MINIMAP_EDGE_INDICATOR_ROUTE] = {
        edgeType = CT_TEXTURE,
        edgeTexture = "MiniMap/media/edge_indicator_triangle.dds",
        insideType = CT_BACKDROP,
        color = MINIMAP_ROUTE_COLOR,
        sizeFactor = MINIMAP_SIZE_FACTOR_EDGE_INDICATOR,
        insideSizeFactor = MINIMAP_SIZE_FACTOR_INSIDE_MARKER,
        hasEdge = true,
        hasInside = true,
    },
}
