# SnapPath 实现计划

基于 `SnapPath_MVP_PRD.md`，使用 AppKit NSStatusItem 架构（支持 macOS 11.5+）。

---

## Phase 0: 项目配置

### 0.1 修复部署目标
- **文件**: `SnapPath.xcodeproj/project.pbxproj`
- 将项目级 `MACOSX_DEPLOYMENT_TARGET` 从 `15.7` 改为 `11.5`（Debug + Release）
- Target 级保持 `11.5` 不变

### 0.2 添加 Info.plist 配置
- **文件**: `SnapPath.xcodeproj/project.pbxproj`
- 添加 `INFOPLIST_KEY_NSScreenCaptureUsageDescription = "SnapPath 需要屏幕录制权限来截取屏幕。";`
- 添加 `INFOPLIST_KEY_LSUIElement = YES;`（隐藏 Dock 图标）

### 0.3 添加 SPM 依赖
- **文件**: `SnapPath.xcodeproj/project.pbxproj`
- `KeyboardShortcuts` — `https://github.com/sindresorhus/KeyboardShortcuts`
- `LaunchAtLogin` — `https://github.com/sindresorhus/LaunchAtLogin`（非 Modern 版本，支持 macOS 11.5+）

**验证**: `xcodebuild build` 成功。

---

## Phase 1: 菜单栏骨架（AppKit NSStatusItem）

由于 macOS 11.5 没有 MenuBarExtra，使用 AppKit 实现菜单栏。

### 1.1 创建 Models
- **创建** `SnapPath/Models/CaptureMode.swift` — 枚举: region, fullScreen, window
- **创建** `SnapPath/Models/AppSettings.swift` — ObservableObject + @AppStorage（saveDirectory, playSoundEffect, showNotification）

### 1.2 创建 Utils
- **创建** `SnapPath/Utils/Constants.swift` — 应用名、截图文件前缀、日期格式等常量

### 1.3 创建 AppDelegate（核心变更）
- **创建** `SnapPath/AppDelegate.swift`
- 使用 `NSStatusItem` + `NSMenu` 构建菜单栏
- 菜单项：区域截图(⌘⇧S)、全屏截图(⌘⇧A)、窗口截图(⌘⇧W)、分隔线、打开下载文件夹、分隔线、设置...、分隔线、退出
- SF Symbol `camera.viewfinder` 作为菜单栏图标（`NSImage(systemSymbolName:accessibilityDescription:)` macOS 11.5+）

### 1.4 修改 SnapPathApp.swift
- **修改** `SnapPath/SnapPathApp.swift`
- 使用 `@NSApplicationDelegateAdaptor(AppDelegate.self)` 引入 AppDelegate
- 移除 WindowGroup，改为空 Scene 或 Settings scene

### 1.5 删除 ContentView.swift
- **删除** `SnapPath/ContentView.swift`

### 1.6 创建 SettingsView 占位
- **创建** `SnapPath/Views/SettingsView.swift` — SwiftUI 视图，占位内容

**验证**: 构建运行后，菜单栏出现相机图标，点击展示下拉菜单，无 Dock 图标，无主窗口。"打开下载文件夹"和"退出"可用。

---

## Phase 2: 工具服务层

### 2.1 权限检查
- **创建** `SnapPath/Utils/PermissionChecker.swift`
- `checkScreenCapturePermission()` → `CGPreflightScreenCaptureAccess()`
- `requestScreenCapturePermission()` → `CGRequestScreenCaptureAccess()`
- `openSystemPreferences()` → 打开系统设置屏幕录制面板

### 2.2 剪贴板服务
- **创建** `SnapPath/Services/ClipboardService.swift`
- `copyPath(_ path: String)` → `NSPasteboard.general`

### 2.3 文件服务
- **创建** `SnapPath/Services/FileService.swift`
- `generateFilename()` → `screenshot_YYYY-MM-DD_HH-mm-ss.png`
- `saveScreenshot(_ image: CGImage) throws -> URL` → PNG 编码写入指定目录
- 读取 AppSettings 中的 saveDirectory

### 2.4 通知服务
- **创建** `SnapPath/Services/NotificationService.swift`
- `UNUserNotificationCenter` 请求授权并发送本地通知
- `showSuccess(path:)` — 标题"截图已保存"，内容显示路径
- 尊重 AppSettings.showNotification 和 playSoundEffect 设置

**验证**: 可在菜单项临时触发各服务进行测试。

---

## Phase 3: 截图核心实现

### 3.1 全屏截图（最简单，先实现）
- **创建** `SnapPath/Services/ScreenCaptureService.swift`
- `captureFullScreen()`:
  1. 检查权限
  2. 获取鼠标所在屏幕（`NSEvent.mouseLocation` + `NSScreen.screens`）
  3. `CGWindowListCreateImage(screenRect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])`
  4. 调用 FileService 保存 → ClipboardService 复制路径 → NotificationService 通知
- MVP 全部使用 `CGWindowListCreateImage`，不引入 ScreenCaptureKit 复杂度

### 3.2 连接全屏截图到菜单
- **修改** `SnapPath/AppDelegate.swift` — 菜单项触发 `ScreenCaptureService`

**验证**: 点击"全屏截图"，截图保存到 ~/Downloads，路径已复制到剪贴板，收到通知。

### 3.3 区域截图覆盖层
- **创建** `SnapPath/Views/ScreenshotOverlay.swift`
- `RegionSelectorWindow`（NSWindow 子类）：
  - borderless, 透明, level = .screenSaver
  - 覆盖整个屏幕，十字光标
- `RegionSelectorView`（NSView 子类）：
  - mouseDown 记录起点, mouseDragged 更新选区, mouseUp 完成选择
  - ESC (keyCode 53) 取消
  - draw: 半透明黑色遮罩 + 选区透明镂空 + 白色边框
  - acceptsFirstResponder = true
- **坐标转换**: NSView 坐标 → CG 屏幕坐标（Y 轴翻转）
- **关键**: 覆盖层窗口必须在截图前完全关闭，否则会出现在截图中

### 3.4 区域截图服务
- **修改** `SnapPath/Services/ScreenCaptureService.swift`
- `captureRegion()`: 显示覆盖层 → 用户选择区域 → 关闭覆盖层 → 延迟截图 → 保存流程

### 3.5 窗口截图
- **修改** `SnapPath/Views/ScreenshotOverlay.swift` — 添加 `WindowSelectorWindow`/`WindowSelectorView`
- **修改** `SnapPath/Services/ScreenCaptureService.swift`
- `captureWindow()`:
  1. `CGWindowListCopyWindowInfo` 获取窗口列表
  2. 过滤 layer==0 的普通窗口，排除自身
  3. 显示透明覆盖层，鼠标悬停时高亮对应窗口边界
  4. 点击 → `CGWindowListCreateImage` 截取该窗口
  5. ESC 取消
- 坐标转换: CGWindowList 返回 CG 坐标（左上角原点），需转换为 NSView 坐标绘制高亮

### 3.6 连接所有截图模式到菜单
- **修改** `SnapPath/AppDelegate.swift`

**验证**: 三种截图模式全部可用，保存正确，路径复制正确，通知显示正确。

---

## Phase 4: 全局快捷键

### 4.1 快捷键服务
- **创建** `SnapPath/Services/HotkeyService.swift`
- 定义 `KeyboardShortcuts.Name` 扩展: captureRegion, captureFullScreen, captureWindow
- `setupHotkeys()`:
  - 首次启动设置默认快捷键（⌘⇧S, ⌘⇧A, ⌘⇧W）
  - 注册 `onKeyUp` 处理器调用 ScreenCaptureService

### 4.2 初始化快捷键
- **修改** `SnapPath/AppDelegate.swift` — 在 `applicationDidFinishLaunching` 中初始化 HotkeyService

**验证**: 在任意应用中按 ⌘⇧S/A/W，对应截图模式被触发。

---

## Phase 5: 设置窗口（P1）

### 5.1 完整 SettingsView
- **修改** `SnapPath/Views/SettingsView.swift`
- Form 布局:
  - 保存位置：显示当前路径 + "选择..."按钮（NSOpenPanel）
  - 开机自启动：LaunchAtLogin.Toggle
  - 截图音效：Toggle
  - 显示通知：Toggle
- 通过 NSWindow 呈现（AppDelegate 管理窗口打开）

**验证**: 设置可修改并持久化，重启后保持。截图行为受设置控制。

---

## Phase 6: 权限流程与收尾

### 6.1 首次启动权限引导
- **修改** `SnapPath/AppDelegate.swift`
- 启动时检查屏幕录制权限，未授权则弹出 NSAlert 引导到系统设置

### 6.2 截图前权限检查
- **修改** `SnapPath/Services/ScreenCaptureService.swift`
- 每次截图前检查权限，未授权时引导而非崩溃

### 6.3 音效集成
- 截图成功后根据设置播放系统音效

### 6.4 边界情况处理
- 保存目录不存在时回退到 ~/Downloads
- 多显示器坐标系正确处理
- 截图过程中退出应用时清理覆盖层窗口

**验证**: 撤销屏幕录制权限后启动应用，应有引导提示。所有截图模式在权限缺失时优雅处理。

---

## Phase 7: 截图编辑器

### 7.1 编辑器设置项
- **修改** `SnapPath/Models/AppSettings.swift`
- 添加 `showEditorAfterCapture: Bool`（默认 true）

### 7.2 标注数据模型
- **创建** `SnapPath/Models/Annotation.swift`
- `EditorTool` 枚举：arrow, rectangle, text, crop
- `Annotation` 枚举：arrow / rectangle / text，包含颜色、线宽、字体大小等属性
- `CropRect` 结构体：裁剪区域

### 7.3 标注渲染服务
- **创建** `SnapPath/Services/AnnotationRenderer.swift`
- `render(annotations:cropRect:onto:)` → 将标注渲染到原始图片上
- 支持箭头（带箭头的线条）、矩形边框、文字
- 支持裁剪：渲染完成后根据 cropRect 裁剪

### 7.4 编辑器画布
- **创建** `SnapPath/Views/EditorCanvasView.swift`
- 显示原始图片 + 标注叠加层
- 鼠标事件处理：mouseDown / mouseDragged / mouseUp
- 绘制实时预览（拖拽时显示临时标注）
- 撤销栈：`undoStack: [[Annotation]]`，最多 50 步

### 7.5 文字编辑视图
- **创建** `SnapPath/Views/TextEditingView.swift`
- NSTextView 包装，支持多行文字输入
- 自动调整大小
- ESC 取消，Cmd+Enter 确认
- 点击已有文字标注可重新编辑

### 7.6 编辑器工具栏
- **创建** `SnapPath/Views/EditorToolbarView.swift`
- 工具按钮：Arrow / Rectangle / Text / Crop
- NSColorWell 颜色选择器
- NSPopUpButton 字体大小选择（12pt ~ 72pt）
- Undo 按钮
- 缩放控制：滑块（0.1x ~ 4x）、放大/缩小按钮、适应窗口按钮、百分比标签
- 操作按钮：Cancel / Copy Image / Copy Path / Pin

### 7.7 编辑器窗口
- **创建** `SnapPath/Views/EditorWindow.swift`
- NSWindow 子类，包含工具栏和画布
- 窗口大小根据图片尺寸自适应（最大 85% 屏幕，最小 400x300）
- 在截图来源屏幕居中显示
- 回调：onCopyImage / onCopyPath / onCancel

### 7.8 集成到截图流程
- **修改** `SnapPath/Services/ScreenCaptureService.swift`
- `finalize()` 根据 `showEditorAfterCapture` 决定是否显示编辑器
- 编辑器输出：Copy Image → 复制图片到剪贴板；Copy Path → 保存并复制路径

**验证**: 截图后显示编辑器，可添加箭头/矩形/文字标注，可裁剪，Undo 可用，Copy Image/Copy Path 正确输出。

---

## Phase 8: Pin（钉住）功能

### 8.1 Pin 服务
- **创建** `SnapPath/Services/PinService.swift`
- 单例模式，管理所有钉住的窗口
- `pin(image:on:)` → 创建 PinWindow 并显示
- `closeAll()` → 关闭所有钉住窗口
- `remove(_:)` → 从列表中移除指定窗口

### 8.2 Pin 窗口
- **创建** `SnapPath/Views/PinWindow.swift`
- NSWindow 子类，`level = .floating`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- 透明标题栏，可通过背景拖拽移动
- 滚轮缩放（0.25x ~ 4x），保持中心位置
- ESC 或双击关闭
- 右键菜单：Copy Image / Save & Copy Path / Opacity（25%/50%/75%/100%）/ Close
- 在截图来源屏幕居中显示，自动缩小以适应屏幕

### 8.3 Pin 快捷键
- **修改** `SnapPath/Services/HotkeyService.swift`
- 添加 `pinRegion` 快捷键（默认 ⌘⇧P）

### 8.4 Pin 菜单项
- **修改** `SnapPath/AppDelegate.swift`
- 菜单中添加 "Pin Region" 项

### 8.5 从编辑器 Pin
- **修改** `SnapPath/Views/EditorToolbarView.swift`
- 添加 Pin 按钮，点击后渲染最终图片并调用 PinService

**验证**: ⌘⇧P 截取区域后钉住，可拖拽、缩放、调节透明度，右键菜单功能正常，ESC/双击可关闭。

---

## Phase 9: 多显示器支持

### 9.1 区域选取 Coordinator
- **修改** `SnapPath/Views/ScreenshotOverlay.swift`
- 创建 `RegionSelectorCoordinator` 类
- 为每个屏幕创建 RegionSelectorWindow
- 使用全局 NS 坐标追踪选区，支持跨屏选取
- 选区在所有屏幕上同步显示（各窗口只绘制可见部分）

### 9.2 窗口选取 Coordinator
- **修改** `SnapPath/Views/ScreenshotOverlay.swift`
- 创建 `WindowSelectorCoordinator` 类
- 窗口列表在启动时获取一次，所有屏幕共享
- 窗口高亮可跨屏幕显示

### 9.3 坐标转换工具
- **创建** `SnapPath/Utils/ScreenCoordinateHelper.swift`
- `nsPointToCG(_:)` / `cgPointToNS(_:)` — 点坐标转换
- `nsRectToCG(_:)` / `cgRectToNS(_:)` — 矩形坐标转换
- 处理多屏幕布局下的坐标偏移

### 9.4 编辑器/Pin 窗口屏幕感知
- 编辑器窗口在截图来源屏幕居中显示
- Pin 窗口在截图来源屏幕居中显示
- `sourceScreen` 参数贯穿整个截图流程

**验证**: 多显示器环境下，区域选取可跨屏幕，窗口选取正确高亮跨屏窗口，编辑器和 Pin 窗口在正确屏幕显示。

---

## Phase 10: 剪贴板增强

### 10.1 复制图片功能
- **修改** `SnapPath/Services/ClipboardService.swift`
- 添加 `copyImage(_ image: CGImage)` 方法
- 将 CGImage 转换为 NSImage 并写入 NSPasteboard

**验证**: 编辑器 Copy Image 按钮和 Pin 窗口 Copy Image 菜单项可将图片复制到剪贴板。

---

## Phase 11: 统一设计系统

### 11.1 设计令牌
- **创建** `SnapPath/Utils/DesignTokens.swift`
- `Colors`: overlayDim, selectionBorder, hoverFill, hoverBorder, cropOverlay, editingBorder, toolbarBackground, annotationDefault
- `Spacing`: xxs/xs/s/m/l/xl/xxl（基于 4pt 栅格）
- `Border`: widthThin/Medium/Thick, radiusSmall/Medium/Large
- `Sizes`: toolbarHeight, buttonMinWidth, iconButtonSize, colorWellSize 等
- `Typography`: caption, captionMono, body, bodyMedium, annotation
- `Animation`: durationFast/Normal/Slow
- `Shadow`: standard, floating

### 11.2 SwiftUI 桥接
- `DesignTokens.Colors` 和 `DesignTokens.Spacing` 提供 SwiftUI 兼容属性

**验证**: 所有 UI 组件使用统一的设计令牌，视觉风格一致。

---

## 文件清单

| 文件 | 操作 | Phase |
|------|------|-------|
| `SnapPath.xcodeproj/project.pbxproj` | 修改 | 0 |
| `SnapPath/Models/CaptureMode.swift` | 创建 | 1 |
| `SnapPath/Models/AppSettings.swift` | 创建 | 1 |
| `SnapPath/Utils/Constants.swift` | 创建 | 1 |
| `SnapPath/AppDelegate.swift` | 创建 | 1, 3, 4, 6 |
| `SnapPath/SnapPathApp.swift` | 修改 | 1 |
| `SnapPath/ContentView.swift` | 删除 | 1 |
| `SnapPath/Views/SettingsView.swift` | 创建 | 1, 5 |
| `SnapPath/Utils/PermissionChecker.swift` | 创建 | 2 |
| `SnapPath/Services/ClipboardService.swift` | 创建 | 2 |
| `SnapPath/Services/FileService.swift` | 创建 | 2 |
| `SnapPath/Services/NotificationService.swift` | 创建 | 2 |
| `SnapPath/Services/ScreenCaptureService.swift` | 创建 | 3 |
| `SnapPath/Views/ScreenshotOverlay.swift` | 创建 | 3 |
| `SnapPath/Services/HotkeyService.swift` | 创建 | 4 |

## 关键技术决策

1. **AppKit NSStatusItem + NSMenu** 代替 SwiftUI MenuBarExtra（支持 macOS 11.5+）
2. **CGWindowListCreateImage** 用于所有截图模式（MVP 不引入 ScreenCaptureKit）
3. **ObservableObject + @AppStorage** 用于设置（非 @Observable，兼容 macOS 11.5）
4. **LaunchAtLogin**（非 Modern 版本）支持 macOS 11.5+
5. **覆盖层必须在截图前完全关闭**，避免出现在截图中
6. **坐标系转换**: NSView (左下原点) ↔ CG/Quartz (左上原点)，`cgY = screenHeight - nsY - height`
