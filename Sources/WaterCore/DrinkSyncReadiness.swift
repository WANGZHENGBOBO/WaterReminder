import Foundation

public enum DrinkSyncReadiness: Equatable {
    case disabled
    case waiting
    case healthy(Date)
    case failed(String)

    public static func classify(enabled: Bool, phoneEventCount: Int, syncedAt: Date) -> Self {
        guard enabled else { return .disabled }
        guard phoneEventCount > 0 else { return .waiting }
        return .healthy(syncedAt)
    }
}
