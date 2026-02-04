import Foundation
import SwiftUI

class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()

    @Published var isEnabled: Bool {
        didSet {
            // Only perform file operations if the state actually changes from what's on disk
            let currentlyEnabled = checkIsEnabled()
            if isEnabled && !currentlyEnabled {
                enable()
            } else if !isEnabled && currentlyEnabled {
                disable()
            }
        }
    }

    private init() {
        // Initialize default value. Property observers (didSet) are NOT called during initialization.
        self.isEnabled = false
        // Check actual state from disk
        self.isEnabled = checkIsEnabled()
    }

    private var launchAgentURL: URL? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let fileManager = FileManager.default
        // Use ~/Library/LaunchAgents
        guard let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        return libraryURL.appendingPathComponent("LaunchAgents").appendingPathComponent("\(bundleID).plist")
    }

    private func checkIsEnabled() -> Bool {
        guard let url = launchAgentURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func enable() {
        guard let url = launchAgentURL,
              let bundleID = Bundle.main.bundleIdentifier,
              let executablePath = Bundle.main.executablePath else { return }

        // Create the plist dictionary
        let plistContent: [String: Any] = [
            "Label": bundleID,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]

        do {
            let directory = url.deletingLastPathComponent()
            // Ensure ~/Library/LaunchAgents exists
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            // Serialize and write
            let data = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
            try data.write(to: url)
            print("Launch at Login enabled via LaunchAgent: \(url.path)")
        } catch {
            print("Failed to enable Launch at Login: \(error)")
        }
    }

    private func disable() {
        guard let url = launchAgentURL else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("Launch at Login disabled (removed \(url.path))")
            }
        } catch {
            print("Failed to disable Launch at Login: \(error)")
        }
    }
}
