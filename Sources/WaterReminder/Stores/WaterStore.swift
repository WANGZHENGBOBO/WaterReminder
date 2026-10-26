import AppKit
import Combine
import WaterCore

struct DrinkFeedback {
    let id = UUID()
    let milestone: Int?
}

@MainActor
final class WaterStore: ObservableObject {
    @Published private(set) var state = SavedState()
    @Published var now = Date()
    @Published var error: String?
    @Published var nextReminder: Date?
    @Published var notice: String?
    @Published private(set) var feedback: DrinkFeedback?
    let notifications = NotificationService()
    private var timer: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var lastTick = Date()
    private var snoozedUntil: Date?
    private var file: URL
    private var storageReadable = true

    init() {
        file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bobo.WaterReminder/state.json")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let restored = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: file))
                guard restored.preferences.isValid,
                      restored.drinks.allSatisfy({ (1...2000).contains($0.grams) }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                state = restored
            }
        } catch {
            storageReadable = false
            self.error = "无法读取已有数据，已停止写入以保护原文件。\(error.localizedDescription)"
        }
        notifications.onDrink = { [weak self] id in self?.addDrink(notificationID: id) }
        notifications.onSnooze = { [weak self] in self?.snooze() }
        notifications.onError = { [weak self] in self?.error = $0 }
        reschedule()
        timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date(); self?.lastTick = Date(); self?.snoozedUntil = nil
                self?.notifications.clear(); self?.reschedule()
            }
        })
    }

    var preferences: Preferences { state.preferences }
    var todayDrinks: [Drink] { state.drinks.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }.sorted { $0.date > $1.date } }
    var total: Int { state.total(on: now) }
    var progress: Double { Double(total) / Double(preferences.goal) }
    var paused: Bool { state.pausedDay.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false }
    var completed: Bool { total >= preferences.goal }
    var status: String {
        if paused { return "今日提醒已暂停" }
        if completed && preferences.stopAtGoal { return "今日目标已完成" }
        if let nextReminder { return "下次提醒 \(nextReminder.formatted(.dateTime.month().day().hour().minute()))" }
        return "提醒已关闭"
    }

    private func save(_ changed: SavedState) -> Bool {
        guard storageReadable else { return false }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(changed).write(to: file, options: .atomic)
            state = changed
            return true
        } catch {
            self.error = "保存失败，本次更改未生效：\(error.localizedDescription)"
            return false
        }
    }

    func addDrink(notificationID: String? = nil) {
        now = Date()
        if let notificationID, state.handledNotifications.contains(notificationID) { return }
        let previousTotal = total
        var changed = state
        changed.drinks.append(Drink(grams: preferences.serving))
        let day = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let dayKey = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        let storedCelebrations = changed.celebratedMilestones?[dayKey] ?? []
        let celebrated = Milestones.retained(storedCelebrations, at: previousTotal, goal: preferences.goal)
        let crossed = Milestones.crossed(from: previousTotal, to: previousTotal + preferences.serving,
                                         goal: preferences.goal, alreadyCelebrated: celebrated)
        if !crossed.isEmpty || celebrated != storedCelebrations {
            var history = changed.celebratedMilestones ?? [:]
            history[dayKey] = Array(Set(celebrated).union(crossed)).sorted()
            changed.celebratedMilestones = history
        }
        if let notificationID {
            changed.handledNotifications.append(notificationID)
            changed.handledNotifications = Array(changed.handledNotifications.suffix(100))
        }
        guard save(changed) else { return }
        let milestone = crossed.max()
        feedback = DrinkFeedback(milestone: milestone)
        switch milestone {
        case 100: notice = "今日目标达成，喝水BO～！🎉"
        case 80: notice = "已经 80% 啦，快到目标了！"
        case 60: notice = "达到 60%，继续保持！"
        default: notice = "已记录 \(preferences.serving)ml"
        }
        snoozedUntil = nil
        notifications.clear()
        reschedule()
    }

    func remove(_ drink: Drink) {
        now = Date()
        var changed = state
        changed.drinks.removeAll { $0.id == drink.id }
        let day = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let dayKey = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        if let celebrated = changed.celebratedMilestones?[dayKey] {
            let remainingTotal = changed.total(on: now)
            changed.celebratedMilestones?[dayKey] = Milestones.retained(
                celebrated, at: remainingTotal, goal: preferences.goal)
        }
        if save(changed) { notice = "已撤销本次记录"; reschedule() }
    }

    func update(_ preferences: Preferences) -> Bool {
        guard preferences.isValid else { error = "请检查数值；开始时间必须早于结束时间。"; return false }
        var changed = state
        changed.preferences = preferences
        guard save(changed) else { return false }
        snoozedUntil = nil
        notifications.clear()
        reschedule()
        return true
    }

    func togglePause() {
        now = Date()
        var changed = state
        changed.pausedDay = paused ? nil : now
        if save(changed) { snoozedUntil = nil; notifications.clear(); reschedule() }
    }

    func snooze() {
        now = Date()
        let candidate = now.addingTimeInterval(Double(preferences.snooze) * 60)
        guard !paused, !(completed && preferences.stopAtGoal),
              ReminderSchedule.canSnooze(to: candidate, from: now, preferences: preferences) else {
            notice = "当前无法稍后提醒：已暂停、已达标或超出生效时段"
            return
        }
        snoozedUntil = candidate
        notifications.clear()
        notice = "将在 \(preferences.snooze) 分钟后提醒"
        reschedule()
    }

    private func reschedule() {
        nextReminder = snoozedUntil ?? ReminderSchedule.next(after: now, preferences: preferences,
            pausedDay: state.pausedDay, completedDay: completed && preferences.stopAtGoal ? now : nil)
    }

    private func tick() {
        let previous = now
        now = Date()
        defer { lastTick = now }
        if !Calendar.current.isDate(previous, inSameDayAs: now) || now.timeIntervalSince(lastTick) > 60 || now < lastTick {
            snoozedUntil = nil; notice = nil; notifications.clear(); reschedule(); return
        }
        if let due = nextReminder, now >= due {
            notifications.send(serving: preferences.serving, total: total, goal: preferences.goal)
            snoozedUntil = nil
            reschedule()
        }
    }
}
