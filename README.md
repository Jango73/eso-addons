# MiniMap

MiniMap is an Elder Scrolls Online addon that adds a compact minimap with resource markers, edge indicators, route guidance, and notes.

## Features

- Circular minimap with north-up or player-facing orientation.
- Resource spot markers for gathered and manually added locations.
- Edge indicators for off-map points of interest.
- Route calculation across selected resource categories.
- Optional notes panel.
- Configurable size, opacity, position, refresh rate, toolbar, and auto-save behavior.
- Localized in-game help. English and French are included first.

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
AddOns/MiniMap-1.0.0/MiniMap/
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
/minimap route clear
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

## Packaging

From the repository root:

```bash
scripts/package-addons.sh
```

The package is written to `dist/` and keeps the ESO addon folder at the archive root.

See [PUBLISHING.md](PUBLISHING.md) for ESOUI release notes.
