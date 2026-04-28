# Zai Usage Menu Bar

A native macOS menu bar app for monitoring your [ZhiPu (智谱)](https://open.bigmodel.cn) Coding Plan API usage in real time.

## Quick Start

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode, then press Cmd+R to run
open ZaiUsageMenuBar.xcodeproj
```

For release builds, see [Build Guide](docs/build-guide.md).

## Features

- **Multi-Account Support** — Configure multiple named API accounts
- **Quota Monitoring** — Remaining token/MCP quotas with color-coded warnings
- **Adaptive Refresh** — 30s active, 1min idle, 5min long idle
- **Menu Bar Icon** — Shows remaining quota (e.g. `G55%`)
- **Claude Code Integration** — Display quota in Claude Code status line
- **Bilingual** — English and Simplified Chinese

## Documentation

- [Build Guide](docs/build-guide.md) — Build signed app bundle for release
- [Claude Code Integration](docs/claude-code-integration.md) — Show quota in Claude Code footer

## License

MIT

## 友情链接

- [Linux Do 社区](https://linux.do/)
