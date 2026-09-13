#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="${1:?usage: sign_update.sh /path/to/release.zip [output-appcast.xml]}"
OUTPUT_PATH="${2:-$(dirname "$ARCHIVE_PATH")/appcast.xml}"
TOOLS="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
KEY_ACCOUNT="com.david.codexnotch.sparkle"

[[ -x "$TOOLS/generate_appcast" ]] || { echo "error: run swift package resolve first" >&2; exit 1; }
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-notch-appcast.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$ARCHIVE_PATH" "$STAGING_DIR/$(basename "$ARCHIVE_PATH")"
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT_DIR/Resources/Info.plist")"
NOTES_PATH="$ROOT_DIR/docs/releases/$VERSION.md"
if [[ -f "$NOTES_PATH" ]]; then
    cp "$NOTES_PATH" "$STAGING_DIR/$(basename "${ARCHIVE_PATH%.*}").md"
fi
# Isolating one ZIP prevents DMG/ZIP duplicates and unintended delta generation.
"$TOOLS/generate_appcast" --account "$KEY_ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/fengdwx/codex-notch/releases/download/v$VERSION/" \
    --embed-release-notes -o "$STAGING_DIR/appcast.xml" "$STAGING_DIR"
# Independently verify with only the public key. Missing or wrong publisher
# keys must fail the release, even if generate_appcast emitted an unsigned item.
swift "$ROOT_DIR/scripts/verify_update.swift" "$STAGING_DIR/appcast.xml" \
    "$ARCHIVE_PATH" "$ROOT_DIR/Resources/Info.plist"
mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$STAGING_DIR/appcast.xml" "$OUTPUT_PATH"
echo "Signed update feed: $OUTPUT_PATH"
