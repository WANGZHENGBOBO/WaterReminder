import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchSession: NSObject, ObservableObject {
    @Published private(set) var isReachable = false
    @Published private(set) var status = "等待 iPhone"
    @Published private(set) var sending = false
    @Published private(set) var defaultAmount = 197
    @Published private(set) var goal = 1800
    @Published private(set) var todayTotal = 0
    @Published private(set) var confirmation: RecordConfirmation?

    struct RecordConfirmation: Equatable {
        let id = UUID()
        let amount: Int
        let saved: Bool
    }

    private let session: WCSession?
    private let defaults = UserDefaults.standard
    private var pendingPayloads = PendingWatchPayloads()

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        let savedServing = defaults.integer(forKey: Self.servingKey)
        if (1...2000).contains(savedServing) {
            defaultAmount = savedServing
        }
        let savedGoal = defaults.integer(forKey: Self.goalKey)
        if savedGoal > 0 {
            goal = savedGoal
        }
        todayTotal = max(defaults.integer(forKey: Self.totalKey), 0)
        if let data = defaults.data(forKey: Self.pendingKey),
           let saved = try? JSONDecoder().decode(PendingWatchPayloads.self, from: data) {
            pendingPayloads = saved
        }
        session?.delegate = self
        session?.activate()
    }

    func record(milliliters: Int) {
        guard (1...2000).contains(milliliters) else {
            status = "请输入 1～2000ml"
            return
        }
        guard let session else {
            status = "这台手表不支持连接"
            return
        }
        do {
            let payload = try WatchDrinkPayload(milliliters: milliliters)
            let message = try WatchMessageCodec.encode(payload)
            sending = true
            if session.activationState == .activated, session.isReachable {
                session.sendMessage(
                    message,
                    replyHandler: { [weak self] reply in
                        Task { @MainActor in
                            guard let self else { return }
                            self.sending = false
                            let saved = (reply["ok"] as? Bool) == true
                            self.status = saved
                                ? "已保存 iCloud"
                                : "已交给 iPhone，等待写入"
                            self.confirmation = RecordConfirmation(
                                amount: payload.milliliters,
                                saved: saved
                            )
                        }
                    },
                    errorHandler: { [weak self] _ in
                        Task { @MainActor in
                            self?.queue(payload, on: session)
                        }
                    }
                )
            } else {
                queue(payload, on: session)
            }
        } catch {
            sending = false
            status = error.localizedDescription
        }
    }

    private func queue(_ payload: WatchDrinkPayload, on session: WCSession) {
        pendingPayloads.enqueue(payload)
        savePending()
        guard session.activationState == .activated else {
            sending = false
            status = "已保存，等待 iPhone"
            return
        }
        flushPending(on: session)
        sending = false
        status = "已交给 iPhone，等待写入"
        confirmation = RecordConfirmation(
            amount: payload.milliliters,
            saved: false
        )
    }

    private func flushPending(on session: WCSession) {
        while let payload = pendingPayloads.first {
            guard let message = try? WatchMessageCodec.encode(payload) else {
                pendingPayloads.popFirst()
                continue
            }
            guard session.transferUserInfo(message) != nil else { break }
            pendingPayloads.popFirst()
        }
        savePending()
    }

    private func savePending() {
        if let data = try? JSONEncoder().encode(pendingPayloads) {
            defaults.set(data, forKey: Self.pendingKey)
        }
    }

    private static let pendingKey = "pendingWatchPayloads.v1"
    private static let servingKey = "lastServing.v1"
    private static let goalKey = "lastGoal.v1"
    private static let totalKey = "lastTodayTotal.v1"
}

extension WatchSession: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if error != nil {
                self.status = "无法连接 iPhone"
            } else if activationState == .activated {
                self.flushPending(on: session)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            if let value = applicationContext["status"] as? String {
                self.status = value
            }
            if let serving = applicationContext["serving"] as? Int {
                self.defaultAmount = serving
                self.defaults.set(serving, forKey: Self.servingKey)
            }
            if let goal = applicationContext["goal"] as? Int {
                self.goal = goal
                self.defaults.set(goal, forKey: Self.goalKey)
            }
            if let total = applicationContext["todayTotal"] as? Int {
                self.todayTotal = total
                self.defaults.set(total, forKey: Self.totalKey)
            }
        }
    }
}
