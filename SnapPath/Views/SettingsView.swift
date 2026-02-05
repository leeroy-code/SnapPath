import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginService.shared
    @State private var selection: SettingsTab? = .general

    private enum SettingsTab: Hashable {
        case general
        case saveLocation
        case keyboardShortcuts
        case language

        var title: String {
            switch self {
            case .general:
                return "settings.general".localized
            case .saveLocation:
                return "settings.saveLocation".localized
            case .keyboardShortcuts:
                return "settings.keyboardShortcuts".localized
            case .language:
                return "settings.language".localized
            }
        }

        var systemImage: String {
            switch self {
            case .general:
                return "gearshape.fill"
            case .saveLocation:
                return "folder.fill"
            case .keyboardShortcuts:
                return "command"
            case .language:
                return "globe"
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                sidebarLink(for: .general)
                sidebarLink(for: .saveLocation)
                sidebarLink(for: .keyboardShortcuts)
                sidebarLink(for: .language)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 160, idealWidth: 180, maxWidth: 210)

            SettingsDetailPlaceholderView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 640, minHeight: 480, idealHeight: 520)
        .onAppear {
            if selection == nil { selection = .general }
        }
    }

    private func sidebarLink(for tab: SettingsTab) -> some View {
        NavigationLink(
            destination: detailView(for: tab),
            tag: tab,
            selection: $selection
        ) {
            Label(tab.title, systemImage: tab.systemImage)
        }
    }

    @ViewBuilder
    private func detailView(for tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalView
        case .saveLocation:
            saveLocationView
        case .keyboardShortcuts:
            keyboardShortcutsView
        case .language:
            languageView
        }
    }

    private var generalView: some View {
        SettingsPane {
            ModernSettingsHeader(
                title: "settings.general".localized,
                icon: "gearshape.fill",
                color: Color(NSColor.systemGray)
            )

            SettingsGroup {
                VStack(spacing: 0) {
                    HStack {
                        Text("settings.launchAtLogin".localized)
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $launchAtLogin.isEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.leading, 12)

                    SettingsToggleRow(
                        title: "settings.showEditor".localized,
                        isOn: settings.showEditorAfterCapture
                    ) { settings.showEditorAfterCapture = $0 }

                    Divider()
                        .padding(.leading, 12)

                    SettingsToggleRow(
                        title: "settings.playSoundEffect".localized,
                        isOn: settings.playSoundEffect
                    ) { settings.playSoundEffect = $0 }

                    Divider()
                        .padding(.leading, 12)

                    SettingsToggleRow(
                        title: "settings.showNotification".localized,
                        isOn: settings.showNotification
                    ) { settings.showNotification = $0 }

                    Divider()
                        .padding(.leading, 12)

                    SettingsToggleRow(
                        title: "settings.autoCheckUpdates".localized,
                        isOn: settings.autoCheckUpdates
                    ) { settings.autoCheckUpdates = $0 }
                }
            }
        }
    }

    private var saveLocationView: some View {
        SettingsPane {
            ModernSettingsHeader(
                title: "settings.saveLocation".localized,
                icon: "folder.fill",
                color: Color(NSColor.systemOrange)
            )

            SettingsGroup {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(URL(fileURLWithPath: settings.saveDirectory).lastPathComponent)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(settings.saveDirectory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }

                    Spacer()

                    Button("settings.choose".localized) {
                        chooseSaveDirectory()
                    }

                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.saveDirectory)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(12)
            }
        }
    }

    private var keyboardShortcutsView: some View {
        SettingsPane {
            ModernSettingsHeader(
                title: "settings.keyboardShortcuts".localized,
                icon: "command",
                color: Color(NSColor.systemPurple)
            )

            SettingsGroup {
                VStack(spacing: 0) {
                    shortcutRow(label: "settings.regionCapture".localized, key: .captureRegion)
                    Divider().padding(.leading, 12)
                    shortcutRow(label: "settings.fullScreen".localized, key: .captureFullScreen)
                    Divider().padding(.leading, 12)
                    shortcutRow(label: "settings.windowCapture".localized, key: .captureWindow)
                    Divider().padding(.leading, 12)
                    shortcutRow(label: "settings.pinRegion".localized, key: .pinRegion)
                    Divider().padding(.leading, 12)
                    shortcutRow(label: "settings.copyFinderPath".localized, key: .copyFinderPath)
                }
            }
        }
    }

    private var languageView: some View {
        SettingsPane {
            ModernSettingsHeader(
                title: "settings.language".localized,
                icon: "globe",
                color: Color(NSColor.systemBlue)
            )

            SettingsGroup {
                HStack {
                    Text("settings.language".localized)
                        .font(.body)
                    Spacer()
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
    
    @ViewBuilder
    private func shortcutRow(label: String, key: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            KeyboardShortcuts.Recorder(for: key)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            settings.saveDirectory = url.path
        }
    }
}

// MARK: - Modern UI Components

private struct SettingsPane<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                content
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct SettingsDetailPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.general".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Text("settings.windowTitle".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }
}

struct ModernSettingsHeader: View {
    let title: String
    let icon: String // SF Symbol name
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color)
                )
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct SettingsGroup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
        )
    }
}

struct SettingsToggleRow: View {
    let title: String
    let isOn: Bool
    let action: (Bool) -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { action($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
