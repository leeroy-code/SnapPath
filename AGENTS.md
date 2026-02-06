# AGENTS.md

This file provides guidance for AI coding agents working with this repository.

> **Primary Reference**: See [`CLAUDE.md`](./CLAUDE.md) for detailed project information.

## Quick Reference

- **Project**: SnapPath - macOS menu bar screenshot utility
- **Language**: Swift (SwiftUI)
- **Build**: Xcode project (`xcodebuild -project SnapPath.xcodeproj -scheme SnapPath`)
- **Platform**: macOS 11.5+
- **Architecture**: Service-oriented with SwiftUI

## Critical Constraints

1. **Sandbox disabled** — required for screen capture (do not enable)
2. **Menu bar only** — no Dock icon, no main window
3. **Absolute paths** — must use absolute paths for terminal compatibility

## When Making Changes

1. Read [`CLAUDE.md`](./CLAUDE.md) first
2. Check `doc/architecture.md` for detailed architecture
3. Check `SnapPath_MVP_PRD.md` (Chinese) for requirements

## Common Tasks

- **New feature**: Add to appropriate Services/Views folder
- **New shortcut**: Update `HotkeyService.swift` and register in `KeyboardShortcuts`
- **Settings**: Add to `AppSettings.swift` with `@AppStorage`
