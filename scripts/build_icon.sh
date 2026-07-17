#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PATH="$ROOT_DIR/Resources/AppIcon.svg"
OUTPUT_PATH="${1:-}"

[[ -f "$SOURCE_PATH" ]] || { echo "error: icon source missing: $SOURCE_PATH" >&2; exit 1; }
[[ -n "$OUTPUT_PATH" ]] || { echo "usage: $0 /path/to/CodexNotch.icns" >&2; exit 2; }

command -v sips >/dev/null || { echo "error: sips is required to build the app icon" >&2; exit 1; }
command -v iconutil >/dev/null || { echo "error: iconutil is required to build the app icon" >&2; exit 1; }

ICON_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-notch-icon.XXXXXX")"
trap 'rm -rf "$ICON_WORKDIR"' EXIT

MASTER_PNG="$ICON_WORKDIR/AppIcon-1024.png"
ICONSET_PATH="$ICON_WORKDIR/CodexNotch.iconset"
mkdir -p "$ICONSET_PATH" "$(dirname "$OUTPUT_PATH")"
sips -s format png -z 1024 1024 "$SOURCE_PATH" --out "$MASTER_PNG" >/dev/null

render_size() {
    local pixels="$1"
    local filename="$2"
    sips -z "$pixels" "$pixels" "$MASTER_PNG" --out "$ICONSET_PATH/$filename" >/dev/null
}

render_size 16 icon_16x16.png
render_size 32 icon_16x16@2x.png
render_size 32 icon_32x32.png
render_size 64 icon_32x32@2x.png
render_size 128 icon_128x128.png
render_size 256 icon_128x128@2x.png
render_size 256 icon_256x256.png
render_size 512 icon_256x256@2x.png
render_size 512 icon_512x512.png
render_size 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_PATH" -o "$OUTPUT_PATH"
echo "Built app icon: $OUTPUT_PATH"
