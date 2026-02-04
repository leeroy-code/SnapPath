import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginService.shared
    @State private var refreshID = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Language
                VStack(spacing: 8) {
                    ModernSettingsHeader(
                        title: "settings.language".localized,
                        icon: "globe",
                        color: Color(NSColor.systemBlue)
                    )
                    
                    SettingsGroup {
                        HStack {
                            Text("Language")
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

                // MARK: - Save Location
                VStack(spacing: 8) {
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
                
                // MARK: - General
                VStack(spacing: 8) {
                    ModernSettingsHeader(
                        title: "settings.general".localized,
                        icon: "gearshape.fill",
                        color: Color(NSColor.systemGray)
                    )
                    
                    SettingsGroup {
                        VStack(spacing: 0) {
                            // LaunchAtLogin 使用单独的 Toggle
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
                        }
                    }
                }

                // MARK: - Keyboard Shortcuts
                VStack(spacing: 8) {
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
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
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
                    RoundedRectangle(cornerRadius: 6)
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
            RoundedRectangle(cornerRadius: 10)
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
