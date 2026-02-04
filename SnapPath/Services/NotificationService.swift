import Cocoa
import UserNotifications

enum NotificationService {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func showSuccess(path: String) {
        showMessage(title: "notification.screenshotSaved".localized, body: path)
    }

    static func showMessage(title: String, body: String) {
        let settings = AppSettings.shared

        if settings.playSoundEffect {
            NSSound(named: .init("Tink"))?.play()
        }

        guard settings.showNotification else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
