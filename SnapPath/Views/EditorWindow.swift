import Cocoa

final class EditorWindow: NSWindow, NSWindowDelegate {

    private let originalImage: CGImage
    private let onCopyImage: (CGImage) -> Void
    private let onCopyPath: (CGImage) -> Void
    private let onCancel: () -> Void
    private let sourceScreen: NSScreen?

    private var toolbarView: EditorToolbarView!
    private var canvasView: EditorCanvasView!
    private var scrollView: NSScrollView!
    private let toolbarHeight: CGFloat = 44

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

        // Window size = image size in points (toolbar overlays)
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

        // Scroll view for canvas (fill entire window)
        scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .darkGray
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        // Canvas
        canvasView = EditorCanvasView(image: originalImage)
        canvasView.delegate = self
        scrollView.documentView = canvasView

        // Enable magnification for zoom
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 4.0

        // Toolbar (floating at bottom)
        toolbarView = EditorToolbarView(frame: .zero)
        toolbarView.delegate = self
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarView, positioned: .above, relativeTo: scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            toolbarView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.l),
            toolbarView.heightAnchor.constraint(equalToConstant: toolbarHeight)
        ])

        updateUndoState()
    }

    private func updateUndoState() {
        toolbarView.setUndoEnabled(canvasView.canUndo)
    }
}

// MARK: - EditorToolbarViewDelegate

extension EditorWindow: EditorToolbarViewDelegate {

    func toolbarDidSelectTool(_ tool: EditorTool?) {
        canvasView.currentTool = tool
        if tool != .crop {
            canvasView.clearCrop()
        }
    }

    func toolbarDidSelectColor(_ color: NSColor) {
        canvasView.currentColor = color
    }

    func toolbarDidChangeFontSize(_ size: CGFloat) {
        canvasView.currentFontSize = size
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
        PinService.shared.pin(image: finalImage)
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
