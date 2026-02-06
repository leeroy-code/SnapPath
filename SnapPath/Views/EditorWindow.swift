import Cocoa

private final class EditorToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class EditorWindow: NSWindow, NSWindowDelegate {

    private let originalImage: CGImage
    private let onCopyImage: (CGImage) -> Void
    private let onCopyPath: (CGImage) -> Void
    private let onCancel: () -> Void
    private let sourceScreen: NSScreen?
    private let imageSizeInPoints: NSSize
    private let pixelsPerPoint: CGFloat

    private var toolbarView: EditorToolbarView!
    private var toolbarWindow: EditorToolbarPanel?
    private var imageView: NSImageView!
    private var canvasView: EditorCanvasView!
    private let toolbarHeight: CGFloat = 38
    private let toolbarOutsideGap: CGFloat = 0

    init(image: CGImage, sourceScreen: NSScreen? = nil, onCopyImage: @escaping (CGImage) -> Void, onCopyPath: @escaping (CGImage) -> Void, onCancel: @escaping () -> Void) {
        self.originalImage = image
        self.onCopyImage = onCopyImage
        self.onCopyPath = onCopyPath
        self.onCancel = onCancel
        self.sourceScreen = sourceScreen

        // Use source screen if available, otherwise fall back to main/first screen
        let screen = sourceScreen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let scaleFactor = screen.backingScaleFactor
        let maxWidth = screenFrame.width * 0.85
        let maxHeight = screenFrame.height * 0.85
        let minWindowWidth: CGFloat = 400
        let minWindowHeight: CGFloat = 300

        // Convert pixel dimensions to points for proper display
        let imageWidthInPoints = CGFloat(image.width) / scaleFactor
        let imageHeightInPoints = CGFloat(image.height) / scaleFactor
        self.imageSizeInPoints = NSSize(width: imageWidthInPoints, height: imageHeightInPoints)
        self.pixelsPerPoint = scaleFactor

        // Window size = image size
        var contentWidth = imageWidthInPoints
        var contentHeight = imageHeightInPoints

        // Only scale down if exceeds screen bounds
        if contentWidth > maxWidth || contentHeight > maxHeight {
            let scaleX = maxWidth / contentWidth
            let scaleY = maxHeight / contentHeight
            let scale = min(scaleX, scaleY)
            contentWidth = imageWidthInPoints * scale
            contentHeight = imageHeightInPoints * scale
        }

        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: contentHeight
        )

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Lock window aspect ratio to match image
        let contentRatio = NSSize(
            width: imageWidthInPoints,
            height: imageHeightInPoints
        )
        self.contentAspectRatio = contentRatio

        self.title = "editor.windowTitle".localized
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: minWindowWidth, height: minWindowHeight)
        self.delegate = self

        // Center on the source screen instead of default behavior
        centerOnScreen(screen)

        setupUI()
    }

    private func centerOnScreen(_ screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func setupUI() {
        guard let contentView = self.contentView else { return }

        let containerView = NSView(frame: .zero)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.darkGray.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Toolbar (outside the editor window, attached below)
        toolbarView = EditorToolbarView(frame: .zero)
        toolbarView.delegate = self

        let nsImage = NSImage(cgImage: originalImage, size: imageSizeInPoints)
        imageView = NSImageView(frame: .zero)
        imageView.image = nsImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)

        // Canvas (overlay)
        canvasView = EditorCanvasView(image: originalImage, pixelsPerPoint: pixelsPerPoint)
        canvasView.delegate = self
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(canvasView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        setupToolbarWindow()
        updateUndoState()
    }

    private func setupToolbarWindow() {
        teardownToolbarWindow()

        let fittingWidth = max(toolbarView.fittingSize.width, 1)
        let panelFrame = NSRect(x: 0, y: 0, width: fittingWidth, height: toolbarHeight)
        let panel = EditorToolbarPanel(
            contentRect: panelFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = self.level
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isExcludedFromWindowsMenu = true

        let panelContentView = NSView(frame: NSRect(origin: .zero, size: panelFrame.size))
        panel.contentView = panelContentView

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        panelContentView.addSubview(toolbarView)
        NSLayoutConstraint.activate([
            toolbarView.leadingAnchor.constraint(equalTo: panelContentView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: panelContentView.trailingAnchor),
            toolbarView.topAnchor.constraint(equalTo: panelContentView.topAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: panelContentView.bottomAnchor)
        ])

        toolbarWindow = panel
        addChildWindow(panel, ordered: .above)
        updateToolbarWindowFrame()
        panel.orderFront(nil)
    }

    private func updateToolbarWindowFrame() {
        guard let toolbarWindow else { return }

        let width = max(toolbarView.fittingSize.width, 1)
        let height = toolbarHeight
        let parentFrame = frame
        let visibleFrame = preferredVisibleFrameForToolbar()

        let preferredX = parentFrame.midX - (width / 2)
        let minX = visibleFrame.minX
        let maxX = max(minX, visibleFrame.maxX - width)
        let x = min(max(preferredX, minX), maxX)

        let preferredBelowY = parentFrame.minY - height - toolbarOutsideGap
        let preferredAboveY = parentFrame.maxY + toolbarOutsideGap

        let hasRoomBelow = preferredBelowY >= visibleFrame.minY
        let hasRoomAbove = preferredAboveY + height <= visibleFrame.maxY

        let y: CGFloat
        if hasRoomBelow {
            y = preferredBelowY
        } else if hasRoomAbove {
            y = preferredAboveY
        } else {
            y = min(max(preferredBelowY, visibleFrame.minY), visibleFrame.maxY - height)
        }

        let nextFrame = NSRect(x: x, y: y, width: width, height: height)
        toolbarWindow.setFrame(nextFrame, display: false)
    }

    private func preferredVisibleFrameForToolbar() -> NSRect {
        if let currentScreen = screen {
            return currentScreen.visibleFrame
        }
        if let sourceScreen {
            return sourceScreen.visibleFrame
        }
        if let mainScreen = NSScreen.main {
            return mainScreen.visibleFrame
        }
        return ScreenCoordinateHelper.allScreensUnionFrame()
    }

    private func teardownToolbarWindow() {
        guard let toolbarWindow else { return }

        removeChildWindow(toolbarWindow)
        toolbarWindow.orderOut(nil)
        self.toolbarWindow = nil
    }

    private func updateUndoState() {
        toolbarView.setUndoEnabled(canvasView.canUndo)
    }
}

// MARK: - NSWindowDelegate

extension EditorWindow {
    func windowDidMove(_ notification: Notification) {
        updateToolbarWindowFrame()
    }

    func windowDidResize(_ notification: Notification) {
        updateToolbarWindowFrame()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        toolbarWindow?.orderOut(nil)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        updateToolbarWindowFrame()
        toolbarWindow?.orderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        teardownToolbarWindow()
    }
}

// MARK: - EditorToolbarViewDelegate

extension EditorWindow: EditorToolbarViewDelegate {

    func toolbarDidSelectTool(_ tool: EditorTool?) {
        canvasView.currentTool = tool
        if tool != .crop {
            canvasView.clearCrop()
        }
        focusEditorWindowForCanvasInput()
    }

    func toolbarDidSelectColor(_ color: NSColor) {
        canvasView.currentColor = color
        focusEditorWindowForCanvasInput()
    }

    func toolbarDidChangeFontSize(_ size: CGFloat) {
        canvasView.currentFontSize = size
        focusEditorWindowForCanvasInput()
    }

    func toolbarDidTapUndo() {
        canvasView.undo()
        updateUndoState()
    }

    func toolbarDidTapCancel() {
        onCancel()
    }

    func toolbarDidTapCopyImage() {
        guard let finalImage = canvasView.renderFinalImage() else {
            showRenderError()
            return
        }
        onCopyImage(finalImage)
    }

    func toolbarDidTapCopyPath() {
        guard let finalImage = canvasView.renderFinalImage() else {
            showRenderError()
            return
        }
        onCopyPath(finalImage)
    }

    func toolbarDidTapPin() {
        guard let finalImage = canvasView.renderFinalImage() else {
            showRenderError()
            return
        }
        PinService.shared.pin(image: finalImage, on: sourceScreen)
        onCancel() // Close editor after pinning
    }

    func toolbarDidTapOCR() {
        guard let finalImage = canvasView.renderFinalImage() else {
            showRenderError()
            return
        }

        OCRService.recognizeText(from: finalImage) { [weak self] result in
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
                
                // 3. 识别成功后自动关闭窗口
                self?.onCancel()
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

    private func showRenderError() {
        let alert = NSAlert()
        alert.messageText = "editor.renderError".localized
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func focusEditorWindowForCanvasInput() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }
}

// MARK: - EditorCanvasViewDelegate

extension EditorWindow: EditorCanvasViewDelegate {

    func canvasDidUpdateAnnotations() {
        updateUndoState()
    }

    func canvasDidRequestToolChange(_ tool: EditorTool) {
        toolbarView.selectTool(tool)
    }
}
