import Cocoa

protocol EditorCanvasViewDelegate: AnyObject {
    func canvasDidUpdateAnnotations()
    func canvasDidRequestToolChange(_ tool: EditorTool)
}

final class EditorCanvasView: NSView {

    weak var delegate: EditorCanvasViewDelegate?

    // MARK: - Properties

    private let originalImage: CGImage
    private let imagePixelsPerPoint: CGFloat
    private let imagePixelSize: CGSize
    private let imageSizeInPoints: CGSize

    private var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var cropRect: CropRect?

    var currentTool: EditorTool? = .arrow
    var currentColor: NSColor = DesignTokens.Colors.annotationDefault
    var currentLineWidth: CGFloat = 3
    var currentFontSize: CGFloat = 24

    // Drag state (in image pixel coordinates)
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var isDrawing = false

    // Text input
    private var textEditingView: TextEditingView?
    private var editingAnnotationIndex: Int?
    private var textEditingOriginInPixels: CGPoint?
    private var textEditingFontSizeInPixels: CGFloat?

    // MARK: - Init

    init(image: CGImage, pixelsPerPoint: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0) {
        self.originalImage = image
        self.imagePixelsPerPoint = max(1, pixelsPerPoint)
        self.imagePixelSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        self.imageSizeInPoints = CGSize(
            width: imagePixelSize.width / self.imagePixelsPerPoint,
            height: imagePixelSize.height / self.imagePixelsPerPoint
        )
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw existing annotations (skip the one being edited)
        for (index, annotation) in annotations.enumerated() {
            if index == editingAnnotationIndex {
                continue
            }
            draw(annotation: annotation, in: context)
        }

        // Draw current annotation being created
        if let start = dragStart, let current = dragCurrent, isDrawing, let tool = currentTool {
            switch tool {
            case .arrow:
                let tempAnnotation = Annotation.arrow(
                    start: start,
                    end: current,
                    color: currentColor,
                    lineWidth: currentLineWidthPixels()
                )
                draw(annotation: tempAnnotation, in: context)

            case .rectangle:
                let rect = rectFromPoints(start, current)
                let tempAnnotation = Annotation.rectangle(
                    rect: rect,
                    color: currentColor,
                    lineWidth: currentLineWidthPixels()
                )
                draw(annotation: tempAnnotation, in: context)

            case .crop:
                let rect = rectFromPoints(start, current)
                drawCropOverlay(pixelRect: rect, in: context)

            case .text:
                break
            }
        }

        // Draw crop overlay if set
        if let crop = cropRect, !crop.isEmpty {
            drawCropOverlay(pixelRect: crop.rect, in: context)
        }
    }

    override func layout() {
        super.layout()

        // Keep the editing view anchored to the image while resizing.
        guard let editView = textEditingView, let originPx = textEditingOriginInPixels else { return }
        let viewOrigin = viewPoint(fromPixelPoint: originPx)
        if editView.frame.origin != viewOrigin {
            editView.frame.origin = viewOrigin
        }
    }

    private func draw(annotation: Annotation, in context: CGContext) {
        let pointsPerPixel = currentPointsPerPixel()
        guard pointsPerPixel > 0 else { return }

        switch annotation {
        case .arrow(let startPx, let endPx, let color, let lineWidthPx):
            let start = viewPoint(fromPixelPoint: startPx)
            let end = viewPoint(fromPixelPoint: endPx)
            let lineWidth = lineWidthPx * pointsPerPixel
            drawArrow(from: start, to: end, color: color, lineWidth: lineWidth, in: context)

        case .rectangle(let rectPx, let color, let lineWidthPx):
            let rect = viewRect(fromPixelRect: rectPx)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidthPx * pointsPerPixel)
            context.addRect(rect)
            context.strokePath()

        case .text(let originPx, let content, let color, let fontSizePx):
            let origin = viewPoint(fromPixelPoint: originPx)
            let fontSize = fontSizePx * pointsPerPixel
            let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let string = NSAttributedString(string: content, attributes: attributes)
            string.draw(at: origin)
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: CGFloat, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Main line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Arrowhead (scaled with stroke width)
        let arrowLength: CGFloat = max(6, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)

        let arrow1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrow2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: arrow1)
        context.move(to: end)
        context.addLine(to: arrow2)
        context.strokePath()
    }

    private func drawCropOverlay(pixelRect: CGRect, in context: CGContext) {
        let imageRect = imageRectInView()
        guard !imageRect.isEmpty else { return }

        let cropRect = viewRect(fromPixelRect: pixelRect).intersection(imageRect)
        guard !cropRect.isEmpty else { return }

        // Dim outside area (within the image rect)
        context.setFillColor(DesignTokens.Colors.cropOverlay.cgColor)

        // Top
        if cropRect.minY > imageRect.minY {
            context.fill(CGRect(
                x: imageRect.minX,
                y: imageRect.minY,
                width: imageRect.width,
                height: cropRect.minY - imageRect.minY
            ))
        }

        // Bottom
        if cropRect.maxY < imageRect.maxY {
            context.fill(CGRect(
                x: imageRect.minX,
                y: cropRect.maxY,
                width: imageRect.width,
                height: imageRect.maxY - cropRect.maxY
            ))
        }

        // Left
        if cropRect.minX > imageRect.minX {
            context.fill(CGRect(
                x: imageRect.minX,
                y: cropRect.minY,
                width: cropRect.minX - imageRect.minX,
                height: cropRect.height
            ))
        }

        // Right
        if cropRect.maxX < imageRect.maxX {
            context.fill(CGRect(
                x: cropRect.maxX,
                y: cropRect.minY,
                width: imageRect.maxX - cropRect.maxX,
                height: cropRect.height
            ))
        }

        // Draw border
        context.setStrokeColor(DesignTokens.Colors.selectionBorder.cgColor)
        context.setLineWidth(DesignTokens.Border.widthMedium)
        context.addRect(cropRect)
        context.strokePath()
    }

    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let w = abs(p2.x - p1.x)
        let h = abs(p2.y - p1.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Coordinate Mapping

    private func imageRectInView() -> CGRect {
        let bounds = self.bounds
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return .zero }

        let scale = min(bounds.width / imagePixelSize.width, bounds.height / imagePixelSize.height)
        let width = imagePixelSize.width * scale
        let height = imagePixelSize.height * scale
        let x = bounds.minX + (bounds.width - width) / 2
        let y = bounds.minY + (bounds.height - height) / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func currentPointsPerPixel() -> CGFloat {
        let rect = imageRectInView()
        guard rect.width > 0 else { return 0 }
        return rect.width / imagePixelSize.width
    }

    private func currentDisplayScale() -> CGFloat {
        let rect = imageRectInView()
        guard imageSizeInPoints.width > 0 else { return 1 }
        return rect.width / imageSizeInPoints.width
    }

    private func viewPoint(fromPixelPoint point: CGPoint) -> CGPoint {
        let rect = imageRectInView()
        guard !rect.isEmpty else { return .zero }

        let nx = point.x / imagePixelSize.width
        let ny = point.y / imagePixelSize.height

        return CGPoint(
            x: rect.minX + nx * rect.width,
            y: rect.minY + ny * rect.height
        )
    }

    private func viewRect(fromPixelRect rectPx: CGRect) -> CGRect {
        let p1 = viewPoint(fromPixelPoint: CGPoint(x: rectPx.minX, y: rectPx.minY))
        let p2 = viewPoint(fromPixelPoint: CGPoint(x: rectPx.maxX, y: rectPx.maxY))
        return CGRect(x: p1.x, y: p1.y, width: p2.x - p1.x, height: p2.y - p1.y)
    }

    private func pixelPoint(fromViewPoint viewPoint: CGPoint, clampToImage: Bool) -> CGPoint? {
        let rect = imageRectInView()
        guard !rect.isEmpty else { return nil }

        var point = viewPoint
        if clampToImage {
            point.x = min(max(point.x, rect.minX), rect.maxX)
            point.y = min(max(point.y, rect.minY), rect.maxY)
        } else {
            guard rect.contains(point) else { return nil }
        }

        let nx = (point.x - rect.minX) / rect.width
        let ny = (point.y - rect.minY) / rect.height

        return CGPoint(
            x: nx * imagePixelSize.width,
            y: ny * imagePixelSize.height
        )
    }

    private func currentLineWidthPixels() -> CGFloat {
        currentLineWidth * imagePixelsPerPoint
    }

    private func currentFontSizePixels() -> CGFloat {
        currentFontSize * imagePixelsPerPoint
    }

    // MARK: - Mouse Events

    override func keyDown(with event: NSEvent) {
        // Handle number keys 1-4 for tool switching
        let chars = event.charactersIgnoringModifiers ?? ""
        switch chars {
        case "1":
            delegate?.canvasDidRequestToolChange(.arrow)
        case "2":
            delegate?.canvasDidRequestToolChange(.rectangle)
        case "3":
            delegate?.canvasDidRequestToolChange(.text)
        case "4":
            delegate?.canvasDidRequestToolChange(.crop)
        default:
            // Allow other keys (like standard undo if handled by responder chain)
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // If there's an active text editing view, check if click is outside
        if let editView = textEditingView {
            if !editView.frame.contains(point) {
                // Click outside - confirm the current text
                confirmTextEditing()
            }
            return
        }

        // No tool selected -> view-only mode, ignore drawing
        guard let tool = currentTool else { return }

        if tool == .text {
            guard let pixel = pixelPoint(fromViewPoint: point, clampToImage: false) else { return }

            // Check if clicking on an existing text annotation for re-editing
            if let index = textAnnotationAt(pixel) {
                startEditingAnnotation(at: index)
                return
            }

            // Otherwise, start new text input
            showTextInput(at: point)
            return
        }

        guard let pixel = pixelPoint(fromViewPoint: point, clampToImage: false) else { return }
        dragStart = pixel
        dragCurrent = pixel
        isDrawing = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing, currentTool != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let pixel = pixelPoint(fromViewPoint: point, clampToImage: true) else { return }
        dragCurrent = pixel
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing, let start = dragStart, let end = dragCurrent, let tool = currentTool else {
            isDrawing = false
            dragStart = nil
            dragCurrent = nil
            return
        }

        isDrawing = false

        let rect = rectFromPoints(start, end)
        guard rect.width > 2 || rect.height > 2 else {
            dragStart = nil
            dragCurrent = nil
            needsDisplay = true
            return
        }

        pushUndo()

        switch tool {
        case .arrow:
            annotations.append(.arrow(
                start: start,
                end: end,
                color: currentColor,
                lineWidth: currentLineWidthPixels()
            ))

        case .rectangle:
            annotations.append(.rectangle(
                rect: rect,
                color: currentColor,
                lineWidth: currentLineWidthPixels()
            ))

        case .crop:
            cropRect = CropRect(rect: rect)

        case .text:
            break
        }

        dragStart = nil
        dragCurrent = nil
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations()
    }

    // MARK: - Text Input

    private func showTextInput(at point: CGPoint, initialText: String = "") {
        guard let originPx = pixelPoint(fromViewPoint: point, clampToImage: false) else { return }

        let editView = TextEditingView(
            origin: point,
            color: currentColor,
            fontSize: currentFontSize * currentDisplayScale(),
            initialText: initialText
        )
        editView.delegate = self

        addSubview(editView)
        editView.beginEditing()

        textEditingView = editView
        textEditingOriginInPixels = originPx
        textEditingFontSizeInPixels = currentFontSizePixels()
    }

    private func textAnnotationAt(_ pixelPoint: CGPoint) -> Int? {
        for (index, annotation) in annotations.enumerated().reversed() {
            if annotation.isText, let rect = annotation.boundingRect(), rect.contains(pixelPoint) {
                return index
            }
        }
        return nil
    }

    private func startEditingAnnotation(at index: Int) {
        guard case .text(let originPx, let content, let color, let fontSizePx) = annotations[index] else { return }

        // Store the index for later update
        editingAnnotationIndex = index

        // Create editing view with existing content
        let viewOrigin = viewPoint(fromPixelPoint: originPx)
        let editView = TextEditingView(
            origin: viewOrigin,
            color: color,
            fontSize: fontSizePx * currentPointsPerPixel(),
            initialText: content
        )
        editView.delegate = self

        addSubview(editView)
        editView.beginEditing()

        textEditingView = editView
        textEditingOriginInPixels = originPx
        textEditingFontSizeInPixels = fontSizePx

        // Redraw to hide the annotation being edited
        needsDisplay = true
    }

    private func confirmTextEditing() {
        guard let editView = textEditingView else { return }

        let trimmedText = editView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedText.isEmpty {
            pushUndo()

            let originPx = textEditingOriginInPixels ?? pixelPoint(fromViewPoint: editView.textOrigin, clampToImage: true) ?? .zero
            let fontSizePx = textEditingFontSizeInPixels ?? currentFontSizePixels()
            let newAnnotation = Annotation.text(
                origin: originPx,
                content: editView.text,
                color: editView.textColor,
                fontSize: fontSizePx
            )

            if let editingIndex = editingAnnotationIndex {
                // Replace existing annotation
                annotations[editingIndex] = newAnnotation
            } else {
                // Add new annotation
                annotations.append(newAnnotation)
            }

            delegate?.canvasDidUpdateAnnotations()
        } else if let editingIndex = editingAnnotationIndex {
            // Empty text while editing - remove the annotation
            pushUndo()
            annotations.remove(at: editingIndex)
            delegate?.canvasDidUpdateAnnotations()
        }

        editView.removeFromSuperview()
        textEditingView = nil
        editingAnnotationIndex = nil
        textEditingOriginInPixels = nil
        textEditingFontSizeInPixels = nil
        needsDisplay = true
    }

    private func cancelTextEditing() {
        textEditingView?.removeFromSuperview()
        textEditingView = nil
        editingAnnotationIndex = nil
        textEditingOriginInPixels = nil
        textEditingFontSizeInPixels = nil
        needsDisplay = true
    }

    // MARK: - Undo

    private func pushUndo() {
        undoStack.append(annotations)
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    @objc func undo(_ sender: Any?) {
        if let prev = undoStack.popLast() {
            annotations = prev
            needsDisplay = true
            delegate?.canvasDidUpdateAnnotations()
        }
    }

    func undo() {
        undo(nil)
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    // MARK: - Clear Crop

    func clearCrop() {
        cropRect = nil
        needsDisplay = true
    }

    // MARK: - Render Final Image

    func renderFinalImage() -> CGImage? {
        AnnotationRenderer.render(annotations: annotations, cropRect: cropRect, onto: originalImage)
    }
}

// MARK: - TextEditingViewDelegate

extension EditorCanvasView: TextEditingViewDelegate {
    func textEditingDidConfirm(_ view: TextEditingView, text: String) {
        confirmTextEditing()
    }

    func textEditingDidCancel(_ view: TextEditingView) {
        cancelTextEditing()
    }
}
