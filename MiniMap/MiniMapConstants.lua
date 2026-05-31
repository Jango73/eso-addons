
ADDON_NAME = "MiniMap"
DEBUG_ENABLED = true

MINIMAP_ZOOM_MIN = 1
MINIMAP_ZOOM_MAX = 16

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
    world_boss = nil,
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

-- Slash command identifiers
MINIMAP_SLASH_CORNER = "corner"
MINIMAP_SLASH_POSITION = "position"
MINIMAP_SLASH_SIZE = "size"
MINIMAP_SLASH_ORIENTATION = "orientation"
MINIMAP_SLASH_ORIENT = "orient"
MINIMAP_SLASH_OPACITY = "opacity"
MINIMAP_SLASH_ALPHA = "alpha"
MINIMAP_SLASH_ZOOM = "zoom"
MINIMAP_SLASH_HIDE = "hide"
MINIMAP_SLASH_SHOW = "show"
MINIMAP_SLASH_ADD = "add"
MINIMAP_SLASH_SPOTS = "spots"
MINIMAP_SLASH_CLEAR = "clear"
MINIMAP_SLASH_CLEAN = "clean"
MINIMAP_SLASH_POS = "pos"
MINIMAP_SLASH_ROUTE = "route"
MINIMAP_SLASH_ROUTECLEAR = "route-clear"
MINIMAP_SLASH_ROUTEINFO = "route-info"
MINIMAP_SLASH_RESEARCH = "research"
MINIMAP_SLASH_DUPES = "dupes"
MINIMAP_SLASH_INFO = "info"
MINIMAP_SLASH_ALL = "all"
MINIMAP_SLASH_CLOSEST_QUEST = "closest-quest"

-- Companion armor trait categories
COMPANION_TANKING_TRAITS = {
    [ITEM_TRAIT_TYPE_ARMOR_BOLSTERED] = true,
    [ITEM_TRAIT_TYPE_ARMOR_VIGOROUS] = true,
}

COMPANION_DAMAGE_TRAITS = {
    [ITEM_TRAIT_TYPE_ARMOR_AGGRESSIVE] = true,
    [ITEM_TRAIT_TYPE_ARMOR_FOCUSED] = true,
    [ITEM_TRAIT_TYPE_ARMOR_SHATTERING] = true,
    [ITEM_TRAIT_TYPE_ARMOR_PROLIFIC] = true,
}

-- Resource node loot type identifiers (from EVENT_LOOT_RECEIVED soundCategory)
MINIMAP_LOOT_TYPE_RUNE = 15
MINIMAP_LOOT_TYPE_WATER = 19
MINIMAP_LOOT_TYPE_FURNITURE = 22
MINIMAP_LOOT_TYPE_PLANT = 23
MINIMAP_LOOT_TYPE_ORE = 26
MINIMAP_LOOT_TYPE_WOOD = 37
MINIMAP_LOOT_TYPE_SILK = 40

-- Edge texture insets and blend mode for backdrop controls
MINIMAP_EDGE_INSET = 1
MINIMAP_EDGE_BLEND_MODE = 2

-- Edge darken factor for backdrop edge colors
MINIMAP_EDGE_DARKEN_FACTOR = 0.5

-- Epsilon for near-zero length comparisons
MINIMAP_EPSILON = 0.0001

-- Clamp ranges for spot texture marker sizes
MINIMAP_SPOT_TEXTURE_MIN = 18
MINIMAP_SPOT_TEXTURE_MAX = 40

-- Opacity range
MINIMAP_OPACITY_MIN = 20
MINIMAP_OPACITY_MAX = 100

-- sizePercent range
MINIMAP_SIZE_PERCENT_MIN = 10
MINIMAP_SIZE_PERCENT_MAX = 40

-- Orientation values
MINIMAP_ORIENTATION_NORTH = "north"
MINIMAP_ORIENTATION_PLAYER = "player"

-- Default respawn time in seconds (10 minutes)
MINIMAP_DEFAULT_RESPAWN_TIME = 600

-- Spot alpha values based on respawn state (0-1)
MINIMAP_SPOT_ALPHA_COLLECTED = 0.25
MINIMAP_SPOT_ALPHA_RECHARGING = 0.55
MINIMAP_SPOT_ALPHA_AVAILABLE = 1.0

-- Categories whose spots never respawn (one-time collectibles)
MINIMAP_NON_RESPAWNING_CATEGORIES = {
    book = true,
    shard = true,
}
