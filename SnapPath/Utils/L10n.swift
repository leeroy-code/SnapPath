import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    static var current: AppLanguage {
        get { AppSettings.shared.language }
        set { AppSettings.shared.language = newValue }
    }
}

enum L10n {
    private static var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: AppLanguage.current.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    static func localized(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

extension String {
    var localized: String {
        return L10n.localized(self)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}
