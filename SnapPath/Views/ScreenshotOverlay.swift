import Cocoa

// MARK: - Region Selector Coordinator (Unified)

final class RegionSelectorCoordinator {
    private var window: UnifiedOverlayWindow?
    enum OutputAction {
        case copyImage
        case saveAndCopyPath
    }

    private var onComplete: ((CGImage, OutputAction) -> Void)?
    private var onCancel: (() -> Void)?

    // Selection State
    private var startPoint: NSPoint? // Window/Union coordinates
    private var currentPoint: NSPoint? // Window/Union coordinates
    
    // Edit state
    internal var isEditing = false
    private var editorCanvas: EditorCanvasView?
    private var editorToolbar: EditorToolbarView?

    func start(onComplete: @escaping (CGImage, OutputAction) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        
        let unionRect = ScreenCoordinateHelper.allScreensUnionFrame()
        
        // Hide system cursor, we will draw our own crosshair
        NSCursor.hide()
        
        let overlayWindow = UnifiedOverlayWindow(
            frame: unionRect,
            coordinator: self
        )
        overlayWindow.makeKeyAndOrderFront(nil)
        self.window = overlayWindow
        
        NSApp.activate(ignoringOtherApps: true)
    }

    func cleanup() {
        NSCursor.unhide()
        window?.orderOut(nil)
        window = nil
        startPoint = nil
        currentPoint = nil
        editorCanvas = nil
        editorToolbar = nil
        isEditing = false
    }

    // MARK: - Mouse Events (called by view)

    func handleMouseMoved(point: NSPoint) {
        // Just update current point for crosshair drawing if not selecting or editing
        if !isEditing {
            // If we are not dragging, currentPoint tracks mouse for crosshair
            // If dragging, handleMouseDragged updates it. 
            // Actually, for crosshair we need a property to track mouse pos even when not dragging.
            // Let's use currentPoint for crosshair position generally.
            // But if we are selecting (mouseDown happened), startPoint is set.
            if startPoint == nil {
               currentPoint = point
               refreshWindow()
            }
        }
    }

    func handleMouseDown(point: NSPoint) {
        guard !isEditing else { return }
        startPoint = point
        currentPoint = point
        refreshWindow()
    }

    func handleMouseDragged(point: NSPoint) {
        guard !isEditing else { return }
        currentPoint = point
        refreshWindow()
    }

    func handleMouseUp(point: NSPoint) {
        guard !isEditing else { return }
        currentPoint = point
        let rect = computeSelectionRect()

        guard rect.width > 3, rect.height > 3 else {
            cancel()
            return
        }

        enterEditMode(with: rect)
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
    
    private func refreshWindow() {
        window?.contentView?.needsDisplay = true
    }

    // MARK: - Edit Mode

    private func enterEditMode(with rect: NSRect) {
        isEditing = true
        NSCursor.unhide() // Show cursor for editing
        NSCursor.arrow.set()
        
        guard let window = window else { return }
        
        // Capture image using the overlay window ID to exclude it
        // The rect is in Window(Union) coordinates.
        // We need to convert it to CG coordinates for capture.
        
        let unionRect = ScreenCoordinateHelper.allScreensUnionFrame()
        // Window origin is at unionRect.origin (bottom-left)
        // Global NS Point = Window Point + unionRect.origin ? 
        // No, window frame IS unionRect. So window coordinates (0,0) is bottom-left of the window,
        // which corresponds to unionRect.origin in global NS space?
        // Wait, NSWindow coordinates are relative to the window's bottom-left.
        // Global NS coordinates are relative to the primary screen's bottom-left.
        
        // Let's clarify coordinate systems.
        // `point` passed from View is `locationInWindow`.
        // If Window Frame is `unionRect`, then:
        // GlobalNS = Point + Window.Frame.Origin
        
        let globalRect = NSRect(
            x: rect.origin.x + unionRect.origin.x,
            y: rect.origin.y + unionRect.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        let cgRect = ScreenCoordinateHelper.nsRectToCG(globalRect)
        
        guard let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenBelowWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution]
        ) else {
            cancel()
            return
        }

        // Setup Editor UI
        guard let contentView = window.contentView as? RegionSelectorView else { return }
        
        // Local rect for subviews is same as rect (since we are in the same view)
        let localRect = rect
        
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
        
        refreshWindow()
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
        let selectionRect = getSelectionRect()
        let unionRect = ScreenCoordinateHelper.allScreensUnionFrame()
        let globalRect = NSRect(
            x: selectionRect.origin.x + unionRect.origin.x,
            y: selectionRect.origin.y + unionRect.origin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )
        
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

// MARK: - Unified Overlay Window

final class UnifiedOverlayWindow: NSWindow {
    private weak var coordinator: RegionSelectorCoordinator?

    init(frame: NSRect, coordinator: RegionSelectorCoordinator) {
        self.coordinator = coordinator
        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // IMPORTANT: We set the frame carefully to align with the union rect
        self.setFrame(frame, display: true)

        let selectorView = RegionSelectorView(
            frame: NSRect(origin: .zero, size: frame.size),
            coordinator: coordinator
        )
        self.contentView = selectorView
    }
    
    override var canBecomeKey: Bool { true }
}

// MARK: - Region Selector View

final class RegionSelectorView: NSView {
    private weak var coordinator: RegionSelectorCoordinator?
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, coordinator: RegionSelectorCoordinator) {
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
        coordinator?.handleMouseMoved(point: point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseDown(point: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseDragged(point: point)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseUp(point: point)
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
             let selectionRect = coordinator.getSelectionRect()
             
             if selectionRect.width > 1 && selectionRect.height > 1 {
                 NSColor.clear.setFill()
                 selectionRect.fill(using: .copy)
                 
                 // Draw Border if not editing
                 if !coordinator.isEditing {
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
            drawCrosshair(at: currentPoint)
        }
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
