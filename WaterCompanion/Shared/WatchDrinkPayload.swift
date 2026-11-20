import Foundation

public enum WatchDrinkError: Error, Equatable {
    case invalidAmount
    case invalidMessage
}

public struct WatchDrinkPayload: Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let milliliters: Int

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        milliliters: Int
    ) throws {
        guard (1...2000).contains(milliliters) else {
            throw WatchDrinkError.invalidAmount
        }
        self.id = id
        // ISO-8601 transport has second precision; normalize before sending so
        // the watch payload, local queue and Mac event stay byte-for-byte stable.
        self.timestamp = Date(timeIntervalSince1970: floor(timestamp.timeIntervalSince1970))
        self.milliliters = milliliters
    }

    public static func `default`() throws -> Self {
        try Self(milliliters: 197)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, milliliters
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(UUID.self, forKey: .id),
            timestamp: values.decode(Date.self, forKey: .timestamp),
            milliliters: values.decode(Int.self, forKey: .milliliters)
        )
    }
}

public enum WatchMessageCodec {
    public static let payloadKey = "payload"

    public static func encode(_ payload: WatchDrinkPayload) throws -> [String: Any] {
        [payloadKey: try Self.encoder.encode(payload)]
    }

    public static func decode(_ message: [String: Any]) throws -> WatchDrinkPayload {
        guard let data = message[payloadKey] as? Data else {
            throw WatchDrinkError.invalidMessage
        }
        return try Self.decoder.decode(WatchDrinkPayload.self, from: data)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public struct PendingWatchPayloads: Codable, Equatable, Sendable {
    private(set) public var payloads: [WatchDrinkPayload]

    public init(payloads: [WatchDrinkPayload] = []) {
        var seen = Set<UUID>()
        self.payloads = payloads.filter { seen.insert($0.id).inserted }
    }

    @discardableResult
    public mutating func enqueue(_ payload: WatchDrinkPayload) -> Bool {
        guard !payloads.contains(where: { $0.id == payload.id }) else {
            return false
        }
        payloads.append(payload)
        return true
    }

    public mutating func popFirst() -> WatchDrinkPayload? {
        guard !payloads.isEmpty else { return nil }
        return payloads.removeFirst()
    }

    public var first: WatchDrinkPayload? {
        payloads.first
    }
}
