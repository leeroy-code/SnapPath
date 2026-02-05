import Cocoa
import ApplicationServices

enum FinderPermissionChecker {
    /// Triggers the macOS Automation (Apple Events) permission prompt when needed.
    /// Returns `noErr` (0) when permission is granted.
    static func requestAutomationPermissionToFinder() -> OSStatus {
        let runCheck = {
            let bundleId = "com.apple.finder"
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            let target: NSAppleEventDescriptor

            if let finder = running.first {
                target = NSAppleEventDescriptor(processIdentifier: finder.processIdentifier)
            } else {
                target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
            }

            #if DEBUG
            let usage = Bundle.main.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") as? String
            print("[SnapPath] AppleEvents usage description:", usage ?? "nil")
            print("[SnapPath] Bundle id:", Bundle.main.bundleIdentifier ?? "nil")
            print("[SnapPath] Bundle path:", Bundle.main.bundlePath)
            print("[SnapPath] Finder running count:", running.count)
            #endif
            return AEDeterminePermissionToAutomateTarget(
                target.aeDesc,
                AEEventClass(kAECoreSuite),
                AEEventID(kAEGetData),
                true
            )
        }

        if Thread.isMainThread {
            NSApp.activate(ignoringOtherApps: true)
            let status = runCheck()
            #if DEBUG
            print("[SnapPath] AEDeterminePermissionToAutomateTarget status:", status)
            #endif
            return status
        }

        return DispatchQueue.main.sync {
            NSApp.activate(ignoringOtherApps: true)
            let status = runCheck()
            #if DEBUG
            print("[SnapPath] AEDeterminePermissionToAutomateTarget status:", status)
            #endif
            return status
        }
    }

    static func openAutomationPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "finderPermission.title".localized
        alert.informativeText = "finderPermission.message".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "finderPermission.openSettings".localized)
        alert.addButton(withTitle: "finderPermission.later".localized)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAutomationPreferences()
        }
    }
}
