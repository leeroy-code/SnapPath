import Cocoa

protocol EditorToolbarViewDelegate: AnyObject {
    func toolbarDidSelectTool(_ tool: EditorTool?)
    func toolbarDidSelectColor(_ color: NSColor)
    func toolbarDidChangeFontSize(_ size: CGFloat)
    func toolbarDidTapUndo()
    func toolbarDidTapCancel()
    func toolbarDidTapCopyImage()
    func toolbarDidTapCopyPath()
    func toolbarDidTapPin()
    func toolbarDidTapOCR()
}

final class EditorToolbarView: NSView {

    weak var delegate: EditorToolbarViewDelegate?

    private var selectedTool: EditorTool? = .arrow
    private var toolButtons: [EditorTool: NSButton] = [:]
    private var colorWell: NSColorWell!
    private var fontSizePopup: NSPopUpButton!
    private var undoButton: NSButton!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = DesignTokens.Border.radiusMedium
        layer?.shadowColor = DesignTokens.Shadow.floating().shadowColor?.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 8
        
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = DesignTokens.Spacing.s
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: DesignTokens.Spacing.m, bottom: 0, right: DesignTokens.Spacing.m)
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // --- Tools Group ---
        for tool in EditorTool.allCases {
            let tooltip = tool.displayName
            let tag = EditorTool.allCases.firstIndex(of: tool)!
            
            let button: NSButton
            if tool == .text {
                button = createTextToolButton(
                    title: "T",
                    tooltip: tooltip,
                    tag: tag,
                    action: #selector(toolButtonTapped(_:))
                )
            } else {
                button = createToolButton(
                    iconName: tool.iconName,
                    tooltip: tooltip,
                    tag: tag,
                    action: #selector(toolButtonTapped(_:))
                )
            }
            button.setButtonType(.toggle)
            if tool == .arrow {
                button.state = .on
                button.contentTintColor = DesignTokens.Colors.hoverBorder
            }
            toolButtons[tool] = button
            stackView.addArrangedSubview(button)
        }

        stackView.addArrangedSubview(createSeparator())

        // --- Settings Group ---
        colorWell = NSColorWell()
        colorWell.color = DesignTokens.Colors.annotationDefault
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        let cwWidth = colorWell.widthAnchor.constraint(equalToConstant: 20)
        cwWidth.priority = NSLayoutConstraint.Priority(999)
        cwWidth.isActive = true
        
        let cwHeight = colorWell.heightAnchor.constraint(equalToConstant: 20)
        cwHeight.priority = NSLayoutConstraint.Priority(999)
        cwHeight.isActive = true
        colorWell.toolTip = "toolbar.annotationColor".localized
        // Circular color well
        colorWell.wantsLayer = true
        colorWell.layer?.cornerRadius = 10
        colorWell.layer?.masksToBounds = true
        stackView.addArrangedSubview(colorWell)

        fontSizePopup = NSPopUpButton()
        fontSizePopup.addItems(withTitles: ["12", "16", "24", "36", "48"])
        fontSizePopup.selectItem(withTitle: "24")
        fontSizePopup.target = self
        fontSizePopup.action = #selector(fontSizeChanged(_:))
        fontSizePopup.toolTip = "toolbar.fontSize".localized
        fontSizePopup.font = DesignTokens.Typography.captionMono()
        fontSizePopup.bezelStyle = .recessed
        let fsWidth = fontSizePopup.widthAnchor.constraint(equalToConstant: 44)
        fsWidth.priority = NSLayoutConstraint.Priority(999)
        fsWidth.isActive = true
        stackView.addArrangedSubview(fontSizePopup)

        stackView.addArrangedSubview(createSeparator())

        // --- Actions Group ---
        undoButton = createToolButton(
            iconName: "arrow.uturn.backward",
            tooltip: "toolbar.undo".localized,
            tag: -1,
            action: #selector(undoTapped(_:))
        )
        undoButton.keyEquivalent = "z"
        undoButton.keyEquivalentModifierMask = .command
        stackView.addArrangedSubview(undoButton)
        
        stackView.addArrangedSubview(createSeparator())

        let pinButton = createToolButton(
            iconName: "pin",
            tooltip: "toolbar.pinToScreen".localized,
            tag: -1,
            action: #selector(pinTapped(_:))
        )
        stackView.addArrangedSubview(pinButton)

        let ocrButton = createToolButton(
            iconName: "text.viewfinder",
            tooltip: "toolbar.ocr".localized,
            tag: -1,
            action: #selector(ocrTapped(_:))
        )
        stackView.addArrangedSubview(ocrButton)

        let copyPathButton = createToolButton(
            iconName: "link",
            tooltip: "toolbar.copyPath".localized,
            tag: -1,
            action: #selector(copyPathTapped(_:))
        )
        copyPathButton.keyEquivalent = "s"
        copyPathButton.keyEquivalentModifierMask = .command
        stackView.addArrangedSubview(copyPathButton)
        
        let cancelButton = createToolButton(
            iconName: "xmark",
            tooltip: "toolbar.cancel".localized,
            tag: -1,
            action: #selector(cancelTapped(_:))
        )
        cancelButton.keyEquivalent = "\u{1b}"
        // Add Cmd+W as alternative
        let closeButton = NSButton(title: "", target: self, action: #selector(cancelTapped(_:)))
        closeButton.keyEquivalent = "w"
        closeButton.keyEquivalentModifierMask = .command
        closeButton.isTransparent = true
        closeButton.isBordered = false
        addSubview(closeButton)

        stackView.addArrangedSubview(cancelButton)

        // Done (Checkmark)
        let doneButton = createToolButton(
            iconName: "checkmark",
            tooltip: "toolbar.copyImage".localized,
            tag: -1,
            action: #selector(copyImageTapped(_:))
        )
        doneButton.contentTintColor = NSColor.systemGreen
        doneButton.keyEquivalent = "\r"
        
        // Add Cmd+C as alternative
        let hiddenCopyButton = NSButton(title: "", target: self, action: #selector(copyImageTapped(_:)))
        hiddenCopyButton.keyEquivalent = "c"
        hiddenCopyButton.keyEquivalentModifierMask = .command
        hiddenCopyButton.isTransparent = true
        hiddenCopyButton.isBordered = false
        addSubview(hiddenCopyButton)

        stackView.addArrangedSubview(doneButton)
    }

    // MARK: - Button Factory Methods

    private func createToolButton(iconName: String, tooltip: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton()
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip)
        button.image = image
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(tooltip)
        button.target = self
        button.action = action
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.tag = tag
        button.toolTip = tooltip
        
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: 32)
        widthConstraint.priority = NSLayoutConstraint.Priority(999)
        widthConstraint.isActive = true
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 32)
        heightConstraint.priority = NSLayoutConstraint.Priority(999)
        heightConstraint.isActive = true
        
        return button
    }

    private func createTextToolButton(title: String, tooltip: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.tag = tag
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        button.alignment = .center
        button.font = DesignTokens.Typography.bodyMedium()
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: 32)
        widthConstraint.priority = NSLayoutConstraint.Priority(999)
        widthConstraint.isActive = true
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 32)
        heightConstraint.priority = NSLayoutConstraint.Priority(999)
        heightConstraint.isActive = true
        return button
    }

    private func createSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        let widthConstraint = separator.widthAnchor.constraint(equalToConstant: 1)
        widthConstraint.priority = NSLayoutConstraint.Priority(999)
        widthConstraint.isActive = true
        
        let heightConstraint = separator.heightAnchor.constraint(equalToConstant: 16)
        heightConstraint.priority = NSLayoutConstraint.Priority(999)
        heightConstraint.isActive = true
        return separator
    }

    // MARK: - Actions

    @objc private func toolButtonTapped(_ sender: NSButton) {
        let tool = EditorTool.allCases[sender.tag]

        if selectedTool == tool {
            selectedTool = nil
            sender.state = .off
            sender.contentTintColor = nil
        } else {
            selectedTool = tool
            for (t, button) in toolButtons {
                if t == tool {
                    button.state = .on
                    button.contentTintColor = DesignTokens.Colors.hoverBorder
                } else {
                    button.state = .off
                    button.contentTintColor = nil
                }
            }
        }

        delegate?.toolbarDidSelectTool(selectedTool)
    }

    func selectTool(_ tool: EditorTool) {
        selectedTool = tool
        for (t, button) in toolButtons {
            if t == tool {
                button.state = .on
                button.contentTintColor = DesignTokens.Colors.hoverBorder
            } else {
                button.state = .off
                button.contentTintColor = nil
            }
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        delegate?.toolbarDidSelectColor(sender.color)
    }

    @objc private func fontSizeChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        if let size = Double(title) {
            delegate?.toolbarDidChangeFontSize(CGFloat(size))
        }
    }

    @objc private func undoTapped(_ sender: NSButton) {
        delegate?.toolbarDidTapUndo()
    }

    @objc private func cancelTapped(_ sender: NSButton) {
        delegate?.toolbarDidTapCancel()
    }

    @objc private func copyImageTapped(_ sender: NSButton) {
        delegate?.toolbarDidTapCopyImage()
    }

    @objc private func copyPathTapped(_ sender: NSButton) {
        delegate?.toolbarDidTapCopyPath()
    }

    @objc private func pinTapped(_ sender: NSButton) {
        delegate?.toolbarDidTapPin()
    }

    @objc private func ocrTapped(_ sender: NSButton) {
        delegate?.toolbarDidTapOCR()
    }

    func setUndoEnabled(_ enabled: Bool) {
        undoButton.isEnabled = enabled
    }
}
