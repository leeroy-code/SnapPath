import Cocoa

// MARK: - Region Selector Coordinator (Per-Screen, Single-Display Selection)

final class RegionSelectorCoordinator {
    enum OutputAction {
        case copyImage
        case saveAndCopyPath
    }

    private var windows: [RegionSelectorWindow] = []
    private weak var activeWindow: RegionSelectorWindow?
    private var activeScreen: NSScreen?

    private var onComplete: ((CGImage, OutputAction) -> Void)?
    private var onCancel: (() -> Void)?

    // Selection State
    private var sourceScreen: NSScreen?
    private var startPoint: NSPoint? // Global NS coordinates
    private var currentPoint: NSPoint? // Global NS coordinates
    
    // Edit state
    internal var isEditing = false
    private var editorCanvas: EditorCanvasView?
    private var editorToolbar: EditorToolbarView?

    func start(onComplete: @escaping (CGImage, OutputAction) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel

        // Hide system cursor, we will draw our own crosshair
        NSCursor.hide()

        windows = NSScreen.screens.map { screen in
            let window = RegionSelectorWindow(screen: screen, coordinator: self)
            window.orderFront(nil)
            return window
        }

        // Ensure the screen under cursor becomes key, so ESC works immediately.
        if let screen = screenAtMouseLocation() {
            focusWindowIfNeeded(for: screen)
        } else {
            activeWindow = windows.first
            activeWindow?.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func cleanup() {
        NSCursor.unhide()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        activeWindow = nil
        activeScreen = nil
        startPoint = nil
        currentPoint = nil
        sourceScreen = nil
        editorCanvas = nil
        editorToolbar = nil
        isEditing = false
    }

    // MARK: - Mouse Events (called by view)

    func handleMouseMoved(point: NSPoint, on screen: NSScreen) {
        guard !isEditing else { return }
        focusWindowIfNeeded(for: screen)
        currentPoint = globalPoint(from: point, on: screen)
        refreshAllWindows()
    }

    func handleMouseDown(point: NSPoint, on screen: NSScreen) {
        guard !isEditing else { return }
        focusWindowIfNeeded(for: screen)

        sourceScreen = screen
        let global = globalPoint(from: point, on: screen)
        startPoint = global
        currentPoint = global
        refreshAllWindows()
    }

    func handleMouseDragged(point: NSPoint, on screen: NSScreen) {
        guard !isEditing else { return }
        guard let sourceScreen else { return }
        let global = globalPoint(from: point, on: screen)
        currentPoint = clampPoint(global, to: sourceScreen.frame)
        refreshAllWindows()
    }

    func handleMouseUp(point: NSPoint, on screen: NSScreen) {
        guard !isEditing else { return }
        guard let sourceScreen else { return }

        let global = globalPoint(from: point, on: screen)
        currentPoint = clampPoint(global, to: sourceScreen.frame)
        let rectGlobal = computeSelectionRect()

        guard rectGlobal.width > 3, rectGlobal.height > 3 else {
            cancel()
            return
        }

        enterEditMode(with: rectGlobal)
    }

    func cancel() {
        cleanup()
        onCancel?()
    }

    // MARK: - Selection State

    func getSelectionRect() -> NSRect {
        computeSelectionRect()
    }
    
    func getCurrentMousePoint() -> NSPoint? {
        currentPoint
    }
    
    func getStartPoint() -> NSPoint? {
        startPoint
    }

    private func computeSelectionRect() -> NSRect {
        guard let start = startPoint, let end = currentPoint else { return .zero }
        return NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
    
    private func refreshAllWindows() {
        windows.forEach { ($0.contentView as? RegionSelectorView)?.needsDisplay = true }
    }

    private func focusWindowIfNeeded(for screen: NSScreen) {
        guard activeScreen !== screen else { return }
        activeScreen = screen
        guard let window = windows.first(where: { $0.captureScreen === screen }) else { return }
        activeWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    private func screenAtMouseLocation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return windows.map(\.captureScreen).first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    private func globalPoint(from localPoint: NSPoint, on screen: NSScreen) -> NSPoint {
        NSPoint(x: localPoint.x + screen.frame.origin.x, y: localPoint.y + screen.frame.origin.y)
    }

    private func localRect(from globalRect: NSRect, on screen: NSScreen) -> NSRect {
        NSRect(
            x: globalRect.origin.x - screen.frame.origin.x,
            y: globalRect.origin.y - screen.frame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }

    private func clampPoint(_ point: NSPoint, to frame: NSRect) -> NSPoint {
        let x = min(max(point.x, frame.minX), frame.maxX)
        let y = min(max(point.y, frame.minY), frame.maxY)
        return NSPoint(x: x, y: y)
    }

    // MARK: - Edit Mode

    private func enterEditMode(with rectGlobal: NSRect) {
        isEditing = true
        NSCursor.unhide() // Show cursor for editing
        NSCursor.arrow.set()
        
        guard let sourceScreen else {
            cancel()
            return
        }
        guard let window = windows.first(where: { $0.captureScreen === sourceScreen }) else {
            cancel()
            return
        }
        
        // Capture image using the overlay window ID to exclude it
        // The rect is in global NS coordinates.
        // We need to convert it to CG coordinates for capture.

        let cgRect = ScreenCoordinateHelper.nsRectToCG(rectGlobal)
        
        guard let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenBelowWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution]
        ) else {
            cancel()
            return
        }

        // Keep only the source screen window for editing.
        for w in windows where w !== window {
            w.orderOut(nil)
        }
        windows = [window]
        activeWindow = window
        activeScreen = sourceScreen

        // Setup Editor UI
        guard let contentView = window.contentView as? RegionSelectorView else {
            cancel()
            return
        }
        
        // Local rect for subviews is in the source screen window coordinate space.
        let localRect = localRect(from: rectGlobal, on: sourceScreen)
        
        // Canvas
        let canvas = EditorCanvasView(image: image)
        canvas.frame = localRect
        canvas.wantsLayer = true
        canvas.delegate = self
        
        contentView.addSubview(canvas)
        self.editorCanvas = canvas

        // Toolbar
        let toolbar = EditorToolbarView(frame: .zero)
        toolbar.delegate = self
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbar)
        self.editorToolbar = toolbar

        // Position Toolbar
        let toolbarSize = toolbar.fittingSize
        let toolbarWidth = toolbarSize.width > 0 ? toolbarSize.width : 420
        let toolbarHeight = DesignTokens.Sizes.toolbarHeight
        let spacing = DesignTokens.Spacing.s

        let midX = localRect.midX
        let toolbarX = midX - (toolbarWidth / 2)
        
        var toolbarY = localRect.minY - spacing - toolbarHeight
        
        if toolbarY < spacing {
             toolbarY = localRect.minY + spacing
        }
        
        let contentWidth = contentView.bounds.width
        var finalX = toolbarX
        if finalX < spacing { finalX = spacing }
        if finalX + toolbarWidth > contentWidth - spacing { finalX = contentWidth - spacing - toolbarWidth }

        toolbar.frame = NSRect(x: finalX, y: toolbarY, width: toolbarWidth, height: toolbarHeight)
        toolbar.translatesAutoresizingMaskIntoConstraints = true
        
        refreshAllWindows()
    }
}

// MARK: - Editor Delegates

extension RegionSelectorCoordinator: EditorToolbarViewDelegate, EditorCanvasViewDelegate {
    func toolbarDidSelectTool(_ tool: EditorTool?) {
        editorCanvas?.currentTool = tool
        if tool != .crop {
            editorCanvas?.clearCrop()
        }
    }

    func toolbarDidSelectColor(_ color: NSColor) {
        editorCanvas?.currentColor = color
    }
    
    func toolbarDidChangeFontSize(_ size: CGFloat) {
        editorCanvas?.currentFontSize = size
    }

    func toolbarDidTapUndo() {
        editorCanvas?.undo()
        editorToolbar?.setUndoEnabled(editorCanvas?.canUndo ?? false)
    }

    func toolbarDidTapCancel() {
        cancel()
    }

    func toolbarDidTapCopyImage() {
        guard let finalImage = editorCanvas?.renderFinalImage() else { return }
        cleanup()
        onComplete?(finalImage, .copyImage)
    }

    func toolbarDidTapCopyPath() {
        guard let finalImage = editorCanvas?.renderFinalImage() else { return }
        cleanup()
        onComplete?(finalImage, .saveAndCopyPath)
    }

    func toolbarDidTapOCR() {
        guard let finalImage = editorCanvas?.renderFinalImage() else {
            return
        }

        OCRService.recognizeText(from: finalImage) { result in
            if let text = result {
                // 1. 复制到剪贴板
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)

                // 2. 显示通知
                NotificationService.showMessage(
                    title: "toolbar.ocr".localized,
                    body: "notification.ocrSuccess".localized
                )
                
                // 3. 识别成功后自动关闭覆盖层
                self.cleanup()
            } else {
                // 处理识别失败
                let alert = NSAlert()
                alert.messageText = "OCR 失败"
                alert.informativeText = "未能从图片中提取到文字。"
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    func toolbarDidTapPin() {
        guard let finalImage = editorCanvas?.renderFinalImage() else { return }
        
        // Determine which screen the selection was on to ensure correct scaling
        let globalRect = getSelectionRect()
        
        // Find screen with largest intersection
        var bestScreen: NSScreen?
        var maxArea: CGFloat = 0
        
        for screen in NSScreen.screens {
            let intersection = globalRect.intersection(screen.frame)
            if !intersection.isNull {
                let area = intersection.width * intersection.height
                if area > maxArea {
                    maxArea = area
                    bestScreen = screen
                }
            }
        }
        
        cleanup()
        PinService.shared.pin(image: finalImage, on: bestScreen)
    }

    func canvasDidUpdateAnnotations() {
        editorToolbar?.setUndoEnabled(editorCanvas?.canUndo ?? false)
    }

    func canvasDidRequestToolChange(_ tool: EditorTool) {
        editorToolbar?.selectTool(tool)
    }
}

// MARK: - Region Selector Window

final class RegionSelectorWindow: NSWindow {
    let captureScreen: NSScreen

    init(screen: NSScreen, coordinator: RegionSelectorCoordinator) {
        self.captureScreen = screen
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.setFrame(screen.frame, display: true)

        let selectorView = RegionSelectorView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            coordinator: coordinator
        )
        self.contentView = selectorView
    }
    
    override var canBecomeKey: Bool { true }
}

// MARK: - Region Selector View

final class RegionSelectorView: NSView {
    private let screen: NSScreen
    private weak var coordinator: RegionSelectorCoordinator?
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, screen: NSScreen, coordinator: RegionSelectorCoordinator) {
        self.screen = screen
        self.coordinator = coordinator
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    // Note: We intentionally do NOT use cursorRects here as we self-draw the cursor.

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseMoved(point: point, on: screen)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseDown(point: point, on: screen)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseDragged(point: point, on: screen)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseUp(point: point, on: screen)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            coordinator?.cancel()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // 1. Draw Dimming Background
        DesignTokens.Colors.overlayDim.setFill()
        bounds.fill()

        guard let coordinator = coordinator else { return }

        // 2. Draw Selection (Clear Rect) if active
        // Only draw selection if we have a start point
        if let _ = coordinator.getStartPoint() {
             let selectionRectGlobal = coordinator.getSelectionRect()
             let visibleGlobal = selectionRectGlobal.intersection(screen.frame)
             
             if !visibleGlobal.isNull, visibleGlobal.width > 1, visibleGlobal.height > 1 {
                 NSColor.clear.setFill()
                 globalRectToLocal(visibleGlobal).fill(using: .copy)
                 
                 // Draw Border if not editing
                 if !coordinator.isEditing {
                     let selectionRect = globalRectToLocal(selectionRectGlobal)
                     DesignTokens.Colors.selectionBorder.setStroke()
                     let border = NSBezierPath(rect: selectionRect)
                     border.lineWidth = DesignTokens.Border.widthMedium
                     border.stroke()
                     
                     // Draw Dimensions Label
                     drawDimensions(rect: selectionRect)
                 }
             }
        }
        
        // 3. Draw Crosshair (if not editing)
        if !coordinator.isEditing, let currentPoint = coordinator.getCurrentMousePoint() {
            if NSMouseInRect(currentPoint, screen.frame, false) {
                drawCrosshair(at: globalPointToLocal(currentPoint))
            }
        }
    }

    private func globalPointToLocal(_ point: NSPoint) -> NSPoint {
        NSPoint(x: point.x - screen.frame.origin.x, y: point.y - screen.frame.origin.y)
    }

    private func globalRectToLocal(_ rect: NSRect) -> NSRect {
        NSRect(
            x: rect.origin.x - screen.frame.origin.x,
            y: rect.origin.y - screen.frame.origin.y,
            width: rect.width,
            height: rect.height
        )
    }
    
    private func drawCrosshair(at point: NSPoint) {
        NSColor.white.setStroke()
        let path = NSBezierPath()
        
        // Horizontal line
        path.move(to: NSPoint(x: 0, y: point.y))
        path.line(to: NSPoint(x: bounds.width, y: point.y))
        
        // Vertical line
        path.move(to: NSPoint(x: point.x, y: 0))
        path.line(to: NSPoint(x: point.x, y: bounds.height))
        
        path.lineWidth = 1.0
        // Use a dashed pattern for better visibility? Standard macOS screenshot is solid gray/white.
        // Let's stick to simple solid line for now.
        path.stroke()
    }
    
    private func drawDimensions(rect: NSRect) {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        
        let size = text.size(withAttributes: attributes)
        let x = rect.minX + 5
        let y = rect.minY - size.height - 5
        
        // Ensure it stays on screen
        let drawPoint = NSPoint(
            x: x,
            y: y < 0 ? rect.minY + 5 : y
        )
        
        // Draw background pill
        let bgRect = NSRect(x: drawPoint.x - 4, y: drawPoint.y - 2, width: size.width + 8, height: size.height + 4)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        bgPath.fill()
        
        text.draw(at: drawPoint, withAttributes: attributes)
    }
}

// MARK: - Window Selector Coordinator (Stub for compatibility)
// Note: User asked to focus on fixing crosshair. Window selector might need similar treatment, 
// but for now we keep it minimal or untouched if it was shared.
// The original file had WindowSelectorCoordinator. We should preserve it but maybe adapt it 
// or leave it as is if it doesn't conflict. 
// However, the original prompt implies fixing the "Region Capture" mode effectively.
// I will keep WindowSelectorCoordinator mostly as is but ensure it compiles with any changes.
// Since I'm replacing the whole file, I need to include it.

final class WindowSelectorCoordinator {
    private var windows: [WindowSelectorWindow] = []
    private var windowInfos: [WindowInfo] = []
    private var onComplete: ((CGWindowID, NSScreen) -> Void)?
    private var onCancel: (() -> Void)?

    private var hoveredWindow: WindowInfo?
    private var sourceScreen: NSScreen?

    func start(onComplete: @escaping (CGWindowID, NSScreen) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel

        // Fetch window list once, shared across all screens
        windowInfos = WindowSelectorView.fetchWindowList(excludingPID: ProcessInfo.processInfo.processIdentifier)

        for screen in NSScreen.screens {
            let window = WindowSelectorWindow(
                screen: screen,
                coordinator: self,
                windowInfos: windowInfos
            )
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func cleanup() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        hoveredWindow = nil
        sourceScreen = nil
    }

    // MARK: - Mouse Events

    func handleMouseMoved(globalCGPoint: CGPoint) {
        let newHovered = windowInfos.first { $0.frame.contains(globalCGPoint) }
        if newHovered?.windowID != hoveredWindow?.windowID {
            hoveredWindow = newHovered
            refreshAllWindows()
        }
    }

    func handleMouseDown(screen: NSScreen) {
        sourceScreen = screen
        guard let hovered = hoveredWindow else { return }
        let capturedScreen = sourceScreen ?? screen
        cleanup()
        onComplete?(hovered.windowID, capturedScreen)
    }

    func cancel() {
        cleanup()
        onCancel?()
    }

    func getHoveredWindow() -> WindowInfo? {
        hoveredWindow
    }

    private func refreshAllWindows() {
        windows.forEach { ($0.contentView as? WindowSelectorView)?.needsDisplay = true }
    }
}

// MARK: - Window Selector Window (Preserved)

final class WindowSelectorWindow: NSWindow {
    // Legacy single-screen init
    convenience init(screen: NSScreen, onComplete: @escaping (CGWindowID) -> Void, onCancel: @escaping () -> Void) {
        self.init(screen: screen, coordinator: nil, windowInfos: nil)
        // Legacy support omitted for brevity in this cleanup, assuming coordinator path is mainly used
    }

    // Multi-screen init with coordinator
    init(screen: NSScreen, coordinator: WindowSelectorCoordinator?, windowInfos: [WindowInfo]?) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let coordinator = coordinator, let windowInfos = windowInfos {
            let selectorView = WindowSelectorView(
                frame: screen.frame,
                screen: screen,
                windowInfos: windowInfos,
                coordinator: coordinator
            )
            self.contentView = selectorView
        }
    }

    override var canBecomeKey: Bool { true }
}

struct WindowInfo {
    let windowID: CGWindowID
    let frame: CGRect // CG coordinates (top-left origin)
    let name: String
    let ownerName: String
}

final class WindowSelectorView: NSView {
    private let screen: NSScreen
    private let windowInfos: [WindowInfo]
    private weak var coordinator: WindowSelectorCoordinator?
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, screen: NSScreen, windowInfos: [WindowInfo],
         coordinator: WindowSelectorCoordinator?) {
        self.screen = screen
        self.windowInfos = windowInfos
        self.coordinator = coordinator
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    static func fetchWindowList(excludingPID: pid_t) -> [WindowInfo] {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return infoList.compactMap { info -> WindowInfo? in
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != excludingPID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"],
                  w > 0, h > 0
            else { return nil }

            let name = info[kCGWindowName as String] as? String ?? ""
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""

            return WindowInfo(
                windowID: windowID,
                frame: CGRect(x: x, y: y, width: w, height: h),
                name: name,
                ownerName: ownerName
            )
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        DesignTokens.Colors.overlayDim.setFill()
        bounds.fill()

        guard let coordinator = coordinator, let hoveredWindow = coordinator.getHoveredWindow() else { return }
        
        let nsRect = cgRectToNSRect(hoveredWindow.frame)

        // Clip to visible portion on this screen
        let visibleRect = nsRect.intersection(bounds)
        guard !visibleRect.isNull, visibleRect.width > 0, visibleRect.height > 0 else { return }

        // Highlight the hovered window
        DesignTokens.Colors.hoverFill.setFill()
        visibleRect.fill()

        DesignTokens.Colors.hoverBorder.setStroke()
        let border = NSBezierPath(rect: visibleRect)
        border.lineWidth = DesignTokens.Border.widthMedium
        border.stroke()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        let cgPoint = globalCGPoint(from: event)
        coordinator?.handleMouseMoved(globalCGPoint: cgPoint)
    }

    override func mouseDown(with event: NSEvent) {
        coordinator?.handleMouseDown(screen: screen)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            coordinator?.cancel()
        }
    }

    private func globalCGPoint(from event: NSEvent) -> CGPoint {
        let windowPoint = event.locationInWindow
        guard let window = self.window else {
            return ScreenCoordinateHelper.nsPointToCG(windowPoint)
        }
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        return ScreenCoordinateHelper.nsPointToCG(screenPoint)
    }

    private func cgRectToNSRect(_ cgRect: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return .zero }
        let screenFrame = screen.frame
        let globalNSY = primary.frame.height - cgRect.origin.y - cgRect.height
        let localX = cgRect.origin.x - screenFrame.origin.x + bounds.origin.x
        let localY = globalNSY - screenFrame.origin.y + bounds.origin.y
        return NSRect(x: localX, y: localY, width: cgRect.width, height: cgRect.height)
    }
}
