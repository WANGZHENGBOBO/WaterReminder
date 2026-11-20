import Combine
import Foundation
import WatchConnectivity

@MainActor
final class PhoneSession: NSObject, ObservableObject {
    enum SyncState: Equatable {
        case folderRequired
        case waiting(String)
        case saved(Date)
    }

    @Published private(set) var syncState: SyncState = .folderRequired
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastAmount: Int?
    @Published private(set) var watchReachable = false
    @Published private(set) var selectedFolderName: String?
    @Published private(set) var defaultServing = CompanionSettings.fallback.serving
    @Published private(set) var goal = CompanionSettings.fallback.goal
    @Published private(set) var todayTotal = 0

    private let session: WCSession?
    private let reminderService = CompanionNotificationService()
    private let folderAccess = FolderAccess()
    private let queueStorage = PendingEventStorage.live()
    private var queue = PendingEventQueue()
    private var processedRecordIDs = Set<String>()

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        queue = (try? queueStorage.load()) ?? PendingEventQueue()
        selectedFolderName = folderAccess.selectedURL?.lastPathComponent
        refreshQueueState()
        reminderService.onQuickRecord = { [weak self] amount in
            self?.submit(milliliters: amount)
        }
        session?.delegate = self
        session?.activate()
        reloadSettings()
        retryPending()
    }

    func chooseFolder(_ url: URL) {
        do {
            try folderAccess.save(url: url)
            selectedFolderName = url.lastPathComponent
            reloadSettings()
            retryPending()
        } catch {
            syncState = .waiting(error.localizedDescription)
        }
    }

    func retryPending() {
        refreshQueueState()
        guard folderAccess.selectedURL != nil else {
            syncState = .folderRequired
            publishStatus()
            return
        }
        var changed = false
        for event in queue.events {
            do {
                _ = try folderAccess.write(event)
                queue.remove(recordID: event.recordID)
                processedRecordIDs.insert(event.recordID)
                changed = true
            } catch {
                syncState = .waiting(error.localizedDescription)
                if changed { try? queueStorage.save(queue) }
                refreshQueueState()
                publishStatus()
                return
            }
        }
        if changed {
            try? queueStorage.save(queue)
        }
        refreshQueueState()
        if queue.events.isEmpty {
            syncState = .saved(Date())
        } else {
            syncState = .waiting("等待写入 iCloud")
        }
        publishStatus()
    }

    @discardableResult
    func submit(milliliters: Int) -> Bool {
        guard let payload = try? WatchDrinkPayload(milliliters: milliliters) else {
            syncState = .waiting("请输入 1～2000ml")
            return false
        }
        return accept(payload)
    }

    func refresh() {
        reloadSettings()
        retryPending()
    }

    private func accept(_ payload: WatchDrinkPayload) -> Bool {
        let event = PhoneDrinkEvent(payload)
        guard !processedRecordIDs.contains(event.recordID) else {
            return true
        }
        lastAmount = payload.milliliters
        if queue.enqueue(event) {
            try? queueStorage.save(queue)
        }
        retryPending()
        let saved = processedRecordIDs.contains(event.recordID)
        if saved {
            todayTotal += payload.milliliters
        }
        return saved
    }

    private func reloadSettings() {
        guard folderAccess.selectedURL != nil else {
            defaultServing = CompanionSettings.fallback.serving
            goal = CompanionSettings.fallback.goal
            todayTotal = 0
            publishStatus()
            return
        }
        let settings = (try? folderAccess.readSettings()) ?? .fallback
        let summary = try? folderAccess.readTodaySummary()
        defaultServing = settings.serving
        goal = settings.goal
        if let summary, summary.isCurrentDay() {
            todayTotal = summary.total
        } else if summary == nil {
            todayTotal = 0
        }
        reminderService.schedule(settings: settings, summary: summary)
        publishStatus()
    }

    private func reject(_ error: Error) {
        syncState = .waiting(error.localizedDescription)
        publishStatus()
    }

    private func refreshQueueState() {
        pendingCount = queue.events.count
        watchReachable = session?.isReachable ?? false
    }

    private func publishStatus() {
        refreshQueueState()
        let text: String
        switch syncState {
        case .folderRequired: text = "等待选择 iCloud 文件夹"
        case .waiting(let message): text = message
        case .saved: text = "已保存 iCloud"
        }
        try? session?.updateApplicationContext([
            "status": text,
            "pending": pendingCount,
            "amount": lastAmount ?? 0,
            "serving": defaultServing,
            "goal": goal,
            "todayTotal": todayTotal
        ])
    }
}

extension PhoneSession: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.watchReachable = session.isReachable
            self.retryPending()
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            do {
                let payload = try WatchMessageCodec.decode(message)
                let saved = self.accept(payload)
                replyHandler([
                    "ok": saved,
                    "status": saved ? "saved" : "pending"
                ])
            } catch {
                self.reject(error)
                replyHandler(["ok": false, "status": "invalid"])
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            do {
                _ = self.accept(try WatchMessageCodec.decode(userInfo))
            } catch {
                self.reject(error)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.watchReachable = session.isReachable
        }
    }
}
