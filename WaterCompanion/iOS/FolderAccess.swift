import Foundation

enum FolderAccessError: LocalizedError {
    case notSelected
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notSelected:
            "请先选择 iCloud Drive 中的 Sync 文件夹"
        case .permissionDenied:
            "无法访问已选择的 iCloud 文件夹，请重新选择"
        }
    }
}

@MainActor
struct FolderAccess {
    private static let bookmarkKey = "iCloudSyncFolderBookmark.v2"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedURL: URL? {
        try? resolve()
    }

    func save(url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let bookmark = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmark, forKey: Self.bookmarkKey)
    }

    func write(_ event: PhoneDrinkEvent) throws -> URL {
        guard let url = try resolve() else {
            throw FolderAccessError.notSelected
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw FolderAccessError.permissionDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try EventFileWriter.write(
            event,
            to: url.appendingPathComponent("Events", isDirectory: true)
        )
    }

    func readSettings() throws -> CompanionSettings {
        guard let url = try resolve() else {
            return .fallback
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw FolderAccessError.permissionDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let settingsURL = url.appendingPathComponent("settings.json")
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return .fallback
        }
        return try JSONDecoder().decode(
            CompanionSettings.self,
            from: Data(contentsOf: settingsURL)
        )
    }

    func readTodaySummary() throws -> CompanionTodaySummary? {
        guard let url = try resolve() else { return nil }
        guard url.startAccessingSecurityScopedResource() else {
            throw FolderAccessError.permissionDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let summaryURL = url.appendingPathComponent("today-summary.json")
        guard FileManager.default.fileExists(atPath: summaryURL.path) else {
            return nil
        }
        return try JSONDecoder().decode(
            CompanionTodaySummary.self,
            from: Data(contentsOf: summaryURL)
        )
    }

    private func resolve() throws -> URL? {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else {
            return nil
        }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            try save(url: url)
        }
        return url
    }
}
