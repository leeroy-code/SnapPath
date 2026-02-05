import Cocoa

/// Utility for converting between NS coordinates (bottom-left origin) and CG coordinates (top-left origin)
struct ScreenCoordinateHelper {

    /// Get the union frame of all screens in NS coordinates
    static func allScreensUnionFrame() -> NSRect {
        guard let first = NSScreen.screens.first else { return .zero }
        return NSScreen.screens.dropFirst().reduce(first.frame) { $0.union($1.frame) }
    }

    /// Global top edge in NS coordinates used as the flip baseline for Quartz.
    static func desktopMaxY() -> CGFloat {
        allScreensUnionFrame().maxY
    }

    /// Convert NS point (global) to CG point (global)
    static func nsPointToCG(_ point: NSPoint) -> CGPoint {
        let maxY = desktopMaxY()
        return CGPoint(x: point.x, y: maxY - point.y)
    }

    /// Convert CG point (global) to NS point (global)
    static func cgPointToNS(_ point: CGPoint) -> NSPoint {
        let maxY = desktopMaxY()
        return NSPoint(x: point.x, y: maxY - point.y)
    }

    /// Convert NS rect (global) to CG rect (global)
    static func nsRectToCG(_ rect: NSRect) -> CGRect {
        let maxY = desktopMaxY()
        let cgY = maxY - rect.maxY
        return CGRect(x: rect.origin.x, y: cgY, width: rect.width, height: rect.height)
    }

    /// Convert CG rect (global) to NS rect (global)
    static func cgRectToNS(_ rect: CGRect) -> NSRect {
        let maxY = desktopMaxY()
        let nsY = maxY - rect.maxY
        return NSRect(x: rect.origin.x, y: nsY, width: rect.width, height: rect.height)
    }

    /// Get the union frame of all screens in CG coordinates
    static func allScreensUnionFrameCG() -> CGRect {
        nsRectToCG(allScreensUnionFrame())
    }
}
