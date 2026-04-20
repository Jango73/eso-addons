#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="${1:-}"
TARGET_FILE="$ROOT_DIR/MiniMap/MiniMapData.lua"
MAP_KEY_DUMP="$ROOT_DIR/../SavedVariables/MiniMapMapDumper.lua"

usage() {
    cat <<'EOF'
Usage: scripts/import-default-spots.sh source.lua

Imports MiniMapSpots from source.lua into MiniMap/MiniMapData.lua,
using MiniMapDefaultSpots as the target table and MiniMapMapDumper's
SavedVariables to convert localized map names to universal map keys.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

if [[ "${SOURCE_FILE:-}" == "-h" || "${SOURCE_FILE:-}" == "--help" ]]; then
    usage
    exit 0
fi

[[ "$#" -eq 1 ]] || die "expected exactly one source file"
[[ -f "$SOURCE_FILE" ]] || die "source file not found: $SOURCE_FILE"
[[ -f "$TARGET_FILE" ]] || die "target file not found: $TARGET_FILE"
[[ -f "$MAP_KEY_DUMP" ]] || die "map key dump not found: $MAP_KEY_DUMP"

"$ROOT_DIR/scripts/merge_spots.py" \
    --no-backup \
    --map-key-dump "$MAP_KEY_DUMP" \
    --target-var MiniMapDefaultSpots \
    "$SOURCE_FILE" \
    "$TARGET_FILE"
