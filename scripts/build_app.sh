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
"$ROOT_DIR/scripts/build_icon.sh" "$APP_PATH/Contents/Resources/CodexNotch.icns"

if [[ "$SIGN_IDENTITY" != "none" ]]; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

echo "Built: $APP_PATH"
