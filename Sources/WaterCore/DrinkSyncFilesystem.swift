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

public struct DrinkSyncTodayRecord: Codable, Equatable, Sendable {
    public let recordID: String
    public let timestamp: String
    public let displayTime: String
    public let milliliters: Int
    public let deviceShortName: String?
    public let deviceName: String?

    public init(recordID: String, timestamp: String, displayTime: String, milliliters: Int,
                deviceShortName: String? = nil, deviceName: String? = nil) {
        self.recordID = recordID
        self.timestamp = timestamp
        self.displayTime = displayTime
        self.milliliters = milliliters
        self.deviceShortName = deviceShortName
        self.deviceName = deviceName
    }
}

public struct DrinkSyncTodaySummary: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let day: String
    public let goal: Int
    public let total: Int
    public let phoneLogCount: Int
    public let records: [DrinkSyncTodayRecord]

    public init(day: String, goal: Int, total: Int, phoneLogCount: Int,
                records: [DrinkSyncTodayRecord]) {
        self.schemaVersion = 1
        self.day = day
        self.goal = goal
        self.total = total
        self.phoneLogCount = phoneLogCount
        self.records = records
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

    public var sharedLogURL: URL {
        syncDirectory.appendingPathComponent("喝水记录.csv")
    }

    public var devicesDirectory: URL {
        syncDirectory.appendingPathComponent("Devices", isDirectory: true)
    }

    public func publishDevice(_ record: LanDeviceRecord) throws {
        try fileManager.createDirectory(at: devicesDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(record).write(
            to: devicesDirectory.appendingPathComponent("\(safeFileComponent(record.deviceID)).json"),
            options: .atomic
        )
    }

    public func loadDevices() throws -> [LanDeviceRecord] {
        guard fileManager.fileExists(atPath: devicesDirectory.path) else { return [] }
        let files = try fileManager.contentsOfDirectory(
            at: devicesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return files.compactMap { file in
            guard file.pathExtension.lowercased() == "json",
                  let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(LanDeviceRecord.self, from: data)
        }.sorted { $0.deviceID < $1.deviceID }
    }

    public func ensureSharedLog() throws {
        try fileManager.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: sharedLogURL.path) else {
            try Data(DrinkSyncCSV.header.utf8).write(to: sharedLogURL, options: .atomic)
            return
        }
        let existing = (try? String(contentsOf: sharedLogURL, encoding: .utf8)) ?? ""
        let body = existing.hasPrefix("\u{FEFF}") ? String(existing.dropFirst()) : existing
        guard !body.hasPrefix("事件ID,") else { return }
        try Data((DrinkSyncCSV.header + existing).utf8).write(to: sharedLogURL, options: .atomic)
    }

    public func loadSharedEvents() throws -> [DrinkSyncEvent] {
        guard fileManager.fileExists(atPath: sharedLogURL.path),
              let text = try? String(contentsOf: sharedLogURL, encoding: .utf8) else {
            return []
        }
        return DrinkSyncCSV.decode(text)
    }

    public func appendShared(_ event: DrinkSyncEvent) throws {
        try ensureSharedLog()
        guard !(try loadSharedEvents().contains { $0.id == event.id }) else { return }
        let data = Data(try DrinkSyncCSV.encode(event).utf8)
        let handle = try FileHandle(forWritingTo: sharedLogURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    public func appendMissingShared(drinks: [Drink], source: String) throws {
        let represented = Set(try loadSharedEvents().map {
            DrinkSyncMerge.resolvedUUID(for: $0.recordID).uuidString.lowercased()
        })
        let eventsDirectory = syncDirectory.appendingPathComponent("Events", isDirectory: true)
        try fileManager.createDirectory(at: eventsDirectory, withIntermediateDirectories: true)
        for drink in drinks where !represented.contains(drink.id.uuidString.lowercased()) {
            let canonicalSource = drink.source == .phone ? "iphone" : "mac"
            let event = try DrinkSyncEvent(
                id: "\(source.lowercased())-\(drink.id.uuidString)",
                kind: .drink,
                recordID: drink.id.uuidString,
                timestamp: drink.date,
                milliliters: drink.grams,
                source: canonicalSource,
                deviceID: drink.deviceID,
                deviceName: drink.deviceName,
                deviceShortName: drink.deviceShortName
            )
            let prefix = canonicalSource == "iphone"
                ? "phone" : "mac-\(drink.deviceID ?? "unknown")"
            try event.encoded().write(
                to: eventURL("\(prefix)-\(event.id)", in: eventsDirectory),
                options: .atomic
            )
            try appendShared(event)
        }
    }

    public func migrateLegacyFiles(backupDirectory: URL) throws -> [DrinkSyncEvent] {
        try ensureSharedLog()
        for event in try loadEvents() {
            try appendShared(event)
        }

        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let controlFiles = Set(["settings.json", "today-summary.json"])
        let files = try fileManager.contentsOfDirectory(
            at: syncDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for source in files where source.standardizedFileURL.path != sharedLogURL.standardizedFileURL.path {
            let values = try source.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let destination = uniqueBackupURL(for: source.lastPathComponent, in: backupDirectory)
            try fileManager.copyItem(at: source, to: destination)
            guard try Data(contentsOf: source) == Data(contentsOf: destination) else {
                throw CocoaError(.fileWriteUnknown)
            }
            if !controlFiles.contains(source.lastPathComponent) {
                try fileManager.removeItem(at: source)
            }
        }
        return try loadSharedEvents()
    }

    public static func shortcutSyncDirectory(homeDirectory: URL) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents", isDirectory: true)
            .appendingPathComponent("喝水BO～/Sync", isDirectory: true)
    }

    public func loadEvents() throws -> [DrinkSyncEvent] {
        var byID: [String: DrinkSyncEvent] = [:]
        let phoneEventsDirectory = syncDirectory.appendingPathComponent("Events", isDirectory: true)
        for directory in [syncDirectory, outboxDirectory, phoneEventsDirectory]
        where fileManager.fileExists(atPath: directory.path) {
            let isPhoneEventsDirectory =
                directory.standardizedFileURL == phoneEventsDirectory.standardizedFileURL
            let files = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            for file in files where file.lastPathComponent != "settings.json" {
                let fileExtension = file.pathExtension.lowercased()
                guard fileExtension == "json" || (isPhoneEventsDirectory && fileExtension == "txt")
                else { continue }
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
        let represented = Set(try loadEvents().map {
            DrinkSyncMerge.resolvedUUID(for: $0.recordID).uuidString.lowercased()
        })
        for drink in drinks where !represented.contains(drink.id.uuidString.lowercased()) {
            let canonicalSource = drink.source == .phone ? "iphone" : "mac"
            let event = try DrinkSyncEvent(
                kind: .drink,
                recordID: drink.id.uuidString,
                timestamp: drink.date,
                milliliters: drink.grams,
                source: canonicalSource,
                deviceID: drink.deviceID,
                deviceName: drink.deviceName,
                deviceShortName: drink.deviceShortName
            )
            try enqueue(event)
        }
    }

    public func flushOutbox(sourceDeviceID: String? = nil) throws {
        guard fileManager.fileExists(atPath: outboxDirectory.path) else { return }
        let eventsDirectory = syncDirectory.appendingPathComponent("Events", isDirectory: true)
        try fileManager.createDirectory(at: eventsDirectory, withIntermediateDirectories: true)
        let files = try fileManager.contentsOfDirectory(
            at: outboxDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for source in files where source.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: source)
            let event = try DrinkSyncEvent.decode(data)
            let lowerSource = event.source.lowercased()
            let prefix = lowerSource.contains("iphone") || lowerSource.contains("phone")
                ? "phone" : "mac-\(sourceDeviceID ?? event.deviceID ?? "unknown")"
            let eventFile = eventURL("\(prefix)-\(event.id)", in: eventsDirectory)
            try event.encoded().write(to: eventFile, options: .atomic)
            try appendShared(event)
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

    public func todaySummary(drinks: [Drink], goal: Int, now: Date,
                             calendar: Calendar = .current) throws -> DrinkSyncTodaySummary {
        guard (1...10_000).contains(goal) else { throw DrinkSyncError.invalidAmount }
        let today = drinks
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.id.uuidString < $1.id.uuidString
            }
        let iso = ISO8601DateFormatter()
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.dateFormat = "HH:mm"
        let records = today.map {
            DrinkSyncTodayRecord(
                recordID: $0.id.uuidString,
                timestamp: iso.string(from: $0.date),
                displayTime: timeFormatter.string(from: $0.date),
                milliliters: $0.grams,
                deviceShortName: $0.deviceShortName ?? ($0.source == .phone ? "iPH" : "mac"),
                deviceName: $0.deviceName
            )
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return DrinkSyncTodaySummary(
            day: formatter.string(from: now),
            goal: goal,
            total: today.reduce(0) { $0 + $1.grams },
            phoneLogCount: max(
                shortcutLogRowCount(in: syncDirectory),
                sharedPhoneDrinkCount()
            ),
            records: records
        )
    }

    public func publishTodaySummary(drinks: [Drink], goal: Int, now: Date,
                                    calendar: Calendar = .current) throws {
        let summary = try todaySummary(drinks: drinks, goal: goal, now: now, calendar: calendar)
        try fileManager.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(summary).write(
            to: syncDirectory.appendingPathComponent("today-summary.json"),
            options: .atomic
        )
    }

    private func eventURL(_ id: String, in directory: URL) -> URL {
        directory.appendingPathComponent(safeFileComponent(id)).appendingPathExtension("json")
    }

    private func safeFileComponent(_ value: String) -> String {
        let safe = value.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "-" }
        return String(safe).lowercased()
    }

    private func uniqueBackupURL(for filename: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(filename)
        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(filename).\(suffix)")
            suffix += 1
        }
        return candidate
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

    private func shortcutLogRowCount(in directory: URL) -> Int {
        let amountURL = directory.appendingPathComponent("iphone-amounts.txt")
        let timeURL = directory.appendingPathComponent("iphone-times.txt")
        guard let amountText = try? String(contentsOf: amountURL, encoding: .utf8),
              let timeText = try? String(contentsOf: timeURL, encoding: .utf8) else { return 0 }
        return min(
            amountText.split(whereSeparator: \.isNewline).count,
            timeText.split(whereSeparator: \.isNewline).count
        )
    }

    private func sharedPhoneDrinkCount() -> Int {
        (try? loadSharedEvents())?.filter {
            $0.kind == .drink && $0.source.lowercased().contains("iphone")
        }.count ?? 0
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
