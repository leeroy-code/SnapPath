# SnapPath

中文版 | [English](README.md)

> 为 AI 编程而生。截图、保存、路径自动复制到剪贴板，一气呵成。

## 为什么选择 SnapPath？

AI CLI 工具（如 Claude Code、Cursor、Aider）运行在终端中，无法直接粘贴图片。当你需要把报错截图或 UI 问题发给 AI 时，你真正需要的是**文件路径**，而非图片本身。

**SnapPath 工作流：**

```text
按下快捷键 → 截图自动保存到本地 → 文件路径自动复制到剪贴板 → 终端里 Cmd+V 粘贴路径
```

## 核心功能

- **四种截图模式**：区域选取、全屏、窗口、Pin（固定截图）。
- **路径自动复制**：截图完成后，文件的绝对路径立即进入剪贴板。
- **内置编辑器**：支持箭头、矩形、文字标注及裁剪工具。
- **钉住到屏幕 (Pin)**：将截图窗口置顶悬浮，适合对比参考。
- **菜单栏常驻**：无 Dock 图标，不干扰工作流。
- **多显示器支持**：支持跨多个显示器进行操作。

## 快速开始

### 1. 从源码构建

```bash
git clone <repo-url>
cd SnapPath
xcodebuild -project SnapPath.xcodeproj -scheme SnapPath -configuration Debug build
```

或者在 Xcode 中打开 `SnapPath.xcodeproj` 并按下 `⌘R` 运行。

### 2. 授权

SnapPath 需要 **屏幕录制** 权限。请前往：
`系统设置 → 隐私与安全性 → 屏幕录制` 并开启 SnapPath。

### 3. 开始截图

- 按下 `⌘⇧S` 选取区域。
- 截图完成后会弹出编辑器（可在设置中关闭）。
- 点击 **Copy Path** 保存文件并将路径复制到剪贴板。
- 默认保存目录：`~/Downloads/screenshot_YYYY-MM-DD_HH-mm-ss.png`

## 默认快捷键

| 操作     | 快捷键 |
| -------- | ------ |
| 区域截图 | `⌘⇧S`  |
| 全屏截图 | `⌘⇧A`  |
| 窗口截图 | `⌘⇧W`  |
| Pin 截图 | `⌘⇧P`  |

_可在设置中自定义（菜单栏图标 → Settings...）_

## 系统要求

- macOS 11.5+
- 需要授予屏幕录制权限

---

## 详细文档

- [快速开始](doc/getting-started.md)
- [使用指南](doc/usage-guide.md)
- [架构说明](doc/architecture.md)

## 开源协议

[MIT](LICENSE)
