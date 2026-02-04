# SnapPath

<!-- CI Test 1 -->

[中文版](README_CN.md) | English

> A macOS screenshot tool designed for AI-assisted programming. Capture, save, and have the path automatically copied to your clipboard—all in one flow.

## Why SnapPath?

AI CLI tools (like Claude Code, Cursor, Aider) run in the terminal and often cannot accept image pastes directly. When you need to send a screenshot of an error or a UI issue to an AI, what you really need is the **file path**, not just the image itself.

**SnapPath Workflow:**

```text
Press Shortcut → Capture is saved locally → File Path is copied to clipboard → Cmd+V the path in your Terminal
```

## Key Features

- **4 Capture Modes**: Region, Full Screen, Window, and Pin.
- **Auto-copy Path**: The absolute file path is immediately copied to your clipboard after capture.
- **Built-in Editor**: Annotate with arrows, rectangles, text, and cropping tools.
- **Pin to Screen**: Float snippets on top of all windows for easy reference.
- **Menu Bar Only**: No Dock icon to clutter your workspace.
- **Multi-monitor Support**: Works across all connected displays.

## Quick Start

### 1. Build from Source

```bash
git clone <repo-url>
cd SnapPath
xcodebuild -project SnapPath.xcodeproj -scheme SnapPath -configuration Debug build
```

Or open `SnapPath.xcodeproj` in Xcode and press `⌘R`.

### 2. Permissions

SnapPath requires **Screen Recording** permission to function. Go to:
`System Settings → Privacy & Security → Screen Recording` and enable SnapPath.

### 3. First Capture

- Press `⌘⇧S` to select a region.
- Once captured, the editor pops up (optional).
- Click **Copy Path** to save the file and get the path in your clipboard.
- Default save location: `~/Downloads/screenshot_YYYY-MM-DD_HH-mm-ss.png`

## Keyboard Shortcuts (Default)

| Action              | Shortcut |
| ------------------- | -------- |
| Region Capture      | `⌘⇧S`    |
| Full Screen Capture | `⌘⇧A`    |
| Window Capture      | `⌘⇧W`    |
| Pin Region          | `⌘⇧P`    |

_Customizable in Settings (Menu Bar → Settings...)_

## System Requirements

- macOS 11.5+
- Screen Recording Permission

---

## Documentation

- [Getting Started](doc/getting-started.md)
- [Usage Guide](doc/usage-guide.md)
- [Architecture](doc/architecture.md)

## License

[MIT](LICENSE)
