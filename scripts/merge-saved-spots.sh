#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="${1:-}"
TARGET_FILE="$ROOT_DIR/MiniMap/MiniMapData.lua"

usage() {
    cat <<'EOF'
Usage: scripts/merge-saved-spots.sh source.lua

Imports MiniMapSpots from source.lua into MiniMap/MiniMapData.lua,
using MiniMapDefaultSpots as the target table.
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

"$ROOT_DIR/scripts/merge_spots.py" \
    --no-backup \
    --clear-source \
    --target-var MiniMapDefaultSpots \
    "$SOURCE_FILE" \
    "$TARGET_FILE"
