# MiniMap

MiniMap is an Elder Scrolls Online addon that adds a compact minimap with resource markers, edge indicators, route guidance, and notes.

## Features

- Circular minimap with north-up or player-facing orientation.
- Resource spot markers for gathered and manually added locations.
- Edge indicators for off-map points of interest.
- Route calculation across selected resource categories.
- Optional notes panel.
- Research duplicate detection for researchable trait gear (backpack + bank).
- Red `X` overlay in inventory/bank/merchant sell view on items selected as sellable duplicates.
- Research duplicate quality filters (rare / epic / legendary).
- Configurable size, opacity, position, refresh rate, toolbar, notes panel, and auto-save behavior.
- Localized strings for `en`, `fr`, `es`, `ja`, `de`, `ru`, `zh`.

## Requirements

- Elder Scrolls Online API `101049`
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)

## Installation

Install the addon folder into your ESO AddOns directory:

```text
Elder Scrolls Online/live/AddOns/MiniMap/
```

The manifest must be directly inside the addon folder:

```text
MiniMap/MiniMap.txt
```

Do not install it as:

```text
AddOns/MiniMap-1.3.0/MiniMap/
AddOns/AddOns/MiniMap/
```

## Basic Usage

Open the settings panel with:

```text
/minimapsettings
```

Show the in-game help with:

```text
/minimap help
```

Common commands:

```text
/minimap show
/minimap hide
/minimap size 22
/minimap opacity 80
/minimap orientation north
/minimap orientation player
/minimap route all
/minimap route <category...>
/minimap route info
/minimap route clear
/minimap routeclear
/minimap routeinfo
/minimap research
/minimap dupes
```

## Resource Spots

MiniMap can save resource spots automatically when loot is collected, or manually through the toolbar and slash commands.

Useful commands:

```text
/minimap add <category>
/minimap spots
/minimap clear <category>
/minimap clear all
/minimap clean
```

## Bundled Spot Data

The addon ships with a small default spot database in `MiniMap/MiniMapData.lua`. This default database is barely started and will grow over time as you collect resource spots while playing. The more you play, the more complete it becomes. To merge spots from an exported `MiniMapSpots` saved-variable file into that bundled data table, run:

```bash
scripts/merge-saved-spots.sh source.lua
```

This is a merge, not a replacement. Existing bundled spots are kept, source spots are added only when they are not duplicates, and duplicate detection uses the addon threshold `MINIMAP_SPOT_DUPLICATE_THRESHOLD`.

Warning: the import script clears the source `MiniMapSpots` table after a successful merge. The source is expected to be the game's `SavedVariables/MiniMap.lua` file. Do not run this import while ESO is running, because the game can rewrite its saved variables on exit and restore the old in-memory data.

## Routes

Routes can be calculated for selected resource categories or for all known resource spots in the current map.

```text
/minimap route all
/minimap route ore wood plant
/minimap route info
/minimap route clear
```

## Notes

The notes panel can be enabled or disabled in the settings panel. Notes are stored in the `MiniMapNotes` saved variable.

## Research Duplicates

`/minimap research` (alias `/minimap dupes`) analyzes researchable trait duplicates across backpack and bank, picks one item to keep in each duplicate group, and reports sellable duplicates.

Matching items are also marked in list UIs with a red `X` overlay:

- Player inventory
- Bank inventory
- Merchant sell view

## Packaging

From the repository root:

```bash
scripts/package-addons.sh
```

The package is written to `dist/` and keeps the ESO addon folder at the archive root.

See [PUBLISHING.md](PUBLISHING.md) for ESOUI release notes.
