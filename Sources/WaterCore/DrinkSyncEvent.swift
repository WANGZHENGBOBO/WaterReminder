import Foundation

public enum DrinkSyncError: Error, Equatable {
    case unsupportedSchema
    case invalidAmount
    case invalidSource
    case invalidDeletePayload
}

public struct DrinkSyncEvent: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable {
        case drink
        case delete
    }

    public let schemaVersion: Int
    public let id: String
    public let kind: Kind
    public let recordID: String
    public let timestamp: Date
    public let milliliters: Int?
    public let source: String

    public init(id: String = UUID().uuidString, kind: Kind, recordID: String, timestamp: Date,
                milliliters: Int?, source: String, schemaVersion: Int = 1) throws {
        self.schemaVersion = schemaVersion
        self.id = id
        self.kind = kind
        self.recordID = recordID
        self.timestamp = timestamp
        self.milliliters = milliliters
        self.source = source
        try validate()
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        id = try values.decode(String.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        recordID = try values.decode(String.self, forKey: .recordID)
        timestamp = try values.decode(Date.self, forKey: .timestamp)
        milliliters = try values.decodeIfPresent(Int.self, forKey: .milliliters)
        source = try values.decode(String.self, forKey: .source)
        try validate()
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> DrinkSyncEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }

    private func validate() throws {
        guard schemaVersion == 1 else { throw DrinkSyncError.unsupportedSchema }
        guard !id.isEmpty, id.count <= 128, !recordID.isEmpty, recordID.count <= 128 else {
            throw DrinkSyncError.invalidSource
        }
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              source.count <= 64 else { throw DrinkSyncError.invalidSource }
        switch kind {
        case .drink:
            guard let milliliters, (1...2000).contains(milliliters) else {
                throw DrinkSyncError.invalidAmount
            }
        case .delete:
            guard milliliters == nil else { throw DrinkSyncError.invalidDeletePayload }
        }
    }
}

public enum DrinkSyncMerge {
    public static func apply(events: [DrinkSyncEvent], to drinks: [Drink]) -> [Drink] {
        let deleted = Set(events.lazy.filter { $0.kind == .delete }.map { resolvedUUID(for: $0.recordID) })
        var records: [UUID: Drink] = [:]
        for drink in drinks where !deleted.contains(drink.id) {
            records[drink.id] = drink
        }
        let additions = events.filter { $0.kind == .drink && !deleted.contains(resolvedUUID(for: $0.recordID)) }
            .sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                return $0.id < $1.id
            }
        for event in additions {
            guard let amount = event.milliliters else { continue }
            let drinkID = resolvedUUID(for: event.recordID)
            records[drinkID] = Drink(id: drinkID, date: event.timestamp, grams: amount)
        }
        return records.values.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func resolvedUUID(for value: String) -> UUID {
        UUID(uuidString: value) ?? stableUUID(for: value)
    }

    private static func stableUUID(for value: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in value.utf8.enumerated() {
            let slot = index % 16
            bytes[slot] = bytes[slot] &* 31 &+ byte &+ UInt8(truncatingIfNeeded: index)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return bytes.withUnsafeBytes { raw in
            UUID(uuid: raw.load(as: uuid_t.self))
        }
    }
}
