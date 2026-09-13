#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="CodexNotch"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="${1:-${DIST_DIR:-$ROOT_DIR/dist}}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
RUN_TESTS="${RUN_TESTS:-1}"

cd "$ROOT_DIR"

if [[ "$RUN_TESTS" == "1" ]]; then
    swift test
fi

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN_PATH="$BIN_DIR/$PRODUCT_NAME"
APP_PATH="$DIST_DIR/$PRODUCT_NAME.app"

if [[ ! -x "$BIN_PATH" ]]; then
    echo "error: built executable not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
# Sparkle contains signed installer helpers and symlinks. Preserve both, and
# sign only our outer bundle instead of replacing the vendor's helper signatures.
SPARKLE_FRAMEWORK="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -d "$SPARKLE_FRAMEWORK" ]] || { echo "error: Sparkle framework missing" >&2; exit 1; }
mkdir -p "$APP_PATH/Contents/Frameworks"
ditto "$SPARKLE_FRAMEWORK" "$APP_PATH/Contents/Frameworks/Sparkle.framework"
cp "$ROOT_DIR/.build/checkouts/Sparkle/LICENSE" "$APP_PATH/Contents/Resources/Sparkle-LICENSE.txt"
RESOURCE_BUNDLE="$BIN_DIR/CodexNotch_CodexNotch.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"
fi
"$ROOT_DIR/scripts/build_icon.sh" "$APP_PATH/Contents/Resources/CodexNotch.icns"

if [[ "$SIGN_IDENTITY" != "none" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

echo "Built: $APP_PATH"
