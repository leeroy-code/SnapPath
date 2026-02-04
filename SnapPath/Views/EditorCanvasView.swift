import Cocoa

protocol EditorCanvasViewDelegate: AnyObject {
    func canvasDidUpdateAnnotations()
    func canvasDidRequestToolChange(_ tool: EditorTool)
}

final class EditorCanvasView: NSView {

    weak var delegate: EditorCanvasViewDelegate?

    // MARK: - Properties

    private let originalImage: CGImage
    private var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var cropRect: CropRect?

    var currentTool: EditorTool? = .arrow
    var currentColor: NSColor = DesignTokens.Colors.annotationDefault
    var currentLineWidth: CGFloat = 3
    var currentFontSize: CGFloat = 24

    // Drag state
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var isDrawing = false

    // Text input
    private var textEditingView: TextEditingView?
    private var editingAnnotationIndex: Int?  // Index of annotation being re-edited

    // MARK: - Init

    init(image: CGImage) {
        self.originalImage = image
        // Use points instead of pixels for proper Retina display
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        let widthInPoints = CGFloat(image.width) / scaleFactor
        let heightInPoints = CGFloat(image.height) / scaleFactor
        super.init(frame: NSRect(x: 0, y: 0, width: widthInPoints, height: heightInPoints))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw original image (fill the entire view bounds)
        let imageRect = self.bounds
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(originalImage, in: imageRect)
        context.restoreGState()

        // Draw existing annotations (skip the one being edited)
        for (index, annotation) in annotations.enumerated() {
            if index == editingAnnotationIndex {
                continue  // Don't draw annotation currently being edited
            }
            draw(annotation: annotation, in: context)
        }

        // Draw current annotation being created
        if let start = dragStart, let current = dragCurrent, isDrawing, let tool = currentTool {
            switch tool {
            case .arrow:
                let tempAnnotation = Annotation.arrow(start: start, end: current, color: currentColor, lineWidth: currentLineWidth)
                draw(annotation: tempAnnotation, in: context)

            case .rectangle:
                let rect = rectFromPoints(start, current)
                let tempAnnotation = Annotation.rectangle(rect: rect, color: currentColor, lineWidth: currentLineWidth)
                draw(annotation: tempAnnotation, in: context)

            case .crop:
                let rect = rectFromPoints(start, current)
                drawCropOverlay(rect: rect, in: context)

            case .text:
                break
            }
        }

        // Draw crop overlay if set
        if let crop = cropRect, !crop.isEmpty {
            drawCropOverlay(rect: crop.rect, in: context)
        }
    }

    private func draw(annotation: Annotation, in context: CGContext) {
        switch annotation {
        case .arrow(let start, let end, let color, let lineWidth):
            drawArrow(from: start, to: end, color: color, lineWidth: lineWidth, in: context)

        case .rectangle(let rect, let color, let lineWidth):
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.addRect(rect)
            context.strokePath()

        case .text(let origin, let content, let color, let fontSize):
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

        // Arrowhead
        let arrowLength: CGFloat = 15
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

    private func drawCropOverlay(rect: CGRect, in context: CGContext) {
        let bounds = self.bounds

        // Dim outside area
        context.setFillColor(DesignTokens.Colors.cropOverlay.cgColor)

        // Top
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: rect.minY))
        // Bottom
        context.fill(CGRect(x: 0, y: rect.maxY, width: bounds.width, height: bounds.height - rect.maxY))
        // Left
        context.fill(CGRect(x: 0, y: rect.minY, width: rect.minX, height: rect.height))
        // Right
        context.fill(CGRect(x: rect.maxX, y: rect.minY, width: bounds.width - rect.maxX, height: rect.height))

        // Draw border
        context.setStrokeColor(DesignTokens.Colors.selectionBorder.cgColor)
        context.setLineWidth(DesignTokens.Border.widthMedium)
        context.addRect(rect)
        context.strokePath()
    }

    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let w = abs(p2.x - p1.x)
        let h = abs(p2.y - p1.y)
        return CGRect(x: x, y: y, width: w, height: h)
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

        // No tool selected → view-only mode, ignore drawing
        guard let tool = currentTool else { return }

        if tool == .text {
            // Check if clicking on an existing text annotation for re-editing
            if let index = textAnnotationAt(point) {
                startEditingAnnotation(at: index)
                return
            }
            // Otherwise, start new text input
            showTextInput(at: point)
            return
        }

        dragStart = point
        dragCurrent = point
        isDrawing = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing, currentTool != nil else { return }
        dragCurrent = convert(event.locationInWindow, from: nil)
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
            annotations.append(.arrow(start: start, end: end, color: currentColor, lineWidth: currentLineWidth))

        case .rectangle:
            annotations.append(.rectangle(rect: rect, color: currentColor, lineWidth: currentLineWidth))

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
        textEditingView?.removeFromSuperview()

        let editView = TextEditingView(
            origin: point,
            color: currentColor,
            fontSize: currentFontSize,
            initialText: initialText
        )
        editView.delegate = self

        addSubview(editView)
        editView.beginEditing()
        textEditingView = editView
    }

    private func textAnnotationAt(_ point: CGPoint) -> Int? {
        for (index, annotation) in annotations.enumerated().reversed() {
            if annotation.isText, let rect = annotation.boundingRect(), rect.contains(point) {
                return index
            }
        }
        return nil
    }

    private func startEditingAnnotation(at index: Int) {
        guard case .text(let origin, let content, let color, let fontSize) = annotations[index] else { return }

        // Store the index for later update
        editingAnnotationIndex = index

        // Create editing view with existing content
        let editView = TextEditingView(
            origin: origin,
            color: color,
            fontSize: fontSize,
            initialText: content
        )
        editView.delegate = self

        addSubview(editView)
        editView.beginEditing()
        textEditingView = editView

        // Redraw to hide the annotation being edited
        needsDisplay = true
    }

    private func confirmTextEditing() {
        guard let editView = textEditingView else { return }

        let trimmedText = editView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedText.isEmpty {
            pushUndo()

            let newAnnotation = Annotation.text(
                origin: editView.textOrigin,
                content: editView.text,
                color: editView.textColor,
                fontSize: editView.fontSize
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
        needsDisplay = true
    }

    private func cancelTextEditing() {
        textEditingView?.removeFromSuperview()
        textEditingView = nil
        editingAnnotationIndex = nil
        needsDisplay = true
    }

    @objc private func textInputDidEnd(_ sender: NSTextField) {
        guard !sender.stringValue.isEmpty else {
            sender.removeFromSuperview()
            return
        }

        pushUndo()

        let origin = sender.frame.origin
        annotations.append(.text(origin: origin, content: sender.stringValue, color: currentColor, fontSize: currentFontSize))

        sender.removeFromSuperview()
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations()
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
