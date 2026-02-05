import Cocoa

final class ScreenCaptureService {
    static let shared = ScreenCaptureService()

    private var regionSelectorCoordinator: RegionSelectorCoordinator?
    private var windowSelectorCoordinator: WindowSelectorCoordinator?
    private var editorWindow: EditorWindow?

    private init() {}

    // MARK: - Full Screen Capture

    func captureFullScreen() {
        guard ensurePermission() else { return }

        guard let screen = currentScreen() else { return }

        let cgImage = CGWindowListCreateImage(
            screen.toCGRect(),
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )

        guard let cgImage = cgImage else { return }
        finalize(cgImage, sourceScreen: screen)
    }

    // MARK: - Region Capture

    func captureRegion() {
        guard ensurePermission() else { return }

        let coordinator = RegionSelectorCoordinator()
        regionSelectorCoordinator = coordinator

        coordinator.start { [weak self] image, sourceScreen in
            self?.regionSelectorCoordinator = nil
            self?.showEditor(for: image, on: sourceScreen)
        } onCancel: { [weak self] in
            self?.regionSelectorCoordinator = nil
        }
    }

    // MARK: - Window Capture

    func captureWindow() {
        guard ensurePermission() else { return }

        let coordinator = WindowSelectorCoordinator()
        windowSelectorCoordinator = coordinator

        coordinator.start { [weak self] windowID, sourceScreen in
            self?.windowSelectorCoordinator = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard let cgImage = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowID,
                    [.bestResolution, .boundsIgnoreFraming]
                ) else { return }
                self?.finalize(cgImage, sourceScreen: sourceScreen)
            }
        } onCancel: { [weak self] in
            self?.windowSelectorCoordinator = nil
        }
    }

    // MARK: - Pin Capture

    func captureAndPin() {
        guard ensurePermission() else { return }

        let coordinator = RegionSelectorCoordinator()
        regionSelectorCoordinator = coordinator

        coordinator.start { [weak self] image, sourceScreen in
            self?.regionSelectorCoordinator = nil
            self?.showEditor(for: image, on: sourceScreen)
        } onCancel: { [weak self] in
            self?.regionSelectorCoordinator = nil
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        regionSelectorCoordinator?.cleanup()
        regionSelectorCoordinator = nil
        windowSelectorCoordinator?.cleanup()
        windowSelectorCoordinator = nil
    }

    // MARK: - Private

    private func ensurePermission() -> Bool {
        if PermissionChecker.checkScreenCapturePermission() {
            return true
        }
        PermissionChecker.showPermissionAlert()
        return false
    }

    private func currentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
    }

    private func finalize(_ image: CGImage, sourceScreen: NSScreen? = nil) {
        if AppSettings.shared.showEditorAfterCapture {
            showEditor(for: image, on: sourceScreen)
        } else {
            saveAndNotify(image)
        }
    }

    private func showEditor(for image: CGImage, on sourceScreen: NSScreen?) {
        let editor = EditorWindow(
            image: image,
            sourceScreen: sourceScreen,
            onCopyImage: { [weak self] editedImage in
                self?.editorWindow?.close()
                self?.editorWindow = nil
                ClipboardService.copyImage(editedImage)
                NotificationService.showMessage(title: "pin.imageCopied".localized, body: "")
            },
            onCopyPath: { [weak self] editedImage in
                self?.editorWindow?.close()
                self?.editorWindow = nil
                self?.saveAndNotify(editedImage)
            },
            onCancel: { [weak self] in
                self?.editorWindow?.close()
                self?.editorWindow = nil
            }
        )
        editorWindow = editor
        editor.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func saveAndNotify(_ image: CGImage) {
        do {
            let url = try FileService.saveScreenshot(image)
            let path = url.path
            ClipboardService.copyPath(path)
            NotificationService.showSuccess(path: path)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Screenshot Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}

// MARK: - NSScreen coordinate conversion

extension NSScreen {
    func toCGRect() -> CGRect {
        ScreenCoordinateHelper.nsRectToCG(frame)
    }
}
