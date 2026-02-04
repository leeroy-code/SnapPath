# 快速开始

> 从源码构建 SnapPath 并完成第一次截图。

## 1. 构建

```bash
git clone <repo-url>
cd SnapPath
xcodebuild -project SnapPath.xcodeproj -scheme SnapPath -configuration Debug build
```

或在 Xcode 中打开 `SnapPath.xcodeproj`，直接 `⌘R` 运行。

## 2. 授予屏幕录制权限

首次启动时，SnapPath 会弹窗提示需要屏幕录制权限。点击引导按钮后：

1. 系统设置 → 隐私与安全性 → 屏幕录制
2. 找到 SnapPath，开启开关
3. 如果提示需要重启应用，退出后重新启动即可

> 没有这个权限，截图功能无法工作。这是 macOS 的系统级限制。

## 3. 第一次截图

启动后，菜单栏出现 SnapPath 图标。按下 `⌘⇧S`（Command + Shift + S）：

1. 屏幕出现半透明遮罩和十字准星
2. 拖拽选择截图区域，松开鼠标完成截图
3. 按 `ESC` 可随时取消

截图完成后：
- 如果开启了"截图后显示编辑器"（默认开启），会弹出编辑窗口，可以添加箭头、矩形、文字标注或裁剪
- 点击 "Copy Path" 保存文件并复制路径，或点击 "Copy Image" 直接复制图片到剪贴板
- 文件保存到 `~/Downloads/screenshot_YYYY-MM-DD_HH-mm-ss.png`
- 文件路径已自动复制到剪贴板
- 系统通知确认截图成功

现在打开终端，`Cmd+V` 粘贴，你会看到类似：

```
/Users/yourname/Downloads/screenshot_2025-01-15_14-30-25.png
```

这个路径可以直接粘贴给 Claude Code、Cursor 等 AI CLI 工具。

## 常见问题

### 截图是黑屏 / 截图失败

屏幕录制权限未正确授予。前往 系统设置 → 隐私与安全性 → 屏幕录制，确认 SnapPath 已开启。修改权限后需要重启应用。

### 菜单栏看不到图标

SnapPath 是纯菜单栏应用，不会出现在 Dock 栏。检查菜单栏右侧是否有相机图标。如果菜单栏空间不足，图标可能被系统隐藏。

### 快捷键没有反应

可能与其他应用的快捷键冲突。打开 SnapPath 设置（菜单栏图标 → Settings...），在 Keyboard Shortcuts 区域重新录制快捷键。

## 4. 试试 Pin 功能

按下 `⌘⇧P`，选择一个区域，截图会作为浮动窗口固定在屏幕上。

- 滚轮缩放
- 拖拽移动
- 双击或 ESC 关闭

---

[← 返回首页](README.md) · [使用指南 →](usage-guide.md)
