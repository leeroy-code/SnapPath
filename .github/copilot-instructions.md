# Copilot Instructions for SnapPath

## Project Overview

SnapPath is a macOS menu bar screenshot application built with SwiftUI.

**Full documentation**: See [`CLAUDE.md`](../CLAUDE.md)

## Development Guidelines

### Project Structure

```
SnapPath/
├── SnapPathApp.swift          # App entry (MenuBarExtra)
├── Views/                      # SwiftUI views
├── Services/                   # Business logic
├── Models/                     # Data models
└── Utils/                      # Utilities
```

### Key Constraints

- **macOS 11.5+** deployment target
- **No App Sandbox** — must remain disabled for screen capture
- **Hardened Runtime** enabled
- **Menu bar only** — uses `MenuBarExtra`, no Dock icon

### Dependencies

- `KeyboardShortcuts` — global hotkeys
- `LaunchAtLogin` — login item management
- `Sparkle` — auto-updates

### When Generating Code

1. Check `CLAUDE.md` for architecture details
2. Check `doc/architecture.md` for component documentation
3. Check `SnapPath_MVP_PRD.md` for requirements (Chinese)
4. Follow existing code patterns in the same folder

### Build

```bash
xcodebuild -project SnapPath.xcodeproj -scheme SnapPath -configuration Debug build
```
