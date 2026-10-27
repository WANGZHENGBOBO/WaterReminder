import Foundation

public struct DrinkSyncSettings: Codable, Equatable {
    public let schemaVersion: Int
    public let goal: Int
    public let serving: Int

    public init(goal: Int, serving: Int) throws {
        guard (1...10_000).contains(goal), (1...2_000).contains(serving) else {
            throw DrinkSyncError.invalidAmount
        }
        self.schemaVersion = 1
        self.goal = goal
        self.serving = serving
    }
}

public struct DrinkSyncFilesystem {
    public let outboxDirectory: URL
    public let syncDirectory: URL
    private let fileManager: FileManager

    public init(outboxDirectory: URL, syncDirectory: URL, fileManager: FileManager = .default) {
        self.outboxDirectory = outboxDirectory
        self.syncDirectory = syncDirectory
        self.fileManager = fileManager
    }

    public func loadEvents() throws -> [DrinkSyncEvent] {
        var byID: [UUID: DrinkSyncEvent] = [:]
        for directory in [syncDirectory, outboxDirectory] where fileManager.fileExists(atPath: directory.path) {
            let files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for file in files where file.pathExtension.lowercased() == "json" && file.lastPathComponent != "settings.json" {
                guard let data = try? Data(contentsOf: file),
                      let event = try? DrinkSyncEvent.decode(data) else { continue }
                byID[event.id] = event
            }
        }
        return byID.values.sorted {
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func enqueue(_ event: DrinkSyncEvent) throws {
        try fileManager.createDirectory(at: outboxDirectory, withIntermediateDirectories: true)
        try event.encoded().write(to: eventURL(event.id, in: outboxDirectory), options: .atomic)
    }

    public func enqueueMissing(drinks: [Drink], source: String) throws {
        let represented = Set(try loadEvents().map(\.recordID))
        for drink in drinks where !represented.contains(drink.id) {
            let event = try DrinkSyncEvent(
                kind: .drink,
                recordID: drink.id,
                timestamp: drink.date,
                milliliters: drink.grams,
                source: source
            )
            try enqueue(event)
        }
    }

    public func flushOutbox() throws {
        guard fileManager.fileExists(atPath: outboxDirectory.path) else { return }
        try fileManager.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let files = try fileManager.contentsOfDirectory(
            at: outboxDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for source in files where source.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: source)
            let event = try DrinkSyncEvent.decode(data)
            let destination = eventURL(event.id, in: syncDirectory)
            try data.write(to: destination, options: .atomic)
            let copied = try DrinkSyncEvent.decode(Data(contentsOf: destination))
            guard copied == event else { throw CocoaError(.fileWriteUnknown) }
            try fileManager.removeItem(at: source)
        }
    }

    public func publishSettings(goal: Int, serving: Int) throws {
        let settings = try DrinkSyncSettings(goal: goal, serving: serving)
        try fileManager.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(
            to: syncDirectory.appendingPathComponent("settings.json"),
            options: .atomic
        )
    }

    private func eventURL(_ id: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent(id.uuidString.lowercased()).appendingPathExtension("json")
    }
}
