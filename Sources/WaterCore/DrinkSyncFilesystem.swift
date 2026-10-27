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
        var byID: [String: DrinkSyncEvent] = [:]
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
            if directory == syncDirectory {
                for event in shortcutLogEvents(in: directory) { byID[event.id] = event }
            }
        }
        return byID.values.sorted {
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            return $0.id < $1.id
        }
    }

    public func enqueue(_ event: DrinkSyncEvent) throws {
        try fileManager.createDirectory(at: outboxDirectory, withIntermediateDirectories: true)
        try event.encoded().write(to: eventURL(event.id, in: outboxDirectory), options: .atomic)
    }

    public func enqueueMissing(drinks: [Drink], source: String) throws {
        let represented = Set(try loadEvents().map(\.recordID))
        for drink in drinks where !represented.contains(drink.id.uuidString) {
            let event = try DrinkSyncEvent(
                kind: .drink,
                recordID: drink.id.uuidString,
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

    private func eventURL(_ id: String, in directory: URL) -> URL {
        let safe = id.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "-" }
        return directory.appendingPathComponent(String(safe).lowercased()).appendingPathExtension("json")
    }

    private func shortcutLogEvents(in directory: URL) -> [DrinkSyncEvent] {
        let amountURL = directory.appendingPathComponent("iphone-amounts.txt")
        let timeURL = directory.appendingPathComponent("iphone-times.txt")
        guard let amountText = try? String(contentsOf: amountURL, encoding: .utf8),
              let timeText = try? String(contentsOf: timeURL, encoding: .utf8) else { return [] }
        let amounts = amountText.split(whereSeparator: \.isNewline)
        let times = timeText.split(whereSeparator: \.isNewline)
        return zip(amounts, times).enumerated().compactMap { index, pair in
            guard let amount = Int(pair.0.trimmingCharacters(in: .whitespaces)),
                  let timestamp = Self.parseShortcutDate(String(pair.1)) else { return nil }
            return try? DrinkSyncEvent(
                id: "iphone-log-\(index)", kind: .drink, recordID: "iphone-log-\(index)",
                timestamp: timestamp, milliliters: amount, source: "iphone-shortcut"
            )
        }
    }

    private static func parseShortcutDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        for format in ["yyyy年M月d日 HH:mm:ss", "yyyy年M月d日 HH:mm", "yyyy/M/d HH:mm:ss", "yyyy/M/d HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
