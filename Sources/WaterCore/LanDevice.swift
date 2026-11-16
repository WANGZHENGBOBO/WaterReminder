import Foundation

public enum LanDeviceRole: String, Codable, Equatable {
    case primary
    case standby
}

public struct LanDeviceRecord: Codable, Equatable {
    public let schemaVersion: Int
    public let deviceID: String
    public let name: String
    public let shortName: String
    public let role: LanDeviceRole
    public let lanURL: String
    public let lanFallbackURL: String
    public let lanSubnet: String
    public let lanToken: String
    public let lastSeen: String
    public let lastSeenEpoch: Int?

    public init(
        deviceID: String,
        name: String,
        shortName: String,
        role: LanDeviceRole,
        lanURL: String,
        lanFallbackURL: String,
        lanSubnet: String,
        lanToken: String,
        lastSeen: String,
        lastSeenEpoch: Int? = nil,
        schemaVersion: Int = 1
    ) throws {
        guard schemaVersion == 1 else { throw DrinkSyncError.unsupportedSchema }
        guard (1...128).contains(deviceID.count),
              (1...128).contains(name.count),
              LanDeviceNamer.isValidShortName(shortName),
              !lanURL.isEmpty, lanURL.count <= 256, !lanURL.hasSuffix("/"),
              !lanFallbackURL.isEmpty, lanFallbackURL.count <= 256, !lanFallbackURL.hasSuffix("/"),
              LanDeviceNamer.isValidSubnet(lanSubnet),
              (1...256).contains(lanToken.count),
              !lastSeen.isEmpty,
              (lastSeenEpoch.map { $0 > 0 } ?? true) else {
            throw DrinkSyncError.invalidSource
        }
        self.schemaVersion = schemaVersion
        self.deviceID = deviceID
        self.name = name
        self.shortName = shortName
        self.role = role
        self.lanURL = lanURL
        self.lanFallbackURL = lanFallbackURL
        self.lanSubnet = lanSubnet
        self.lanToken = lanToken
        self.lastSeen = lastSeen
        self.lastSeenEpoch = lastSeenEpoch
    }
}

public enum LanDeviceNamer {
    public static let phoneShortName = "iPH"
    public static let maximumShortNameLength = 8

    public static func nextShortName(existing: [String]) -> String {
        let used = Set(existing.map { $0.lowercased() })
        for number in 1...9_999 {
            let candidate = "M\(number)"
            if !used.contains(candidate.lowercased()) {
                return candidate
            }
        }
        return "M1"
    }

    public static func isValidShortName(_ value: String) -> Bool {
        guard (1...maximumShortNameLength).contains(value.count),
              value.lowercased() != phoneShortName.lowercased(),
              value.unicodeScalars.allSatisfy({
                  ($0.value >= 48 && $0.value <= 57)
                      || ($0.value >= 65 && $0.value <= 90)
                      || ($0.value >= 97 && $0.value <= 122)
              }) else {
            return false
        }
        return true
    }

    public static func isValidSubnet(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 3 && parts.allSatisfy {
            guard let number = Int($0) else { return false }
            return (0...255).contains(number) && String(number) == $0
        }
    }

    public static func resolvedShortName(configured: String?, deviceID: String,
                                         others: [LanDeviceRecord]) -> String {
        let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, isValidShortName(value) else {
            return nextShortName(existing: others.map(\.shortName))
        }
        let duplicates = others.filter {
            $0.deviceID != deviceID
                && $0.shortName.caseInsensitiveCompare(value) == .orderedSame
        }
        if duplicates.isEmpty { return value }

        let orderedIDs = ([deviceID] + duplicates.map(\.deviceID)).sorted()
        let position = orderedIDs.firstIndex(of: deviceID) ?? 0
        if position == 0 { return value }

        let used = Set(others.map { $0.shortName.lowercased() })
        var available: [String] = []
        for number in 1...9_999 {
            let candidate = "M\(number)"
            if !used.contains(candidate.lowercased()) {
                available.append(candidate)
            }
        }
        guard !available.isEmpty else { return "M1" }
        return available[min(position - 1, max(available.count - 1, 0))]
    }
}
