import Sparkle
import Foundation

final class UpdateService: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateService()

    private static let fallbackFeedURLString = "https://github.com/leeroy-code/SnapPath/releases/latest/download/appcast.xml"
    
    private var updaterController: SPUStandardUpdaterController!
    
    private override init() {
        super.init()
        // SPUStandardUpdaterController 负责管理更新 UI 和 updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
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
