import Cocoa
import KeyboardShortcuts
import Carbon.HIToolbox

extension KeyboardShortcuts.Name {
    static let captureRegion = Self("captureRegion")
    static let captureFullScreen = Self("captureFullScreen")
    static let captureWindow = Self("captureWindow")
    static let pinRegion = Self("pinRegion")
    static let copyFinderPath = Self("copyFinderPath")
}

enum HotkeyService {
    static func setupHotkeys() {
        // Set default shortcuts on first launch
        if !UserDefaults.standard.bool(forKey: "hotkeysConfigured") {
            KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .shift]), for: .captureRegion)
            KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.command, .shift]), for: .captureFullScreen)
            KeyboardShortcuts.setShortcut(.init(.w, modifiers: [.command, .shift]), for: .captureWindow)
            KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.command, .shift]), for: .pinRegion)
            KeyboardShortcuts.setShortcut(.init(.c, modifiers: [.command, .shift]), for: .copyFinderPath)
            UserDefaults.standard.set(true, forKey: "hotkeysConfigured")
        }

        KeyboardShortcuts.onKeyUp(for: .captureRegion) {
            ScreenCaptureService.shared.captureRegion()
        }

        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) {
            ScreenCaptureService.shared.captureFullScreen()
        }

        KeyboardShortcuts.onKeyUp(for: .captureWindow) {
            ScreenCaptureService.shared.captureWindow()
        }

        KeyboardShortcuts.onKeyUp(for: .pinRegion) {
            ScreenCaptureService.shared.captureAndPin()
        }

        KeyboardShortcuts.onKeyUp(for: .copyFinderPath) {
            FinderService.copySelectedPaths()
        }
    }
}
