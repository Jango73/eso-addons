#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-"$ROOT_DIR/dist"}"

usage() {
    cat <<'EOF'
Usage: scripts/package-addons.sh [addon ...]

Packages ESO addons into dist/.

Without arguments, packages every first-party addon discovered with:
  AddOnName/AddOnName.txt

The zip file includes the addon folder at its root, for example:
  MiniMap-1.0.0.zip
    MiniMap/
      MiniMap.txt
      MiniMap.lua
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

manifest_value() {
    local manifest="$1"
    local key="$2"

    awk -v key="$key" '
        $0 ~ "^##[[:space:]]*" key ":" {
            sub("^##[[:space:]]*" key ":[[:space:]]*", "")
            print
            exit
        }
    ' "$manifest"
}

sanitize_filename_part() {
    local value="$1"

    value="${value// /_}"
    value="${value//\//_}"
    value="${value//\\/_}"
    printf '%s' "$value"
}

discover_addons() {
    local addon_dir addon_name

    for addon_dir in "$ROOT_DIR"/*/; do
        addon_name="$(basename "$addon_dir")"

        case "$addon_name" in
            dist|scripts|MiniMapMapDumper|.*)
                continue
                ;;
        esac

        if [[ -f "$addon_dir/$addon_name.txt" ]]; then
            printf '%s\n' "$addon_name"
        fi
    done
}

package_addon() {
    local addon_name="$1"
    local addon_dir="$ROOT_DIR/$addon_name"
    local manifest="$addon_dir/$addon_name.txt"
    local version archive_name archive_path

    [[ -d "$addon_dir" ]] || die "addon directory not found: $addon_name"
    [[ -f "$manifest" ]] || die "manifest not found: $addon_name/$addon_name.txt"

    version="$(manifest_value "$manifest" "Version")"
    if [[ -n "$version" ]]; then
        archive_name="$addon_name-$(sanitize_filename_part "$version").zip"
    else
        archive_name="$addon_name.zip"
    fi
    archive_path="$DIST_DIR/$archive_name"

    rm -f "$archive_path"

    (
        cd "$ROOT_DIR"
        zip -qr "$archive_path" "$addon_name" \
            -x "$addon_name/temp/*" \
            -x "$addon_name/.git/*" \
            -x "$addon_name/.DS_Store" \
            -x "$addon_name/*~"
    )

    echo "packaged $addon_name -> dist/$archive_name"
}

main() {
    local addons=()
    local addon

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    command -v zip >/dev/null 2>&1 || die "zip is required"
    mkdir -p "$DIST_DIR"

    if [[ "$#" -gt 0 ]]; then
        addons=("$@")
    else
        while IFS= read -r addon; do
            addons+=("$addon")
        done < <(discover_addons)
    fi

    [[ "${#addons[@]}" -gt 0 ]] || die "no addons found"

    for addon in "${addons[@]}"; do
        package_addon "$addon"
    done
}

main "$@"
