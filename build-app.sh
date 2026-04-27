#!/bin/bash
set -e

APP_NAME="ZaiUsageMenuBar"
PROJECT="$APP_NAME.xcodeproj"
SCHEME="$APP_NAME"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

resolve_signing_identity() {
    if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
        echo "$SIGNING_IDENTITY"
        return
    fi

    security find-identity -v -p codesigning | awk -F'"' '/"[^"]+"/ { print $2; exit }'
}

# Build release with xcodebuild
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    CONFIGURATION_BUILD_DIR="$PWD/$BUILD_DIR" \
    clean build \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    | tail -5

# Generate .icns from asset catalog
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
ASSETS="ZaiUsageMenuBar/Assets.xcassets/AppIcon.appiconset"
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

echo "App bundle created at: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"

SIGNING_IDENTITY="$(resolve_signing_identity)"

if [[ -z "$SIGNING_IDENTITY" ]]; then
    if [[ "${ALLOW_ADHOC_SIGNING:-0}" == "1" ]]; then
        SIGNING_IDENTITY="-"
        echo "Warning: no signing certificate found, using ad-hoc signing."
    else
        echo "Error: no code-signing identity found."
        echo "Set SIGNING_IDENTITY to a valid identity name, or set ALLOW_ADHOC_SIGNING=1 to force ad-hoc signing."
        echo "Tip: run 'security find-identity -v -p codesigning' to list identities."
        exit 1
    fi
fi

SIGNING_KEYCHAIN=""
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    SIGNING_KEYCHAIN=$(security find-identity -v -p codesigning | grep -F "\"$SIGNING_IDENTITY\"" | head -1 | grep -oE '/[^ "]+\.keychain-db' | head -1)
fi

CODESIGN_ARGS=(--force --deep --sign "$SIGNING_IDENTITY" --options runtime --timestamp=none)
if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    CODESIGN_ARGS+=(--keychain "$SIGNING_KEYCHAIN")
fi

codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"
echo "App bundle signed with identity: $SIGNING_IDENTITY"
