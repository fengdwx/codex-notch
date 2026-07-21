#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${1:-${DIST_DIR:-$ROOT_DIR/dist}}"
VERSION="${VERSION:-$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT_DIR/Resources/Info.plist")}"
ARCH="$(uname -m)"
APP_PATH="$DIST_DIR/CodexNotch.app"
ARCHIVE_PATH="$DIST_DIR/CodexNotch-$VERSION-macOS-$ARCH.zip"
DMG_PATH="$DIST_DIR/CodexNotch-$VERSION-macOS-$ARCH.dmg"
DMG_MOUNT_DIR=""

cleanup_dmg_mount() {
    if [[ -n "$DMG_MOUNT_DIR" ]]; then
        hdiutil detach -quiet "$DMG_MOUNT_DIR" >/dev/null 2>&1 || true
        rmdir "$DMG_MOUNT_DIR" >/dev/null 2>&1 || true
    fi
}

trap cleanup_dmg_mount EXIT

RUN_TESTS="${RUN_TESTS:-1}" \
    "$ROOT_DIR/scripts/build_app.sh" "$DIST_DIR"
"$ROOT_DIR/scripts/verify_app.sh" "$APP_PATH"

rm -f "$ARCHIVE_PATH" "$ARCHIVE_PATH.sha256" "$DMG_PATH" "$DMG_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" | tee "$ARCHIVE_PATH.sha256"

hdiutil create \
    -volname "CodexNotch" \
    -srcfolder "$APP_PATH" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null

DMG_MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-notch-dmg.XXXXXX")"
hdiutil attach -readonly -nobrowse -mountpoint "$DMG_MOUNT_DIR" "$DMG_PATH" >/dev/null
"$ROOT_DIR/scripts/verify_app.sh" "$DMG_MOUNT_DIR/CodexNotch.app"
hdiutil detach -quiet "$DMG_MOUNT_DIR"
rmdir "$DMG_MOUNT_DIR"
DMG_MOUNT_DIR=""

shasum -a 256 "$DMG_PATH" | tee "$DMG_PATH.sha256"
echo "Release ZIP: $ARCHIVE_PATH"
echo "Release DMG: $DMG_PATH"
