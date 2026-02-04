import Cocoa

protocol TextEditingViewDelegate: AnyObject {
    func textEditingDidConfirm(_ view: TextEditingView, text: String)
    func textEditingDidCancel(_ view: TextEditingView)
}

final class TextEditingView: NSView, NSTextViewDelegate {
    weak var delegate: TextEditingViewDelegate?

    private let textView: NSTextView
    private let scrollView: NSScrollView

    let textColor: NSColor
    let fontSize: CGFloat

    private let minWidth: CGFloat = 100
    private let minHeight: CGFloat = 24
    private let padding: CGFloat = 4

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    var textOrigin: CGPoint {
        frame.origin
    }

    init(origin: CGPoint, color: NSColor, fontSize: CGFloat, initialText: String = "") {
        self.textColor = color
        self.fontSize = fontSize

        // Create scroll view for text view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Create text view
        textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainerInset = NSSize(width: padding, height: padding)

        // Configure text container for auto-sizing
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Set font and color
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        textView.font = font
        textView.textColor = color
        textView.insertionPointColor = color

        // Transparent background
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        // Initial frame
        let initialFrame = NSRect(x: origin.x, y: origin.y, width: minWidth + padding * 2, height: minHeight + padding * 2)

        super.init(frame: initialFrame)

        // Set up view hierarchy
        scrollView.documentView = textView
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        addSubview(scrollView)

        // Set delegate
        textView.delegate = self

        // Set initial text
        if !initialText.isEmpty {
            textView.string = initialText
            adjustSize()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw dashed border to indicate editing state
        let borderRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(rect: borderRect)
        path.lineWidth = DesignTokens.Border.widthThin
        path.setLineDash([4, 2], count: 2, phase: 0)

        DesignTokens.Colors.editingBorder.setStroke()
        path.stroke()
    }

    // MARK: - First Responder

    func beginEditing() {
        window?.makeFirstResponder(textView)
        // Move cursor to end
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            delegate?.textEditingDidCancel(self)
        } else if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            // Cmd+Enter to confirm
            confirmEditing()
        } else {
            super.keyDown(with: event)
        }
    }

    private func confirmEditing() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            delegate?.textEditingDidConfirm(self, text: text)
        } else {
            delegate?.textEditingDidCancel(self)
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        adjustSize()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            // ESC key
            delegate?.textEditingDidCancel(self)
            return true
        }
        return false
    }

    // MARK: - Size Adjustment

    private func adjustSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Force layout
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)

        // Calculate new size with padding
        let newWidth = max(minWidth, usedRect.width + padding * 2 + 10)
        let newHeight = max(minHeight, usedRect.height + padding * 2)

        // Update frame
        let newFrame = NSRect(x: frame.origin.x, y: frame.origin.y, width: newWidth, height: newHeight)
        frame = newFrame

        // Update text view frame
        textView.frame = NSRect(x: 0, y: 0, width: newWidth, height: newHeight)
        scrollView.frame = bounds

        needsDisplay = true
    }

    // MARK: - Hit Testing

    func containsPoint(_ point: CGPoint) -> Bool {
        frame.contains(point)
    }
}
