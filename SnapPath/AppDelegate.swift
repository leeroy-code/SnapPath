import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var languageObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        HotkeyService.setupHotkeys()
        NotificationService.requestAuthorization()
        UpdateService.shared.performStartupAutoCheckIfNeeded()

        // Observe language changes to rebuild menu
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildMenu()
            self?.updateSettingsWindowTitle()
        }

        // Check screen capture permission on launch
        if !PermissionChecker.checkScreenCapturePermission() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                PermissionChecker.showPermissionAlert()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScreenCaptureService.shared.cleanup()
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let image = createMenuBarIcon()
            image.isTemplate = true
            button.image = image
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let regionItem = NSMenuItem(title: "menu.regionCapture".localized, action: #selector(captureRegion), keyEquivalent: "")
        regionItem.target = self
        menu.addItem(regionItem)

        let fullScreenItem = NSMenuItem(title: "menu.fullScreenCapture".localized, action: #selector(captureFullScreen), keyEquivalent: "")
        fullScreenItem.target = self
        menu.addItem(fullScreenItem)

        let windowItem = NSMenuItem(title: "menu.windowCapture".localized, action: #selector(captureWindow), keyEquivalent: "")
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(.separator())

        let pinItem = NSMenuItem(title: "menu.pinRegion".localized, action: #selector(pinRegion), keyEquivalent: "")
        pinItem.target = self
        menu.addItem(pinItem)

        menu.addItem(.separator())

        let openFolderItem = NSMenuItem(title: "menu.openFolder".localized, action: #selector(openScreenshotsFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "menu.settings".localized, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "menu.checkForUpdates".localized, action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())
        
        let aboutItem = NSMenuItem(title: "menu.about".localized, action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "menu.quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateSettingsWindowTitle() {
        settingsWindow?.title = "settings.windowTitle".localized
    }

    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let scale = size.width / 24.0
            let path = NSBezierPath()

            // SVG path: M17.5858 5L20.1421 2.44365L21.5563 3.85786L19 6.41421V17H22V19H19V22H17V7H9V5H17.5858Z
            // M15 17V19H6C5.44772 19 5 18.5523 5 18V7H2V5H5V2H7V17H15Z
            // M9 9H15V15H9V9Z

            // First shape - top right L-shape with diagonal
            path.move(to: NSPoint(x: 17.5858 * scale, y: (24 - 5) * scale))
            path.line(to: NSPoint(x: 20.1421 * scale, y: (24 - 2.44365) * scale))
            path.line(to: NSPoint(x: 21.5563 * scale, y: (24 - 3.85786) * scale))
            path.line(to: NSPoint(x: 19 * scale, y: (24 - 6.41421) * scale))
            path.line(to: NSPoint(x: 19 * scale, y: (24 - 17) * scale))
            path.line(to: NSPoint(x: 22 * scale, y: (24 - 17) * scale))
            path.line(to: NSPoint(x: 22 * scale, y: (24 - 19) * scale))
            path.line(to: NSPoint(x: 19 * scale, y: (24 - 19) * scale))
            path.line(to: NSPoint(x: 19 * scale, y: (24 - 22) * scale))
            path.line(to: NSPoint(x: 17 * scale, y: (24 - 22) * scale))
            path.line(to: NSPoint(x: 17 * scale, y: (24 - 7) * scale))
            path.line(to: NSPoint(x: 9 * scale, y: (24 - 7) * scale))
            path.line(to: NSPoint(x: 9 * scale, y: (24 - 5) * scale))
            path.close()

            // Second shape - bottom left L-shape
            path.move(to: NSPoint(x: 15 * scale, y: (24 - 17) * scale))
            path.line(to: NSPoint(x: 15 * scale, y: (24 - 19) * scale))
            path.line(to: NSPoint(x: 6 * scale, y: (24 - 19) * scale))
            path.curve(to: NSPoint(x: 5 * scale, y: (24 - 18) * scale),
                       controlPoint1: NSPoint(x: 5.44772 * scale, y: (24 - 19) * scale),
                       controlPoint2: NSPoint(x: 5 * scale, y: (24 - 18.5523) * scale))
            path.line(to: NSPoint(x: 5 * scale, y: (24 - 7) * scale))
            path.line(to: NSPoint(x: 2 * scale, y: (24 - 7) * scale))
            path.line(to: NSPoint(x: 2 * scale, y: (24 - 5) * scale))
            path.line(to: NSPoint(x: 5 * scale, y: (24 - 5) * scale))
            path.line(to: NSPoint(x: 5 * scale, y: (24 - 2) * scale))
            path.line(to: NSPoint(x: 7 * scale, y: (24 - 2) * scale))
            path.line(to: NSPoint(x: 7 * scale, y: (24 - 17) * scale))
            path.close()

            // Third shape - center square
            path.move(to: NSPoint(x: 9 * scale, y: (24 - 9) * scale))
            path.line(to: NSPoint(x: 15 * scale, y: (24 - 9) * scale))
            path.line(to: NSPoint(x: 15 * scale, y: (24 - 15) * scale))
            path.line(to: NSPoint(x: 9 * scale, y: (24 - 15) * scale))
            path.close()

            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Actions

    @objc private func captureRegion() {
        ScreenCaptureService.shared.captureRegion()
    }

    @objc private func captureFullScreen() {
        ScreenCaptureService.shared.captureFullScreen()
    }

    @objc private func captureWindow() {
        ScreenCaptureService.shared.captureWindow()
    }

    @objc private func pinRegion() {
        ScreenCaptureService.shared.captureAndPin()
    }

    @objc private func openScreenshotsFolder() {
        let path = AppSettings.shared.saveDirectory
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "settings.windowTitle".localized
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "menu.about".localized
        window.styleMask = [.titled, .closable]
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        } else if (notification.object as? NSWindow) === aboutWindow {
            aboutWindow = nil
        }
    }
}

extension AppDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
