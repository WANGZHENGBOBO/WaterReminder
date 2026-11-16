import Foundation

public struct LanEndpoint: Equatable {
    public let hostName: String
    public let ipv4: String
    public let subnet: String
    public let port: UInt16
    public let url: String
    public let fallbackURL: String

    public init(hostName: String, ipv4: String, subnet: String, port: UInt16) {
        self.hostName = hostName
        self.ipv4 = ipv4
        self.subnet = subnet
        self.port = port
        self.url = "http://\(hostName):\(port)"
        self.fallbackURL = "http://\(ipv4):\(port)"
    }
}

public enum LanAddressSelector {
    public static func privateIPv4(in addresses: [String]) -> String? {
        addresses.first(where: isPrivateIPv4)
    }

    public static func subnet(forIPv4 value: String) -> String? {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ Int($0).map { (0...255).contains($0) } == true }) else {
            return nil
        }
        return parts.prefix(3).joined(separator: ".")
    }

    public static func endpoint(hostName: String, addresses: [String], port: UInt16) -> LanEndpoint? {
        guard let ipv4 = privateIPv4(in: addresses),
              let subnet = subnet(forIPv4: ipv4),
              let host = normalizedHost(hostName) else { return nil }
        return LanEndpoint(hostName: host, ipv4: ipv4, subnet: subnet, port: port)
    }

    public static func normalizedHost(_ value: String) -> String? {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while host.hasSuffix(".") { host.removeLast() }
        guard !host.isEmpty,
              !host.contains(where: { $0.isWhitespace || $0 == "/" || $0 == ":" }),
              !host.contains("..") else { return nil }
        if !host.hasSuffix(".local") { host += ".local" }
        return host
    }

    private static func isPrivateIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == 4, numbers.allSatisfy({ (0...255).contains($0) }) else { return false }
        let first = numbers[0]
        let second = numbers[1]
        guard first != 127, first != 0, first < 224,
              !(first == 169 && second == 254) else { return false }
        return first == 10
            || (first == 172 && (16...31).contains(second))
            || (first == 192 && second == 168)
    }
}

public enum LanDeviceSelector {
    public static func candidates(_ devices: [LanDeviceRecord], phoneIPv4: String,
                                  now: Date) -> [LanDeviceRecord] {
        guard let subnet = LanAddressSelector.subnet(forIPv4: phoneIPv4) else { return [] }
        let formatter = ISO8601DateFormatter()
        return devices.filter { device in
            guard device.lanSubnet == subnet else { return false }
            let seen = device.lastSeenEpoch.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                ?? formatter.date(from: device.lastSeen)
            guard let seen else { return false }
            let age = now.timeIntervalSince(seen)
            return age >= -86_400 && age <= 7 * 86_400
        }.sorted { left, right in
            if left.role != right.role { return left.role == .primary }
            let leftSeen = left.lastSeenEpoch.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                ?? formatter.date(from: left.lastSeen) ?? .distantPast
            let rightSeen = right.lastSeenEpoch.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                ?? formatter.date(from: right.lastSeen) ?? .distantPast
            if leftSeen != rightSeen { return leftSeen > rightSeen }
            if left.shortName != right.shortName { return left.shortName < right.shortName }
            return left.deviceID < right.deviceID
        }
    }

    public static func select(_ devices: [LanDeviceRecord], phoneIPv4: String,
                              now: Date) -> LanDeviceRecord? {
        candidates(devices, phoneIPv4: phoneIPv4, now: now).first
    }
}
