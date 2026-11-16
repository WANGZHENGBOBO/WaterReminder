import Foundation
import IOKit

struct LanLocalIdentity {
    let deviceID: String
    let deviceName: String
    let hostName: String

    static func live() -> Self {
        let defaults = UserDefaults.standard
        let installKey = "lanInstallID.v1"
        let installID: String
        if let existing = defaults.string(forKey: installKey), !existing.isEmpty {
            installID = existing
        } else {
            let value = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
            defaults.set(value, forKey: installKey)
            installID = value
        }

        let hardware = IOPlatformUUID()?
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefix(8) ?? ""
        let stablePart = hardware.isEmpty
            ? ProcessInfo.processInfo.hostName.lowercased().filter { $0.isLetter || $0.isNumber }
            : String(hardware)
        let deviceID = "mac-\(stablePart)-\(installID)"
        let deviceName = Host.current().localizedName
            ?? ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
        let hostName = ProcessInfo.processInfo.hostName
        return Self(deviceID: deviceID, deviceName: deviceName, hostName: hostName)
    }

    private static func IOPlatformUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(
            service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String
        return value
    }
}
