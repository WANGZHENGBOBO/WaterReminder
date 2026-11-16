import Foundation
import ServiceManagement
import WaterCore

@MainActor
final class LaunchAtLoginController {
    static let shared = LaunchAtLoginController()

    private let defaults = UserDefaults.standard
    private let preferenceKey = "launchAtLoginPreference.v1"
    private let registeredPathKey = "launchAtLoginRegisteredBundlePath.v1"

    private init() {}

    var preference: LaunchAtLoginPreference {
        guard let raw = defaults.string(forKey: preferenceKey),
              let value = LaunchAtLoginPreference(rawValue: raw) else {
            return .automatic
        }
        return value
    }

    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    var isEnabled: Bool { status == .enabled }

    func prepareAtLaunch() {
        guard preference == .automatic else { return }
        let bundlePath = Bundle.main.bundlePath
        let registeredPath = defaults.string(forKey: registeredPathKey)

        if status == .enabled, registeredPath == bundlePath { return }
        if status == .enabled, registeredPath != bundlePath {
            try? SMAppService.mainApp.unregister()
        }
        guard LaunchAtLoginPolicy.shouldRegister(preference: preference, status: status) else {
            return
        }
        do {
            try SMAppService.mainApp.register()
            defaults.set(bundlePath, forKey: registeredPathKey)
        } catch {
            // The Settings toggle exposes approval guidance when macOS blocks this.
        }
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginStatus {
        if enabled {
            defaults.set(LaunchAtLoginPreference.automatic.rawValue, forKey: preferenceKey)
            try SMAppService.mainApp.register()
            defaults.set(Bundle.main.bundlePath, forKey: registeredPathKey)
        } else {
            defaults.set(LaunchAtLoginPreference.disabled.rawValue, forKey: preferenceKey)
            try SMAppService.mainApp.unregister()
            defaults.removeObject(forKey: registeredPathKey)
        }
        return status
    }

    var errorMessage: String? {
        switch status {
        case .requiresApproval:
            return "请在系统设置的登录项中允许喝水BO～。"
        case .unavailable:
            return "当前系统无法注册自动启动，请把 App 移到“应用程序”文件夹后重试。"
        case .enabled, .notRegistered:
            return nil
        }
    }
}
