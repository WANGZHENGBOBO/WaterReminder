import AppKit
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var authorized = false
    @Published var checked = false
    var onDrink: ((String) -> Void)?
    var onSnooze: (() -> Void)?
    var onError: ((String) -> Void)?
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        let drink = UNNotificationAction(identifier: "drink", title: "已喝水", options: [])
        let snooze = UNNotificationAction(identifier: "snooze", title: "稍后提醒", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: "water", actions: [drink, snooze], intentIdentifiers: [], options: [])])
        refresh()
    }

    func refresh() {
        center.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorized = settings.authorizationStatus == .authorized
                self.checked = true
            }
        }
    }

    func request() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            Task { @MainActor in
                if let error { self.onError?("通知授权失败：\(error.localizedDescription)") }
                self.refresh()
            }
        }
    }

    func send(serving: Int, total: Int, goal: Int, test: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = test ? "喝水BO～ · 测试通知" : "休息一下，喝口水"
        content.body = "喝一杯 \(serving)ml 的水吧。今天已喝 \(total) / \(goal)ml。"
        content.categoryIdentifier = test ? "" : "water"
        content.sound = .default
        clear()
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { error in
            if let error { Task { @MainActor in self.onError?("通知发送失败：\(error.localizedDescription)") } }
        }
    }

    func clear() { center.removeAllDeliveredNotifications() }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            switch response.actionIdentifier {
            case "drink": self.onDrink?(response.notification.request.identifier)
            case "snooze": self.onSnooze?()
            default: break
            }
            completionHandler()
        }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
