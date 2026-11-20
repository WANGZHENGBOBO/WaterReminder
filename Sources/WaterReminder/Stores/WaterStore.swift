import AppKit
import Combine
import Network
import WaterCore

struct DrinkFeedback: Equatable {
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
    @Published private(set) var syncStatus: DrinkSyncReadiness = .disabled
    @Published private(set) var lanSyncEndpoint: LanEndpoint?
    @Published private(set) var lanSyncError: String?
    @Published private(set) var lanShortName = "M1"
    let notifications = NotificationService()
    private var timer: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var lastTick = Date()
    private var snoozedUntil: Date?
    private var file: URL
    private var storageReadable = true
    private let drinkSync: ICloudDrinkSync
    private var sharedCSVMigrated: Bool
    private let sharedCSVMigrationKey = "sharedDrinkCSVMigration.v1"
    private let lanIdentity = LanLocalIdentity.live()
    private var lanServer: LanDrinkServer?
    private var lanPort: UInt16?
    private var lanToken: String?
    private var lanPathMonitor: NWPathMonitor?
    private let lanMonitorQueue = DispatchQueue(label: "com.bobo.WaterReminder.lan-path")
    private var lastDeviceSignature: String?
    private var lastDevicePublishedAt: Date?
    private var lanServerStartBlocked = false

    init(drinkSync: ICloudDrinkSync = .live()) {
        self.drinkSync = drinkSync
        sharedCSVMigrated = UserDefaults.standard.bool(forKey: sharedCSVMigrationKey)
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
        lanShortName = state.preferences.lanShortName ?? "M1"
        synchronizeDrinks()
        reconcileMilestones()
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
                self?.notifications.clear(); self?.reschedule(); self?.synchronizeDrinks()
            }
        })
        startLanPathMonitor()
    }

    var preferences: Preferences { state.preferences }
    var lanDeviceName: String { lanIdentity.deviceName }
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

    func addDrink(amount: Int? = nil, notificationID: String? = nil) {
        now = Date()
        if let notificationID, state.handledNotifications.contains(notificationID) { return }
        let milliliters = amount ?? preferences.serving
        guard (1...2000).contains(milliliters) else {
            error = "饮水量需在 1–2000ml 之间"
            return
        }
        let previousTotal = total
        var changed = state
        let shortName = resolvedShortName()
        let drink = Drink(
            date: now, grams: milliliters, source: .mac,
            deviceID: lanIdentity.deviceID, deviceName: lanIdentity.deviceName,
            deviceShortName: shortName
        )
        changed.drinks.append(drink)
        let dayKey = self.dayKey(for: now)
        let storedCelebrations = changed.celebratedMilestones?[dayKey] ?? []
        let update = Milestones.update(
            celebrated: storedCelebrations,
            from: previousTotal,
            to: previousTotal + milliliters,
            goal: preferences.goal
        )
        if update.celebrated != storedCelebrations {
            var history = changed.celebratedMilestones ?? [:]
            history[dayKey] = update.celebrated
            changed.celebratedMilestones = history
        }
        if let notificationID {
            changed.handledNotifications.append(notificationID)
            changed.handledNotifications = Array(changed.handledNotifications.suffix(100))
        }
        guard save(changed) else { return }
        queue(try? DrinkSyncEvent(
            kind: .drink, recordID: drink.id.uuidString, timestamp: drink.date,
            milliliters: drink.grams, source: "mac", deviceID: lanIdentity.deviceID,
            deviceName: lanIdentity.deviceName, deviceShortName: shortName
        ))
        if let milestone = update.triggered {
            showMilestone(milestone)
        } else {
            notice = "已记录 \(milliliters)ml"
        }
        snoozedUntil = nil
        notifications.clear()
        reschedule()
    }

    func consumeCelebration(_ id: UUID) {
        guard feedback?.id == id else { return }
        feedback = nil
    }

    private func showMilestone(_ milestone: Int) {
        feedback = DrinkFeedback(milestone: milestone)
        switch milestone {
        case 100: notice = "今日目标达成，喝水BO～！🎉"
        case 80: notice = "已经 80% 啦，快到目标了！"
        case 60: notice = "达到 60%，继续保持！"
        default: break
        }
    }

    private func reconcileMilestones() {
        let dayKey = self.dayKey(for: now)
        let storedCelebrations = state.celebratedMilestones?[dayKey] ?? []
        let update = Milestones.reconcile(
            celebrated: storedCelebrations,
            total: total,
            goal: preferences.goal
        )
        guard update.celebrated != storedCelebrations else { return }
        var changed = state
        var history = changed.celebratedMilestones ?? [:]
        history[dayKey] = update.celebrated
        changed.celebratedMilestones = history
        guard save(changed) else { return }
        if let milestone = update.triggered,
           milestone > (feedback?.milestone ?? 0) {
            showMilestone(milestone)
        }
    }

    func remove(_ drink: Drink) {
        now = Date()
        var changed = state
        changed.drinks.removeAll { $0.id == drink.id }
        let dayKey = self.dayKey(for: now)
        if let celebrated = changed.celebratedMilestones?[dayKey] {
            let remainingTotal = changed.total(on: now)
            changed.celebratedMilestones?[dayKey] = Milestones.retained(
                celebrated, at: remainingTotal, goal: preferences.goal)
        }
        if save(changed) {
            queue(try? DrinkSyncEvent(
                kind: .delete, recordID: drink.id.uuidString, timestamp: now,
                milliliters: nil, source: "mac", deviceID: lanIdentity.deviceID,
                deviceName: lanIdentity.deviceName, deviceShortName: resolvedShortName()
            ))
            notice = "已撤销本次记录"; reschedule()
        }
    }

    func update(_ preferences: Preferences) -> Bool {
        guard preferences.isValid else { error = "请检查数值；开始时间必须早于结束时间。"; return false }
        if let shortName = preferences.lanShortName,
           !isShortNameAvailable(shortName) {
            error = "设备后缀已被其他电脑使用"
            return false
        }
        var changed = state
        changed.preferences = preferences
        guard save(changed) else { return false }
        synchronizeDrinks()
        reconcileMilestones()
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
        defer { lastTick = now; synchronizeDrinks() }
        if !Calendar.current.isDate(previous, inSameDayAs: now) || now.timeIntervalSince(lastTick) > 60 || now < lastTick {
            snoozedUntil = nil; notice = nil; notifications.clear(); reschedule(); return
        }
        if let due = nextReminder, now >= due {
            notifications.send(serving: preferences.serving, total: total, goal: preferences.goal)
            snoozedUntil = nil
            reschedule()
        }
    }

    private var syncEnabled: Bool { state.preferences.iCloudSyncEnabled ?? false }

    func setICloudSyncEnabled(_ enabled: Bool) -> Bool {
        var changed = state
        changed.preferences.iCloudSyncEnabled = enabled
        guard save(changed) else { return false }
        if !enabled { stopLanServer() }
        synchronizeDrinks()
        return true
    }

    func setLanSyncEnabled(_ enabled: Bool) -> Bool {
        var changed = state
        changed.preferences.lanSyncEnabled = enabled
        guard save(changed) else { return false }
        if !enabled { stopLanServer() }
        synchronizeDrinks()
        return true
    }

    func setLanPrimaryEnabled(_ enabled: Bool) -> Bool {
        var changed = state
        changed.preferences.lanPrimaryEnabled = enabled
        guard save(changed) else { return false }
        synchronizeDrinks()
        return true
    }

    func setLanShortName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LanDeviceNamer.isValidShortName(trimmed) else {
            error = "设备后缀需为 1–8 个英文字母或数字，且不能使用 iPH"
            return false
        }
        guard isShortNameAvailable(trimmed) else {
            error = "设备后缀已被其他电脑使用"
            return false
        }
        var changed = state
        changed.preferences.lanShortName = trimmed
        guard save(changed) else { return false }
        synchronizeDrinks()
        return true
    }

    func shutdown() {
        lanPathMonitor?.cancel()
        lanPathMonitor = nil
        stopLanServer()
    }

    func refreshSync() {
        now = Date()
        synchronizeDrinks()
    }

    func openSyncFolder() {
        let directory = drinkSync.syncDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func queue(_ event: DrinkSyncEvent?) {
        guard syncEnabled, let event else { return }
        do {
            try drinkSync.enqueue(event)
            try drinkSync.flushOutbox(sourceDeviceID: lanIdentity.deviceID)
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    private var lanEnabled: Bool {
        syncEnabled && (preferences.lanSyncEnabled ?? true)
    }

    private var lanTokenURL: URL {
        file.deletingLastPathComponent().appendingPathComponent("lan-token")
    }

    private func isShortNameAvailable(_ value: String) -> Bool {
        guard LanDeviceNamer.isValidShortName(value),
              let devices = try? drinkSync.loadDevices() else {
            return LanDeviceNamer.isValidShortName(value)
        }
        return !devices.contains {
            $0.deviceID != lanIdentity.deviceID
                && $0.shortName.caseInsensitiveCompare(value) == .orderedSame
        }
    }

    private func resolvedShortName() -> String {
        let others = (try? drinkSync.loadDevices())?
            .filter { $0.deviceID != lanIdentity.deviceID } ?? []
        return LanDeviceNamer.resolvedShortName(
            configured: preferences.lanShortName,
            deviceID: lanIdentity.deviceID,
            others: others
        )
    }

    private func stopLanServer() {
        lanServer?.stop()
        lanServer = nil
        lanPort = nil
        lanSyncEndpoint = nil
        lastDeviceSignature = nil
        lastDevicePublishedAt = nil
        lanServerStartBlocked = false
    }

    private func ensureLanServer() throws {
        guard lanEnabled else {
            stopLanServer()
            return
        }
        if lanServer == nil {
            guard !lanServerStartBlocked else {
                throw CocoaError(.fileWriteUnknown)
            }
            let token = try LanSyncSupport.loadOrCreateToken(at: lanTokenURL)
            lanToken = token
            let server = LanDrinkServer(
                token: token,
                handler: { [weak self] event in
                    guard let self else { return .unavailable("app closed") }
                    return await MainActor.run { self.receiveLAN(event) }
                },
                todayHandler: { [weak self] in
                    guard let self else { return .unavailable("app closed") }
                    return await MainActor.run { self.lanTodaySummary() }
                }
            )
            do {
                lanPort = try server.start()
                lanServer = server
            } catch {
                lanServerStartBlocked = true
                throw error
            }
        }
        guard let lanPort else {
            lanSyncEndpoint = nil
            throw CocoaError(.fileReadUnknown)
        }
        lanSyncEndpoint = LanAddressSelector.endpoint(
            hostName: lanIdentity.hostName,
            addresses: LanSyncSupport.localIPv4Addresses(),
            port: lanPort
        )
        if lanSyncEndpoint == nil {
            lanSyncError = "当前没有可用的局域网地址，继续使用 iCloud"
        } else {
            lanSyncError = nil
        }
    }

    private func publishLanDevice() throws {
        guard lanEnabled, let endpoint = lanSyncEndpoint, let token = lanToken else { return }
        let shortName = resolvedShortName()
        lanShortName = shortName
        if preferences.lanShortName != shortName {
            var changed = state
            changed.preferences.lanShortName = shortName
            guard save(changed) else { return }
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let role = (preferences.lanPrimaryEnabled ?? false) ? "primary" : "standby"
        let signature = [
            lanIdentity.deviceID, lanIdentity.deviceName, shortName, role,
            endpoint.url, endpoint.fallbackURL, endpoint.subnet, token
        ].joined(separator: "|")
        let currentTime = Date()
        if signature == lastDeviceSignature,
           let last = lastDevicePublishedAt,
           currentTime.timeIntervalSince(last) < 60 {
            return
        }
        let record = try LanDeviceRecord(
            deviceID: lanIdentity.deviceID,
            name: lanIdentity.deviceName,
            shortName: shortName,
            role: role == "primary" ? .primary : .standby,
            lanURL: endpoint.url,
            lanFallbackURL: endpoint.fallbackURL,
            lanSubnet: endpoint.subnet,
            lanToken: token,
            lastSeen: formatter.string(from: currentTime),
            lastSeenEpoch: Int(currentTime.timeIntervalSince1970)
        )
        try drinkSync.publishDevice(record)
        lastDeviceSignature = signature
        lastDevicePublishedAt = currentTime
    }

    private func receiveLAN(_ event: DrinkSyncEvent) -> LanDrinkResponse {
        guard lanEnabled else { return .unavailable("LAN sync is disabled") }
        let lowerSource = event.source.lowercased()
        guard lowerSource.contains("iphone") || lowerSource.contains("phone") else {
            return .invalid("only phone events are accepted")
        }
        do {
            try drinkSync.enqueue(event)
            let result = LanDrinkIngestor.ingest(event, into: state)
            guard save(result.state) else {
                return .unavailable("could not save the drink")
            }
            try? drinkSync.flushOutbox(sourceDeviceID: lanIdentity.deviceID)
            try? drinkSync.appendMissingShared(drinks: state.drinks)
            try? drinkSync.publishSettings(
                goal: preferences.goal,
                serving: preferences.serving,
                weekday: preferences.weekday,
                weekend: preferences.weekend,
                snooze: preferences.snooze,
                stopAtGoal: preferences.stopAtGoal
            )
            try? drinkSync.publishTodaySummary(drinks: state.drinks, goal: preferences.goal, now: Date())
            if !result.duplicate, let amount = event.milliliters {
                notice = "已从 iPhone 记录 \(amount)ml"
            }
            return .accepted(duplicate: result.duplicate)
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    private func lanTodaySummary() -> LanDrinkResponse {
        guard lanEnabled else { return .unavailable("LAN sync is disabled") }
        do {
            return .today(
                try drinkSync.todaySummary(
                    drinks: state.drinks,
                    goal: preferences.goal,
                    now: Date()
                )
            )
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    private func startLanPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                self?.lanServerStartBlocked = false
                self?.synchronizeDrinks()
            }
        }
        monitor.start(queue: lanMonitorQueue)
        lanPathMonitor = monitor
    }

    private func dayKey(for date: Date) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    private func mergeExternalDrinks(_ drinks: [Drink]) -> Bool {
        guard drinks != state.drinks else { return true }
        let previousTotal = total
        var changed = state
        changed.drinks = drinks
        let dayKey = self.dayKey(for: now)
        let storedCelebrations = changed.celebratedMilestones?[dayKey] ?? []
        let update = Milestones.update(
            celebrated: storedCelebrations,
            from: previousTotal,
            to: changed.total(on: now),
            goal: preferences.goal
        )
        if update.celebrated != storedCelebrations {
            var history = changed.celebratedMilestones ?? [:]
            history[dayKey] = update.celebrated
            changed.celebratedMilestones = history
        }
        guard save(changed) else { return false }
        if let milestone = update.triggered {
            showMilestone(milestone)
        }
        return true
    }

    private func synchronizeDrinks() {
        guard storageReadable else {
            syncStatus = .failed(error ?? "无法读取本地饮水记录")
            return
        }
        guard syncEnabled else {
            syncStatus = .disabled
            return
        }
        do {
            if !sharedCSVMigrated {
                let migrated = try drinkSync.migrateLegacyFiles(
                    backupDirectory: drinkSync.migrationBackupDirectory
                )
                let merged = DrinkSyncMerge.apply(events: migrated, to: state.drinks)
                guard mergeExternalDrinks(merged) else { return }
                sharedCSVMigrated = true
                UserDefaults.standard.set(true, forKey: sharedCSVMigrationKey)
            }

            let devices = try drinkSync.loadDevices()
            let aliased = LanDrinkIngestor.applyDeviceAliases(devices, to: state)
            if aliased.changed {
                guard save(aliased.state) else { return }
            }
            let events = try drinkSync.loadEvents()
            let merged = DrinkSyncMerge.apply(
                events: try drinkSync.loadSharedEvents() + events,
                to: state.drinks
            )
            guard mergeExternalDrinks(merged) else { return }
            try drinkSync.appendMissingShared(drinks: state.drinks)
            try drinkSync.flushOutbox(sourceDeviceID: lanIdentity.deviceID)
            try drinkSync.publishSettings(
                goal: preferences.goal,
                serving: preferences.serving,
                weekday: preferences.weekday,
                weekend: preferences.weekend,
                snooze: preferences.snooze,
                stopAtGoal: preferences.stopAtGoal
            )
            try drinkSync.publishTodaySummary(drinks: state.drinks, goal: preferences.goal, now: now)
            if lanEnabled {
                do {
                    try ensureLanServer()
                    try publishLanDevice()
                } catch {
                    lanSyncError = "局域网加速暂不可用：\(error.localizedDescription)"
                }
            } else {
                stopLanServer()
                lanSyncError = nil
            }
            let phoneEvents = events.filter {
                $0.kind == .drink && $0.source.lowercased().contains("iphone")
            }
            syncStatus = DrinkSyncReadiness.classify(
                enabled: true,
                phoneEventCount: phoneEvents.count,
                syncedAt: now
            )
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }
}
