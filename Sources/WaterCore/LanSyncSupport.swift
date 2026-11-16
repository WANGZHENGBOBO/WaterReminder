import Foundation
import Darwin
import Security

public enum LanSyncSupport {
    public static func loadOrCreateToken(at url: URL) throws -> String {
        let existing = (try? String(contentsOf: url, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isValidToken(existing) { return existing }

        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CocoaError(.fileWriteUnknown)
        }
        let token = Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(token.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return token
    }

    public static func localIPv4Addresses() -> [String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(first) }

        var candidates: [(name: String, address: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                address, socklen_t(address.pointee.sa_len),
                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST
            )
            guard status == 0 else { continue }
            let value = String(cString: host)
            let name = String(cString: current.pointee.ifa_name)
            candidates.append((name, value))
        }
        let sorted = candidates.sorted { left, right in
            let leftPriority = interfacePriority(left.name)
            let rightPriority = interfacePriority(right.name)
            if leftPriority != rightPriority { return leftPriority > rightPriority }
            return left.name < right.name
        }
        var result: [String] = []
        for candidate in sorted where !result.contains(candidate.address) {
            result.append(candidate.address)
        }
        return result
    }

    private static func interfacePriority(_ name: String) -> Int {
        if name.hasPrefix("en") { return 3 }
        if name.hasPrefix("bridge") { return 2 }
        if name.hasPrefix("utun") || name.hasPrefix("awdl") || name.hasPrefix("llw") {
            return 0
        }
        return 1
    }

    private static func isValidToken(_ value: String) -> Bool {
        (40...128).contains(value.count)
            && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
