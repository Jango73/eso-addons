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
- **FOR DEBUGGING, USE Debug() AND DebugCoalesced() FROM MiniMapDebug.lua AND NOTHING ELSE**

## Dependencies

- LibAddonMenu-2.0
- API 101049

## Saved Variables

- MiniMapSavedVariables: settings
- MiniMapSpots: resource spots

## Release Procedure

When asked to "do a release", follow this sequence:

1. Update version everywhere **except** the changelog first.
2. Build changelog notes from Git history since the previous release.
3. Run packaging with the existing script.
4. Commit release changes and create a version tag.
5. Push branch + tag and create the GitHub release.

### 1) Bump version (without changelog edits)

Update release version consistently in:

- `MiniMap/MiniMap.txt`
  - `## Version: X.Y.Z`
  - `## AddOnVersion: NNNNN` (increment consistently with the release)
- `MiniMap/MiniMap.lua`
  - settings panel `version = 'X.Y.Z'`
- Any release-facing docs/examples that show the current zip/version (README, publishing docs, script examples) when they are meant to reflect the current release.

Do not edit `MiniMap/CHANGELOG.md` in this step.

### 2) Generate changelog from Git

Use Git commits after the previous release (tag or release commit) and summarize into `Added`, `Changed`, `Fixed`:

- Find previous release reference (example):
  - `git describe --tags --abbrev=0`
- Inspect commits since that point:
  - `git log --oneline <previous_release>..HEAD -- MiniMap`
- Inspect relevant diffs when wording notes:
  - `git show --name-only <commit>`
  - `git show <commit> -- <files>`

Then add a new top section in `MiniMap/CHANGELOG.md`:

- `## [X.Y.Z] - YYYY-MM-DD`
- Keep entries factual and based on actual commits.
- Do not rewrite older release sections unless explicitly requested.

### 3) Package

From repository root:

- `scripts/package-addons.sh`

Expected artifact:

- `dist/MiniMap-X.Y.Z.zip`

Quick verification:

- Ensure the archive root contains `MiniMap/` (no extra parent folder like `AddOns/` or `MiniMap-X.Y.Z/`).

### 4) Commit + Tag

Only for an explicit release flow ("do a release"). Do not commit/tag for regular feature or fix tasks.

After a successful packaging run in a release flow:

- Commit release files:
  - `git add AGENTS.md MiniMap/MiniMap.txt MiniMap/MiniMap.lua MiniMap/CHANGELOG.md README.md PUBLISHING.md scripts/package-addons.sh`
  - `git commit -m "Version X.Y.Z"`
- Create an annotated tag:
  - `git tag -a vX.Y.Z -m "Version X.Y.Z"`

Tag format must be exactly `vN.N.N` and tag message must be exactly `Version N.N.N`.

### 5) Push + GitHub Release

Still only for an explicit release flow.

- Push current branch:
  - `git push origin <branch>`
- Push release tag:
  - `git push origin vX.Y.Z`
- Create GitHub release from the tag:
  - Tag: `vX.Y.Z`
  - Title: `Version X.Y.Z`
  - Description: the `## [X.Y.Z] - YYYY-MM-DD` section content from `MiniMap/CHANGELOG.md`
  - Asset: `dist/MiniMap-X.Y.Z.zip`

CLI example:

- `gh release create vX.Y.Z dist/MiniMap-X.Y.Z.zip --title "Version X.Y.Z" --notes-file /tmp/release-notes-X.Y.Z.md`
