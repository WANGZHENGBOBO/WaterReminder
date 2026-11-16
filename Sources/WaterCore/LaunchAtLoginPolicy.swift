import Foundation

public enum LaunchAtLoginPreference: String, Equatable {
    case automatic
    case disabled
}

public enum LaunchAtLoginStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case unavailable
}

public enum LaunchAtLoginPolicy {
    public static func shouldRegister(
        preference: LaunchAtLoginPreference,
        status: LaunchAtLoginStatus
    ) -> Bool {
        guard preference == .automatic else { return false }
        return status == .notRegistered || status == .unavailable
    }
}
