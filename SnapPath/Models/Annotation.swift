import Cocoa

// MARK: - Editor Tool

enum EditorTool: CaseIterable {
    case arrow
    case rectangle
    case text
    case crop

    var displayName: String {
        switch self {
        case .arrow: return "tool.arrow".localized
        case .rectangle: return "tool.rectangle".localized
        case .text: return "tool.text".localized
        case .crop: return "tool.crop".localized
        }
    }

    var iconName: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .crop: return "crop"
        }
    }
}

// MARK: - Annotation

enum Annotation {
    case arrow(start: CGPoint, end: CGPoint, color: NSColor, lineWidth: CGFloat)
    case rectangle(rect: CGRect, color: NSColor, lineWidth: CGFloat)
    case text(origin: CGPoint, content: String, color: NSColor, fontSize: CGFloat)

    var color: NSColor {
        switch self {
        case .arrow(_, _, let color, _): return color
        case .rectangle(_, let color, _): return color
        case .text(_, _, let color, _): return color
        }
    }

    /// Returns the bounding rect for text annotations (used for hit testing and re-editing)
    func boundingRect() -> CGRect? {
        switch self {
        case .text(let origin, let content, _, let fontSize):
            let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (content as NSString).size(withAttributes: attributes)
            // Add some padding for easier click detection
            let padding: CGFloat = 4
            return CGRect(
                x: origin.x - padding,
                y: origin.y - padding,
                width: size.width + padding * 2,
                height: size.height + padding * 2
            )
        default:
            return nil
        }
    }

    /// Check if this is a text annotation
    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

// MARK: - Crop Rect

struct CropRect {
    var rect: CGRect

    init(rect: CGRect = .zero) {
        self.rect = rect
    }

    var isEmpty: Bool {
        rect.isEmpty || rect.width < 1 || rect.height < 1
    }
}
