
MINIMAP_SIZE_FACTOR_PLAYER = 0.1
MINIMAP_SIZE_FACTOR_SPOT_BACKDROP_MARKER = 0.05
MINIMAP_SIZE_FACTOR_SPOT_TEXTURE_MARKER = 0.1
MINIMAP_SIZE_FACTOR_EDGE_INDICATOR = 0.2
MINIMAP_SIZE_FACTOR_INSIDE_MARKER = 0.04
MINIMAP_SEGMENT_TEXTURE = "MiniMap/media/segment.dds"
MINIMAP_BORDER_TEXTURE = "MiniMap/media/minimap_compass_border.dds"
MINIMAP_SPOT_DUPLICATE_THRESHOLD = 0.0005
MINIMAP_CITY_ZOOM = 2
MINIMAP_REFRESH_MS = 500
MINIMAP_LOCATION_PROBE_MS = 1000

MINIMAP_TEXTURE_QUEST = "/esoui/art/compass/quest_icon_assisted.dds"
MINIMAP_TEXTURE_WAYSHRINE = "/esoui/art/icons/mapkey/mapkey_wayshrine.dds"

MINIMAP_EDGE_INDICATOR_QUEST = "activeQuest"
MINIMAP_EDGE_INDICATOR_WAYSHRINE = "wayshrine"
MINIMAP_EDGE_INDICATOR_ROUTE = "activeRoute"

MINIMAP_COMPASS_N = "compassN"
MINIMAP_COMPASS_S = "compassS"
MINIMAP_COMPASS_W = "compassW"
MINIMAP_COMPASS_E = "compassE"

MINIMAP_ESO_BORDER_COLOR = { 0.57, 0.56, 0.45, 1 }
MINIMAP_QUEST_COLOR = { 1, 1, 1, 1 }
MINIMAP_WAYSHRINE_COLOR = { 1, 1, 1, 1 }
MINIMAP_ROUTE_COLOR = { 0.25, 0.25, 0.25, 1 }
MINIMAP_COMPASS_COLOR = { 0.8, 0.8, 0.7, 1 }

MINIMAP_NOTES_PANEL_COLOR = { 0, 0, 0, 0.7 }
MINIMAP_NOTES_EDITOR_COLOR = { 0, 0, 0, 0.85 }
MINIMAP_NOTES_ADD_COLOR = { 0.3, 0.6, 0.3, 0.8 }
MINIMAP_NOTES_ADD_EDGE_COLOR = { 0.5, 0.8, 0.5, 1 }
MINIMAP_NOTES_CONTROL_COLOR = { 0.15, 0.15, 0.15, 0.85 }
MINIMAP_NOTES_CONTROL_EDGE_COLOR = { 0.35, 0.35, 0.35, 1 }
MINIMAP_NOTES_ITEM_COLOR = { 0.15, 0.15, 0.15, 0.7 }
MINIMAP_NOTES_ITEM_EDGE_COLOR = { 0.3, 0.3, 0.3, 1 }
MINIMAP_NOTES_CLOSE_COLOR = { 0.45, 0.45, 0.45, 0.86 }
MINIMAP_NOTES_NAV_COLOR = { 0.12, 0.38, 0.62, 0.86 }
MINIMAP_NOTES_DELETE_COLOR = { 0.72, 0.16, 0.16, 0.86 }

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
}

MINIMAP_MARKER_TYPE_TEXTURE = "texture"
MINIMAP_MARKER_TYPE_BACKDROP = "backdrop"
MINIMAP_MARKER_TYPE_LABEL = "label"

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
    [MINIMAP_COMPASS_N] = {
        type = MINIMAP_MARKER_TYPE_LABEL,
        text = "N",
        color = MINIMAP_COMPASS_COLOR,
        hasEdge = true,
        compassDirection = "N",
    },
    [MINIMAP_COMPASS_S] = {
        type = MINIMAP_MARKER_TYPE_LABEL,
        text = "S",
        color = MINIMAP_COMPASS_COLOR,
        hasEdge = true,
        compassDirection = "S",
    },
    [MINIMAP_COMPASS_W] = {
        type = MINIMAP_MARKER_TYPE_LABEL,
        text = "W",
        color = MINIMAP_COMPASS_COLOR,
        hasEdge = true,
        compassDirection = "W",
    },
    [MINIMAP_COMPASS_E] = {
        type = MINIMAP_MARKER_TYPE_LABEL,
        text = "E",
        color = MINIMAP_COMPASS_COLOR,
        hasEdge = true,
        compassDirection = "E",
    },
}
