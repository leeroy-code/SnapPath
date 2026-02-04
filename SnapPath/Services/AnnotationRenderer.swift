import Cocoa

final class AnnotationRenderer {

    /// Renders annotations onto the given image and returns a new CGImage
    static func render(annotations: [Annotation], cropRect: CropRect?, onto image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw original image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Flip coordinate system for annotations (annotations use top-left origin)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Draw each annotation
        for annotation in annotations {
            draw(annotation: annotation, in: context)
        }

        // Reset transform for cropping
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        guard let resultImage = context.makeImage() else { return nil }

        // Apply crop if needed
        if let crop = cropRect, !crop.isEmpty {
            // Convert crop rect to CGImage coordinates (flip Y)
            let flippedY = CGFloat(height) - crop.rect.origin.y - crop.rect.height
            let cropCGRect = CGRect(
                x: crop.rect.origin.x,
                y: flippedY,
                width: crop.rect.width,
                height: crop.rect.height
            )
            return resultImage.cropping(to: cropCGRect)
        }

        return resultImage
    }

    private static func draw(annotation: Annotation, in context: CGContext) {
        switch annotation {
        case .arrow(let start, let end, let color, let lineWidth):
            drawArrow(from: start, to: end, color: color, lineWidth: lineWidth, in: context)

        case .rectangle(let rect, let color, let lineWidth):
            drawRectangle(rect: rect, color: color, lineWidth: lineWidth, in: context)

        case .text(let origin, let content, let color, let fontSize):
            drawText(at: origin, text: content, color: color, fontSize: fontSize, in: context)
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: CGFloat, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Draw main line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Draw arrowhead
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

    private static func drawRectangle(rect: CGRect, color: NSColor, lineWidth: CGFloat, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.addRect(rect)
        context.strokePath()
    }

    private static func drawText(at origin: CGPoint, text: String, color: NSColor, fontSize: CGFloat, in context: CGContext) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        // Text needs to be flipped again since we already flipped the context
        context.translateBy(x: origin.x, y: origin.y + fontSize)
        context.scaleBy(x: 1, y: -1)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
