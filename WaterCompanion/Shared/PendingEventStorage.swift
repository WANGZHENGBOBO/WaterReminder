import Foundation

public struct PendingEventStorage {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public static func live(fileManager: FileManager = .default) -> Self {
        let directory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("WaterCompanion", isDirectory: true)
        return Self(
            fileURL: directory.appendingPathComponent("pending-events.json"),
            fileManager: fileManager
        )
    }

    public func load() throws -> PendingEventQueue {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PendingEventQueue()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            PendingEventQueue.self,
            from: Data(contentsOf: fileURL)
        )
    }

    public func save(_ queue: PendingEventQueue) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(queue).write(to: fileURL, options: .atomic)
    }
}
