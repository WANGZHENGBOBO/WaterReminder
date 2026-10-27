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
    public let id: UUID
    public let kind: Kind
    public let recordID: UUID
    public let timestamp: Date
    public let milliliters: Int?
    public let source: String

    public init(id: UUID = UUID(), kind: Kind, recordID: UUID, timestamp: Date,
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
        id = try values.decode(UUID.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        recordID = try values.decode(UUID.self, forKey: .recordID)
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
        let deleted = Set(events.lazy.filter { $0.kind == .delete }.map(\.recordID))
        var records = Dictionary(uniqueKeysWithValues: drinks.filter { !deleted.contains($0.id) }.map { ($0.id, $0) })
        let additions = events.filter { $0.kind == .drink && !deleted.contains($0.recordID) }
            .sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                return $0.id.uuidString < $1.id.uuidString
            }
        for event in additions {
            guard let amount = event.milliliters else { continue }
            records[event.recordID] = Drink(id: event.recordID, date: event.timestamp, grams: amount)
        }
        return records.values.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
