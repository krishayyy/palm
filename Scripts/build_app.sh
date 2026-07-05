#!/bin/bash
# Builds Palm in release mode and assembles a runnable, ad-hoc-signed Palm.app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building Palm (release)..."
swift build -c release

APP_NAME="Palm.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

BIN_PATH="$(swift build -c release --show-bin-path)"
cp "$BIN_PATH/Palm" "$MACOS_DIR/Palm"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Palm</string>
    <key>CFBundleDisplayName</key>
    <string>Palm</string>
    <key>CFBundleIdentifier</key>
    <string>com.krishay.palm</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Palm</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Palm uses your camera to track your hands so you can type in the air.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Palm uses your microphone for on-device voice dictation.</string>
</dict>
</plist>
PLIST

echo "Ad-hoc code-signing Palm.app..."
codesign --force --deep --sign - "$APP_DIR"

echo "Done. Built $APP_DIR"
echo "First launch: right-click Palm.app > Open (it's ad-hoc signed, not notarized)."
