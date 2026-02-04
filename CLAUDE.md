# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SnapPath is a **macOS menu bar application** (SwiftUI) that captures screenshots and automatically copies the file path to the clipboard. It targets developers using AI CLI tools (Claude Code, Cursor, Aider) who need to share screenshots via file paths in terminal environments.

The PRD is in `SnapPath_MVP_PRD.md` (Chinese language). All requirements and implementation details are specified there.

## Build & Run

This is an Xcode project (no SPM package, no CocoaPods). Build and run via:

```bash
xcodebuild -project SnapPath.xcodeproj -scheme SnapPath -configuration Debug build
```

No test targets exist yet.

## Architecture

The app uses a service-oriented architecture with SwiftUI. Per the PRD:

```
SnapPath/
├── SnapPathApp.swift              # Entry point using MenuBarExtra (no Dock icon, no main window)
├── Views/
│   ├── MenuBarView.swift          # Dropdown menu (region/fullscreen/window capture, settings, quit)
│   ├── SettingsView.swift         # Save location, launch-at-login, sound, notifications
│   └── ScreenshotOverlay.swift   # Region selection overlay (NSWindow-based)
├── Services/
│   ├── ScreenCaptureService.swift # Core capture logic (ScreenCaptureKit on 12.3+, CGWindowListCreateImage fallback)
│   ├── HotkeyService.swift        # Global shortcuts (⌘⇧S region, ⌘⇧A fullscreen, ⌘⇧W window)
│   ├── ClipboardService.swift     # Copy file path to NSPasteboard
│   ├── FileService.swift          # Save PNG to ~/Downloads as screenshot_YYYY-MM-DD_HH-mm-ss.png
│   └── NotificationService.swift  # Success notification via UserNotifications
├── Models/
│   ├── AppSettings.swift          # @AppStorage-backed settings (ObservableObject)
│   └── CaptureMode.swift          # Enum: region, fullScreen, window
└── Utils/
    ├── PermissionChecker.swift    # CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess
    └── Constants.swift
```

## Key Technical Decisions

- **App Sandbox is disabled** (`ENABLE_APP_SANDBOX = NO`) — required for screen capture permissions
- **Hardened Runtime is enabled**
- **Deployment target**: macOS 11.5
- **Screenshot API**: Conditional — ScreenCaptureKit (macOS 12.3+) with CGWindowListCreateImage fallback
- **Global hotkeys**: Use `KeyboardShortcuts` SPM package (sindresorhus/KeyboardShortcuts)
- **Launch at login**: Use `LaunchAtLogin` SPM package (sindresorhus/LaunchAtLogin)
- **Settings persistence**: `@AppStorage` / UserDefaults
- **Region selector**: Full-screen transparent NSWindow overlay with mouse tracking

## Important Notes

- `Info.plist` must include `NSScreenCaptureUsageDescription`
- No Dock icon — app is menu bar only (MenuBarExtra)
- File paths must be absolute for terminal compatibility
- The capture flow: trigger → capture → save PNG to ~/Downloads → copy path to clipboard → show notification
