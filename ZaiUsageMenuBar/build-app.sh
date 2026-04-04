#!/bin/bash
set -e

APP_NAME="ZaiUsageMenuBar"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Build release binary
swift build -c release

# Create app bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Generate .icns from asset catalog
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
ASSETS="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle/Assets.xcassets/AppIcon.appiconset"
cp "$ASSETS/icon_16x16.png" "$ICONSET/icon_16x16.png"
cp "$ASSETS/icon_16x16@2x.png" "$ICONSET/icon_16x16@2x.png"
cp "$ASSETS/icon_32x32.png" "$ICONSET/icon_32x32.png"
cp "$ASSETS/icon_32x32@2x.png" "$ICONSET/icon_32x32@2x.png"
cp "$ASSETS/icon_128x128.png" "$ICONSET/icon_128x128.png"
cp "$ASSETS/icon_128x128@2x.png" "$ICONSET/icon_128x128@2x.png"
cp "$ASSETS/icon_256x256.png" "$ICONSET/icon_256x256.png"
cp "$ASSETS/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ASSETS/icon_512x512.png" "$ICONSET/icon_512x512.png"
cp "$ASSETS/icon_512x512@2x.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ZaiUsageMenuBar</string>
    <key>CFBundleDisplayName</key>
    <string>Zai Usage</string>
    <key>CFBundleIdentifier</key>
    <string>com.zai.usage-menubar</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>ZaiUsageMenuBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMainNibFile</key>
    <string></string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

echo "App bundle created at: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"

# Ad-hoc sign the app bundle for Gatekeeper compatibility
codesign --force --sign - --options runtime "$APP_BUNDLE"
echo "App bundle signed"
