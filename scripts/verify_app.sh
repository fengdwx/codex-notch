#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
if [[ -z "$APP_PATH" ]]; then
    echo "usage: $0 /path/to/CodexNotch.app" >&2
    exit 2
fi

EXECUTABLE="$APP_PATH/Contents/MacOS/CodexNotch"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

[[ -d "$APP_PATH" ]] || { echo "error: app not found: $APP_PATH" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "error: executable missing: $EXECUTABLE" >&2; exit 1; }
[[ -f "$INFO_PLIST" ]] || { echo "error: Info.plist missing: $INFO_PLIST" >&2; exit 1; }

plutil -lint "$INFO_PLIST"

ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST" 2>/dev/null || true)"
ICON_PATH="$APP_PATH/Contents/Resources/${ICON_NAME}.icns"
[[ "$ICON_NAME" == "CodexNotch" ]] || {
    echo "error: CFBundleIconFile must be CodexNotch" >&2
    exit 1
}
[[ -f "$ICON_PATH" ]] || { echo "error: app icon missing: $ICON_PATH" >&2; exit 1; }

SAFE_AREA_COMPATIBILITY_MODE="$(
    /usr/libexec/PlistBuddy \
        -c 'Print :NSPrefersDisplaySafeAreaCompatibilityMode' \
        "$INFO_PLIST" 2>/dev/null || true
)"
[[ "$SAFE_AREA_COMPATIBILITY_MODE" == "false" ]] || {
    echo "error: NSPrefersDisplaySafeAreaCompatibilityMode must be false" >&2
    exit 1
}

ICONSET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-notch-icon-verify.XXXXXX")"
trap 'rm -rf "$ICONSET_DIR"' EXIT
iconutil -c iconset "$ICON_PATH" -o "$ICONSET_DIR/CodexNotch.iconset"
[[ -f "$ICONSET_DIR/CodexNotch.iconset/icon_512x512@2x.png" ]] || {
    echo "error: app icon is missing its 1024px representation" >&2
    exit 1
}

codesign --verify --deep --strict "$APP_PATH"
echo "Verified: $APP_PATH"
