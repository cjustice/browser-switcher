#!/usr/bin/env bash
# Build BrowserSwitcher.app from the SwiftPM executable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
APP_NAME="Browser Switcher"
EXEC_NAME="BrowserSwitcher"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP_BUNDLE="$ROOT/build/$APP_NAME.app"

cd "$ROOT"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXEC_NAME" "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
cp "$ROOT/Sources/BrowserSwitcher/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/Sources/BrowserSwitcher/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so launching via Finder / login items behaves.
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

echo "==> done: $APP_BUNDLE"
