import Cocoa

final class PinService {
    static let shared = PinService()

    private var pinnedWindows: [PinWindow] = []

    private init() {}

    func pin(image: CGImage, on screen: NSScreen? = nil) {
        let window = PinWindow(image: image, sourceScreen: screen)
        pinnedWindows.append(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAll() {
        pinnedWindows.forEach { $0.close() }
        pinnedWindows.removeAll()
    }

    func remove(_ window: PinWindow) {
        pinnedWindows.removeAll { $0 === window }
    }
}
