import Cocoa

final class PinWindow: NSWindow {
    private let cgImage: CGImage
    private var imageView: NSImageView!
    private var currentScale: CGFloat = 1.0
    private var savedPath: String?
    private var isClosing = false

    private let minScale: CGFloat = 0.25
    private let maxScale: CGFloat = 4.0

    init(image: CGImage, sourceScreen: NSScreen? = nil) {
        self.cgImage = image

        // Use source screen if available, otherwise fall back to main screen
        let screen = sourceScreen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let scaleFactor = screen?.backingScaleFactor ?? 2.0

        // Calculate size in points (handling Retina)
        let imageSizePoints = NSSize(
            width: CGFloat(image.width) / scaleFactor,
            height: CGFloat(image.height) / scaleFactor
        )
        
        var displaySize = imageSizePoints
        
        // Only scale down if it exceeds the screen size significantly
        // User requested "Like Edit window size" which is 1:1
        let maxWidth = screenFrame.width
        let maxHeight = screenFrame.height

        if displaySize.width > maxWidth || displaySize.height > maxHeight {
            let widthRatio = maxWidth / displaySize.width
            let heightRatio = maxHeight / displaySize.height
            let ratio = min(widthRatio, heightRatio)
            displaySize = NSSize(width: displaySize.width * ratio, height: displaySize.height * ratio)
            currentScale = ratio
        }

        // Center on the source screen
        let origin = NSPoint(
            x: screenFrame.midX - displaySize.width / 2,
            y: screenFrame.midY - displaySize.height / 2
        )

        let contentRect = NSRect(origin: origin, size: displaySize)

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = true

        setupUI(imageSize: imageSizePoints, displaySize: displaySize)
        setupContextMenu()
        
        // Lock aspect ratio for manual resizing
        self.contentAspectRatio = imageSizePoints
        
        // Prevent system from releasing the window automatically. 
        // We manage the lifecycle via PinService array.
        self.isReleasedWhenClosed = false
        
        // Set minimum size to prevent window from becoming too small
        self.minSize = NSSize(width: 100, height: 100)
    }

    private func setupUI(imageSize: NSSize, displaySize: NSSize) {
        let containerView = NSView(frame: NSRect(origin: .zero, size: displaySize))
        containerView.wantsLayer = true
        self.contentView = containerView

        let nsImage = NSImage(cgImage: cgImage, size: imageSize)

        // Create image view
        imageView = NSImageView(frame: NSRect(origin: .zero, size: displaySize))
        imageView.image = nsImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = DesignTokens.Border.radiusMedium
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Lower priorities so the window frame can drive the layout during manual resize.
        // Otherwise, it might 'jump' to the original image size on the first resize event.
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        containerView.addSubview(imageView)

        // Create Pin Icon (WeChat Style - Interactive)
        let pinButton = NSButton()
        pinButton.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Close Pinned Image")
        pinButton.contentTintColor = NSColor.systemGreen
        pinButton.bezelStyle = .shadowlessSquare
        pinButton.isBordered = false
        pinButton.setButtonType(.momentaryChange)
        pinButton.target = self
        pinButton.action = #selector(closeWindow)
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure symbol size
        if let image = pinButton.image {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            pinButton.image = image.withSymbolConfiguration(config)
        }
        
        // Add subtle shadow to button for visibility
        pinButton.wantsLayer = true
        pinButton.shadow = NSShadow()
        pinButton.shadow?.shadowOffset = NSSize(width: 0, height: -1)
        pinButton.shadow?.shadowBlurRadius = 2
        pinButton.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.3)
        
        containerView.addSubview(pinButton)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            pinButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            pinButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            pinButton.widthAnchor.constraint(equalToConstant: 24),
            pinButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Enhanced shadow for floating window
        self.hasShadow = true
        containerView.shadow = DesignTokens.Shadow.floating()
    }

    private func setupContextMenu() {
        let menu = NSMenu()

        let copyImageItem = NSMenuItem(title: "pin.copyImage".localized, action: #selector(copyImage), keyEquivalent: "")
        copyImageItem.target = self
        menu.addItem(copyImageItem)

        let saveAndCopyItem = NSMenuItem(title: "pin.saveAndCopyPath".localized, action: #selector(saveAndCopyPath), keyEquivalent: "")
        saveAndCopyItem.target = self
        menu.addItem(saveAndCopyItem)

        menu.addItem(.separator())

        // Opacity submenu
        let opacityMenu = NSMenu()
        for opacity in [100, 75, 50, 25] {
            let item = NSMenuItem(title: "\(opacity)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.tag = opacity
            opacityMenu.addItem(item)
        }
        let opacityItem = NSMenuItem(title: "pin.opacity".localized, action: nil, keyEquivalent: "")
        opacityItem.submenu = opacityMenu
        menu.addItem(opacityItem)

        menu.addItem(.separator())

        let closeItem = NSMenuItem(title: "pin.close".localized, action: #selector(closeWindow), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        self.contentView?.menu = menu
    }

    // MARK: - Actions

    @objc private func copyImage() {
        ClipboardService.copyImage(cgImage)
        NotificationService.showSuccess(path: "pin.imageCopied".localized)
    }

    @objc private func saveAndCopyPath() {
        if let path = savedPath {
            ClipboardService.copyPath(path)
            NotificationService.showSuccess(path: path)
        } else {
            do {
                let url = try FileService.saveScreenshot(cgImage)
                savedPath = url.path
                ClipboardService.copyPath(url.path)
                NotificationService.showSuccess(path: url.path)
            } catch {
                let alert = NSAlert()
                alert.messageText = "pin.saveFailed".localized
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        let opacity = CGFloat(sender.tag) / 100.0
        self.alphaValue = opacity
    }

    @objc private func closeWindow() {
        guard !isClosing else { return }
        isClosing = true
        
        // Order is important: close the window first, then let PinService remove the reference.
        // During self.close(), the window is still in the array, keeping 'self' alive.
        self.close()
        PinService.shared.remove(self)
    }

    // MARK: - Event Handling

    override func scrollWheel(with event: NSEvent) {
        let delta = event.deltaY
        let scaleFactor: CGFloat = 1.0 + (delta * 0.05)
        let newScale = currentScale * scaleFactor

        guard newScale >= minScale && newScale <= maxScale else { return }

        currentScale = newScale

        let originalSize = NSSize(width: cgImage.width, height: cgImage.height)
        let newSize = NSSize(
            width: originalSize.width * currentScale,
            height: originalSize.height * currentScale
        )

        // Keep center position
        let currentCenter = NSPoint(
            x: self.frame.midX,
            y: self.frame.midY
        )

        let newOrigin = NSPoint(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2
        )

        self.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc key
            closeWindow()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            closeWindow()
        } else {
            super.mouseDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
