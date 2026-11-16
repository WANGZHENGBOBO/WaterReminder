import SwiftUI
import WaterCore

struct SyncStatusLabel: View {
    let status: DrinkSyncReadiness

    var body: some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
    }

    private var text: String {
        switch status {
        case .disabled:
            return "iCloud 同步已关闭"
        case .waiting:
            return "同步已开启，等待手机第一次记录"
        case .healthy(let latest):
            return "同步正常 · 最近 \(latest.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            return "同步遇到问题：\(message)"
        }
    }

    private var icon: String {
        switch status {
        case .disabled: return "icloud.slash"
        case .waiting: return "icloud"
        case .healthy: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }

    private var color: Color {
        switch status {
        case .failed: return .red
        case .healthy: return .green
        default: return .secondary
        }
    }
}
