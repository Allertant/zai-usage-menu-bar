# App Icon Design

## Overview

Add a native macOS app icon to ZaiUsageMenuBar so it displays properly in Finder, Launchpad, Activity Monitor, and the Dock.

## Icon Design

- **Symbol**: SF Symbol `gauge.open.with.lines.needle.33percent` rendered in white
- **Background**: Blue gradient (dark blue to lighter blue, top-left to bottom-right)
- **Shape**: Standard macOS rounded rectangle with corner radius proportional to icon size

## Implementation

### 1. Icon Generation Script (`scripts/generate_icon.swift`)

A Swift script using CoreGraphics and AppKit that:
- Renders the SF Symbol in white at the correct size
- Draws a blue gradient rounded-rect background
- Composites the symbol on top of the background
- Exports PNGs at all required macOS icon sizes

Required sizes (with @2x variants):
| Size | @1x | @2x |
|------|-----|-----|
| 16   | 16  | 32  |
| 32   | 32  | 64  |
| 128  | 128 | 256 |
| 256  | 256 | 512 |
| 512  | 512 | 1024 |

### 2. Asset Catalog Structure

```
ZaiUsageMenuBar/Sources/ZaiUsageMenuBar/Assets.xcassets/
  Contents.json
  AppIcon.appiconset/
    Contents.json
    icon_16x16.png
    icon_16x16@2x.png
    icon_32x32.png
    icon_32x32@2x.png
    icon_128x128.png
    icon_128x128@2x.png
    icon_256x256.png
    icon_256x256@2x.png
    icon_512x512.png
    icon_512x512@2x.png
```

### 3. Package.swift Update

Add the `Assets.xcassets` as a resource in the executable target so SwiftPM includes it in the built app bundle.

## Dependencies

- macOS with SF Symbols available (AppKit)
- Swift runtime for the generation script
