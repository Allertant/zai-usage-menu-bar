# Build Guide

## Xcode (Development)

1. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

2. Open `ZaiUsageMenuBar.xcodeproj` in Xcode

3. In Xcode → Signing & Capabilities, set a code signing identity for Debug builds. You can create a self-signed certificate via **Keychain Access → Certificate Assistant → Create Certificate** (type: Code Signing)

4. Press Cmd+R to build and run

## Build Signed App Bundle (Release)

```bash
./build-app.sh
open build/ZaiUsageMenuBar.app
```

The script automatically finds a signing certificate from your keychain. To specify one:

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./build-app.sh
```

## App Configuration

1. Click the **gear icon** in the popover header
2. Add one or more accounts with a custom name and auth token
3. Enable/disable accounts as needed
4. Choose your preferred language (English, Chinese, or System Default)

The app connects to `https://open.bigmodel.cn/api/monitor/usage/*` endpoints.
