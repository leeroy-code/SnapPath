import Cocoa

enum PermissionChecker {
    static func checkScreenCapturePermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    static func requestScreenCapturePermission() {
        CGRequestScreenCaptureAccess()
    }

    static func openSystemPreferences() {
        let url: URL
        if #available(macOS 13.0, *) {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        } else {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        }
        NSWorkspace.shared.open(url)
    }

    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "permission.title".localized
        alert.informativeText = "permission.message".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "permission.openSettings".localized)
        alert.addButton(withTitle: "permission.later".localized)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemPreferences()
        }
    }
}
