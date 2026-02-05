import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var saveDirectory: String {
        didSet { UserDefaults.standard.set(saveDirectory, forKey: "saveDirectory") }
    }

    @Published var autoCheckUpdates: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckUpdates, forKey: "autoCheckUpdates")
            NotificationCenter.default.post(name: .autoUpdateSettingDidChange, object: nil)
        }
    }

    @Published var playSoundEffect: Bool {
        didSet { UserDefaults.standard.set(playSoundEffect, forKey: "playSoundEffect") }
    }

    @Published var showNotification: Bool {
        didSet { UserDefaults.standard.set(showNotification, forKey: "showNotification") }
    }

    @Published var showEditorAfterCapture: Bool {
        didSet { UserDefaults.standard.set(showEditorAfterCapture, forKey: "showEditorAfterCapture") }
    }

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    private init() {
        let defaultDownloads = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first
            ?? NSHomeDirectory() + "/Downloads"

        self.saveDirectory = UserDefaults.standard.string(forKey: "saveDirectory") ?? defaultDownloads
        self.autoCheckUpdates = UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true
        self.playSoundEffect = UserDefaults.standard.object(forKey: "playSoundEffect") as? Bool ?? true
        self.showNotification = UserDefaults.standard.object(forKey: "showNotification") as? Bool ?? true
        self.showEditorAfterCapture = UserDefaults.standard.object(forKey: "showEditorAfterCapture") as? Bool ?? true

        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: savedLanguage) {
            self.language = lang
        } else {
            self.language = .english
        }
    }
}
