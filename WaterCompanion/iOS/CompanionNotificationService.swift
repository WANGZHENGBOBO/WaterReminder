import Foundation
import UserNotifications

@MainActor
final class CompanionNotificationService: NSObject {
    static let categoryID = "WATER_REMINDER"
    static let recordActionID = "WATER_RECORD_DEFAULT"
    static let snoozeActionID = "WATER_REMINDER_SNOOZE"
    private static let identifierPrefix = "water.reminder."

    var onQuickRecord: ((Int) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let identifiersKey = "scheduledWaterReminderIdentifiers.v1"
    private var currentServing = CompanionSettings.fallback.serving
    private var currentSnooze = CompanionSettings.fallback.snooze

    override init() {
        super.init()
        center.delegate = self
    }

    func schedule(
        settings: CompanionSettings,
        summary: CompanionTodaySummary?,
        now: Date = Date()
    ) {
        currentServing = settings.serving
        currentSnooze = settings.snooze
        let recordAction = UNNotificationAction(
            identifier: Self.recordActionID,
            title: "记录 \(settings.serving)ml",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "\(settings.snooze) 分钟后",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [recordAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
        center.removePendingNotificationRequests(
            withIdentifiers: defaults.stringArray(forKey: identifiersKey) ?? []
        )

        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            var occurrences = settings.reminderOccurrences(after: now, limit: 48)
            if settings.stopAtGoal, let summary, summary.isCurrentDay(now: now),
               summary.total >= settings.goal {
                occurrences.removeAll { Calendar.current.isDate($0, inSameDayAs: now) }
            }
            var identifiers: [String] = []
            for (index, date) in occurrences.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "该喝水啦"
                content.body = "点一下记录 \(settings.serving)ml"
                content.sound = .default
                content.categoryIdentifier = Self.categoryID
                content.userInfo = ["serving": settings.serving]
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )
                let identifier = "\(Self.identifierPrefix)\(index).\(Int(date.timeIntervalSince1970))"
                try? await center.add(UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                ))
                identifiers.append(identifier)
            }
            defaults.set(identifiers, forKey: identifiersKey)
        }
    }

    func scheduleSnooze(serving: Int, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "该喝水啦"
        content.body = "点一下记录 \(serving)ml"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = ["serving": serving]
        let identifier = "\(Self.identifierPrefix)snooze.\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(max(minutes, 1) * 60),
                repeats: false
            )
        )
        Task { try? await center.add(request) }
        var identifiers = defaults.stringArray(forKey: identifiersKey) ?? []
        identifiers.append(identifier)
        defaults.set(identifiers, forKey: identifiersKey)
    }
}

extension CompanionNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let serving = response.notification.request.content.userInfo["serving"] as? Int
        if action == Self.snoozeActionID {
            Task { @MainActor in
                self.scheduleSnooze(
                    serving: serving ?? self.currentServing,
                    minutes: self.currentSnooze
                )
                completionHandler()
            }
            return
        }
        guard action == UNNotificationDefaultActionIdentifier
            || action == Self.recordActionID else {
            completionHandler()
            return
        }
        Task { @MainActor in
            self.onQuickRecord?(serving ?? self.currentServing)
            completionHandler()
        }
    }
}
