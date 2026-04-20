#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAVED_VARIABLES_FILE="${1:-"$ROOT_DIR/../SavedVariables/MiniMap.lua"}"
MAP_KEY_DUMP="$ROOT_DIR/../SavedVariables/MiniMapMapDumper.lua"

usage() {
    cat <<'EOF'
Usage: scripts/migrate-saved-spots-map-keys.sh [SavedVariables/MiniMap.lua]

Migrates MiniMapSpots map-name keys in the SavedVariables file to universal
map keys using MiniMapMapDumper's SavedVariables. Unresolved map names are
ignored.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

[[ "$#" -le 1 ]] || die "expected zero or one SavedVariables file"
[[ -f "$SAVED_VARIABLES_FILE" ]] || die "SavedVariables file not found: $SAVED_VARIABLES_FILE"
[[ -f "$MAP_KEY_DUMP" ]] || die "map key dump not found: $MAP_KEY_DUMP"

"$ROOT_DIR/scripts/merge_spots.py" \
    --map-key-dump "$MAP_KEY_DUMP" \
    "$SAVED_VARIABLES_FILE" \
    "$SAVED_VARIABLES_FILE"
