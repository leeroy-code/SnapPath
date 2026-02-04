# 架构说明

> 面向贡献者和维护者的代码结构与技术决策说明。

## 项目结构

```
SnapPath/
├── SnapPathApp.swift              # 入口，通过 NSApplicationDelegateAdaptor 桥接 AppDelegate
├── AppDelegate.swift              # 菜单栏 NSStatusItem 设置，窗口管理，应用生命周期
├── Models/
│   ├── CaptureMode.swift          # 枚举：region / fullScreen / window
│   ├── AppSettings.swift          # 单例，ObservableObject + UserDefaults 持久化
│   └── Annotation.swift           # 标注数据模型
├── Services/
│   ├── ScreenCaptureService.swift # 核心截图逻辑，管理覆盖层窗口生命周期
│   ├── HotkeyService.swift        # 全局快捷键注册（KeyboardShortcuts 库）
│   ├── FileService.swift          # PNG 编码与保存
│   ├── ClipboardService.swift     # NSPasteboard 路径/图片复制
│   ├── NotificationService.swift  # UNUserNotificationCenter 通知
│   ├── PinService.swift           # 截图钉住功能
│   └── AnnotationRenderer.swift   # 标注渲染
├── Views/
│   ├── SettingsView.swift         # SwiftUI 设置窗口
│   ├── ScreenshotOverlay.swift    # 区域选取 / 窗口选取覆盖层（NSWindow + NSView）
│   ├── EditorWindow.swift         # 截图编辑器窗口
│   ├── EditorCanvasView.swift     # 编辑器画布
│   ├── EditorToolbarView.swift    # 编辑器工具栏
│   ├── TextEditingView.swift      # 文字标注编辑
│   └── PinWindow.swift            # 钉住窗口
└── Utils/
    ├── PermissionChecker.swift    # 屏幕录制权限检查与引导
    ├── Constants.swift            # 应用名、文件名前缀、日期格式
    ├── DesignTokens.swift         # 统一设计系统（颜色、间距、字体等）
    └── ScreenCoordinateHelper.swift # NS/CG 坐标系转换工具
```

## 服务设计

无状态服务（`FileService`、`ClipboardService`、`NotificationService`、`HotkeyService`、`PermissionChecker`、`AnnotationRenderer`）实现为 `enum`，所有方法为 `static`，无需实例化。

有状态服务（`ScreenCaptureService`、`AppSettings`、`PinService`）使用单例模式，通过 `.shared` 访问。

## 截图流程

以区域截图为例：

```
用户按下 ⌘⇧S
  → HotkeyService 回调触发
  → ScreenCaptureService.captureRegion()
    → ensurePermission()              // 检查权限，无权限则弹窗引导
    → 创建 RegionSelectorWindow       // 全屏透明覆盖层
    → 用户拖拽选区，松开鼠标
    → 关闭覆盖层
    → 延迟 0.15s                      // 等覆盖层完全消失，否则会被截进去
    → CGWindowListCreateImage()       // 执行截图
    → finalize()
      → FileService.saveScreenshot()  // PNG 编码写入磁盘
      → ClipboardService.copyPath()   // 路径写入剪贴板
      → NotificationService.showSuccess() // 系统通知
```

全屏截图跳过覆盖层步骤，直接调用 `CGWindowListCreateImage`。窗口截图使用 `WindowSelectorWindow` 让用户选择目标窗口后，通过 `CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, ...)` 截取指定窗口。

### 截图后流程

根据 `AppSettings.showEditorAfterCapture` 设置：

- **开启编辑器**（默认）：截图完成后打开编辑器窗口，用户可添加标注、裁剪后选择"Copy Image"或"Copy Path"
- **直接保存**：跳过编辑器，直接保存 PNG 并复制路径到剪贴板

## Pin（钉住）功能

通过 ⌘⇧P 快捷键或编辑器中的 Pin 按钮，可将截图钉住在屏幕上：

```
用户按下 ⌘⇧P
  → HotkeyService 回调触发
  → ScreenCaptureService.captureAndPin()
    → 显示区域选取覆盖层
    → 用户选择区域
    → CGWindowListCreateImage() 截图
    → PinService.shared.pin(image:on:)
      → 创建 PinWindow（浮动窗口）
      → 显示在截图来源的屏幕上
```

PinWindow 特性：
- **浮动显示**: `level = .floating`，始终在其他窗口之上
- **跨空间显示**: 可在所有桌面空间中显示
- **滚轮缩放**: 支持 0.25x ~ 4x 缩放
- **拖拽移动**: 可通过窗口背景拖拽
- **透明度调节**: 右键菜单可设置 25%/50%/75%/100% 透明度
- **右键菜单**: Copy Image、Save & Copy Path、Opacity、Close
- **快捷关闭**: ESC 键或双击关闭

## 截图编辑器

截图完成后（若 `showEditorAfterCapture` 开启），显示编辑器窗口：

```
EditorWindow
├── EditorToolbarView          # 顶部工具栏
│   ├── 工具按钮: Arrow / Rectangle / Text / Crop
│   ├── 颜色选择器 (NSColorWell)
│   ├── 字体大小选择 (NSPopUpButton)
│   ├── Undo 按钮
│   ├── 缩放控制: 滑块 + 放大/缩小按钮 + 适应窗口
│   └── 操作按钮: Cancel / Copy Image / Copy Path / Pin
└── NSScrollView
    └── EditorCanvasView       # 画布（支持缩放 0.1x ~ 4x）
```

### 标注工具

| 工具 | 图标 | 功能 |
|------|------|------|
| Arrow | `arrow.up.right` | 绘制带箭头的线条 |
| Rectangle | `rectangle` | 绘制矩形边框 |
| Text | `textformat` | 添加文字标注（点击添加，再次点击编辑） |
| Crop | `crop` | 选择裁剪区域 |

### 标注数据模型

```swift
enum Annotation {
    case arrow(start: CGPoint, end: CGPoint, color: NSColor, lineWidth: CGFloat)
    case rectangle(rect: CGRect, color: NSColor, lineWidth: CGFloat)
    case text(origin: CGPoint, content: String, color: NSColor, fontSize: CGFloat)
}
```

### 撤销机制

- 使用 `undoStack: [[Annotation]]` 保存历史状态
- 最多保留 50 步历史记录
- 每次添加/修改标注前调用 `pushUndo()`

### 输出选项

- **Copy Image**: 渲染最终图片（含标注和裁剪）→ 复制到剪贴板 → 关闭编辑器
- **Copy Path**: 渲染最终图片 → 保存 PNG → 复制路径到剪贴板 → 关闭编辑器
- **Pin**: 渲染最终图片 → 调用 PinService 钉住 → 关闭编辑器

## 多显示器支持

区域选取和窗口选取均支持多显示器环境，通过 Coordinator 模式实现：

### RegionSelectorCoordinator

```
RegionSelectorCoordinator
├── windows: [RegionSelectorWindow]    # 每个屏幕一个窗口
├── startPoint: NSPoint?               # 全局 NS 坐标
├── currentPoint: NSPoint?             # 全局 NS 坐标
└── sourceScreen: NSScreen?            # 选区起始屏幕
```

- 为每个连接的显示器创建一个全屏透明覆盖层
- 鼠标事件使用全局 NS 坐标，确保跨屏幕选区正确绘制
- 选区可跨越多个屏幕，每个窗口只绘制其可见部分
- 最终截图使用选区起始屏幕的信息

### WindowSelectorCoordinator

```
WindowSelectorCoordinator
├── windows: [WindowSelectorWindow]    # 每个屏幕一个窗口
├── windowInfos: [WindowInfo]          # 一次性获取的窗口列表（共享）
└── hoveredWindow: WindowInfo?         # 当前悬停的窗口
```

- 窗口列表在启动时获取一次，所有屏幕共享
- 窗口高亮可跨屏幕显示（若窗口跨越多个屏幕）

## 坐标系转换

macOS 存在两套坐标系：

- **AppKit / NSView**：原点在左下角，Y 轴向上
- **Core Graphics / Quartz**：原点在主屏幕左上角，Y 轴向下

截图 API（`CGWindowListCreateImage`）使用 CG 坐标。覆盖层 UI（`NSView`）使用 AppKit 坐标。两者之间的转换公式：

```
cgY = primaryScreen.height - nsGlobalY - rectHeight
```

相关代码：

- `NSScreen.toCGRect()` — 屏幕坐标转换（`ScreenCaptureService.swift`）
- `ScreenCoordinateHelper` — 统一坐标转换工具（`Utils/ScreenCoordinateHelper.swift`）
- `RegionSelectorView.nsRectToCGRect()` — 选区坐标转换（`ScreenshotOverlay.swift`）
- `WindowSelectorView.cgRectToNSRect()` — 窗口高亮坐标转换（`ScreenshotOverlay.swift`）

## 关键技术决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 菜单栏实现 | AppKit `NSStatusItem` | `MenuBarExtra` 需要 macOS 13+，不满足 11.5+ 的部署目标 |
| 截图 API | `CGWindowListCreateImage` | MVP 阶段够用，`ScreenCaptureKit` 需要 macOS 12.3+ 且复杂度更高 |
| 全局快捷键 | `KeyboardShortcuts` 库 | 处理了系统级快捷键注册的各种边界情况 |
| 开机自启 | `LaunchAtLogin` 库 | 封装了 `SMLoginItemSetEnabled` 的复杂性 |
| 设置持久化 | `UserDefaults` + `ObservableObject` | 简单直接，不需要 `@AppStorage`（兼容 macOS 11.5） |
| App Sandbox | 关闭 | 屏幕录制需要系统级权限，Sandbox 内无法获取 |
| Dock 图标 | `LSUIElement = YES` | 纯菜单栏应用，不需要 Dock 图标和主窗口 |
| 多显示器选取 | Coordinator 模式 | 每个屏幕一个覆盖层窗口，共享选区状态，支持跨屏选取 |
| 标注渲染 | Core Graphics 直接绘制 | 性能好，支持导出高分辨率图片 |
| 编辑器画布 | NSScrollView + NSView | 支持缩放、滚动，精确控制绘制 |

## 覆盖层窗口设计

区域选取和窗口选取都使用 `NSWindow` + `NSView` 子类实现，而非 SwiftUI。原因：

- 需要精确控制鼠标事件（mouseDown / mouseDragged / mouseUp / mouseMoved）
- 需要自定义绘制（draw 方法中的遮罩和选区渲染）
- 需要 `level = .screenSaver` 确保覆盖所有窗口
- `acceptsFirstResponder` 用于接收键盘事件（ESC 取消）

关键细节：覆盖层窗口必须在调用截图 API **之前**完全关闭（`orderOut`），并延迟 0.15 秒再截图，否则覆盖层本身会出现在截图中。

## 依赖

| 库 | 版本 | 用途 |
|----|------|------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 1.x+ | 全局快捷键注册与 UI 录制组件 |
| [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) | 非 Modern 版本 | 开机自启动（兼容 macOS 11.5+） |

均通过 Xcode SPM 集成，无 CocoaPods 或 Carthage。

---

[← 使用指南](usage-guide.md) · [实现计划 →](implementation-plan.md)
