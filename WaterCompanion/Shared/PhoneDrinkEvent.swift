import Foundation

public struct PhoneDrinkEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let kind: String
    public let recordID: String
    public let timestamp: Date
    public let milliliters: Int
    public let source: String
    public let deviceID: String
    public let deviceName: String
    public let deviceShortName: String

    public init(_ payload: WatchDrinkPayload) {
        let eventID = payload.id.uuidString.lowercased()
        schemaVersion = 1
        id = eventID
        kind = "drink"
        recordID = eventID
        timestamp = payload.timestamp
        milliliters = payload.milliliters
        source = "iphone-watch"
        deviceID = "apple-watch-companion"
        deviceName = "Apple Watch"
        deviceShortName = "WCH"
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

public enum EventFileWriter {
    @discardableResult
    public static func write(
        _ event: PhoneDrinkEvent,
        to directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(event.recordID).json")
        try event.encoded().write(to: url, options: .atomic)
        return url
    }
}
