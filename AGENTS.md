# MiniMap

Elder Scrolls Online minimap addon with resource markers, edge indicators, TSP route, and notes.

## Structure

```
MiniMap/
├── MiniMap.lua           # Entry point, events, UI
├── MiniMapConstants.lua  # Constants (MARKER_DEFINITIONS, RESOURCE_CATEGORIES)
├── MiniMapRenderUtils.lua # Shared utilities (Clamp, WorldToLocal)
├── Settings.lua          # DEFAULTS, CORNERS, STRINGS
├── SpotDatabase.lua      # Spot CRUD (uses RESOURCE_CATEGORIES)
├── SpotRenderer.lua      # Renders spots on minimap
├── RouteManager.lua      # TSP calculation
├── RouteRenderer.lua     # Route rendering
├── IndicatorRenderer.lua # Edge indicators (quest, wayshrine, route)
└── MiniMap.txt           # Manifest
```

## Rules

- **No code duplication**: extract shared functions to MiniMapRenderUtils.lua
- Use constants from MiniMapConstants.lua and Settings.lua
- Renderer pattern: `Init(owner)`, `Update(...)`, `ApplyLayout(size)`
- Iterate categories with `ForEachCategory(callback)` using RESOURCE_CATEGORIES
- Private vars use underscore prefix (`_data`, `_selectedCategories`)
- For debugging, use CHAT_ROUTER:AddDebugMessage()

## Dependencies

- LibAddonMenu-2.0
- API 101049

## Saved Variables

- MiniMapSavedVariables: settings
- MiniMapSpots: resource spots
