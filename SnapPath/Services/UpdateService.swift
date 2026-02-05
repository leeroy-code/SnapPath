import Sparkle
import Foundation

final class UpdateService: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateService()

    private static let fallbackFeedURLString = "https://github.com/leeroy-code/SnapPath/releases/latest/download/appcast.xml"

    private static let autoUpdateLastCheckDateKey = "autoUpdateLastCheckDate"
    private static let autoUpdateMinimumInterval: TimeInterval = 24 * 60 * 60
    
    private var updaterController: SPUStandardUpdaterController!
    private var autoUpdateSettingObserver: NSObjectProtocol?
    
    private override init() {
        super.init()
        // SPUStandardUpdaterController 负责管理更新 UI 和 updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)

        applyAutoUpdateSetting()
        autoUpdateSettingObserver = NotificationCenter.default.addObserver(
            forName: .autoUpdateSettingDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAutoUpdateSetting()
        }
    }

    deinit {
        if let observer = autoUpdateSettingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func performStartupAutoCheckIfNeeded() {
        applyAutoUpdateSetting()
        guard AppSettings.shared.autoCheckUpdates else { return }

        let now = Date()
        if let lastCheckDate = UserDefaults.standard.object(forKey: Self.autoUpdateLastCheckDateKey) as? Date,
           now.timeIntervalSince(lastCheckDate) < Self.autoUpdateMinimumInterval {
            return
        }

        UserDefaults.standard.set(now, forKey: Self.autoUpdateLastCheckDateKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updaterController.updater.checkForUpdatesInBackground()
        }
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    private func applyAutoUpdateSetting() {
        updaterController.updater.automaticallyChecksForUpdates = AppSettings.shared.autoCheckUpdates
    }
    
    // MARK: - SPUUpdaterDelegate

    func feedURLString(for updater: SPUUpdater) -> String? {
        if let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
           !feedURLString.isEmpty {
            return feedURLString
        }

        return Self.fallbackFeedURLString
    }
    
    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        // 更新检查前的回调，如果需要可以做些逻辑
    }
}
