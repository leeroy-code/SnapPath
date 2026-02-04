import Cocoa

/// Utility for converting between NS coordinates (bottom-left origin) and CG coordinates (top-left origin)
struct ScreenCoordinateHelper {

    /// Height of the primary screen (used for coordinate flipping)
    static func primaryScreenHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Convert NS point (global) to CG point (global)
    static func nsPointToCG(_ point: NSPoint) -> CGPoint {
        let height = primaryScreenHeight()
        return CGPoint(x: point.x, y: height - point.y)
    }

    /// Convert CG point (global) to NS point (global)
    static func cgPointToNS(_ point: CGPoint) -> NSPoint {
        let height = primaryScreenHeight()
        return NSPoint(x: point.x, y: height - point.y)
    }

    /// Convert NS rect (global) to CG rect (global)
    static func nsRectToCG(_ rect: NSRect) -> CGRect {
        let height = primaryScreenHeight()
        let cgY = height - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: cgY, width: rect.width, height: rect.height)
    }

    /// Convert CG rect (global) to NS rect (global)
    static func cgRectToNS(_ rect: CGRect) -> NSRect {
        let height = primaryScreenHeight()
        let nsY = height - rect.origin.y - rect.height
        return NSRect(x: rect.origin.x, y: nsY, width: rect.width, height: rect.height)
    }

    /// Get the union frame of all screens in NS coordinates
    static func allScreensUnionFrame() -> NSRect {
        NSScreen.screens.reduce(.zero) { $0.union($1.frame) }
    }

    /// Get the union frame of all screens in CG coordinates
    static func allScreensUnionFrameCG() -> CGRect {
        nsRectToCG(allScreensUnionFrame())
    }
}
