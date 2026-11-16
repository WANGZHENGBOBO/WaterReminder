import Foundation
import WaterCore

struct ICloudDrinkSync {
    let filesystem: DrinkSyncFilesystem
    let migrationBackupDirectory: URL

    static func live(fileManager: FileManager = .default) -> Self {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bobo.WaterReminder", isDirectory: true)
        let cloud = DrinkSyncFilesystem.shortcutSyncDirectory(
            homeDirectory: fileManager.homeDirectoryForCurrentUser
        )
        return Self(
            filesystem: DrinkSyncFilesystem(
                outboxDirectory: applicationSupport.appendingPathComponent("sync-outbox", isDirectory: true),
                syncDirectory: cloud,
                fileManager: fileManager
            ),
            migrationBackupDirectory: applicationSupport.appendingPathComponent(
                "migration-backup",
                isDirectory: true
            )
        )
    }

    func loadEvents() throws -> [DrinkSyncEvent] { try filesystem.loadEvents() }
    func loadDevices() throws -> [LanDeviceRecord] { try filesystem.loadDevices() }
    func publishDevice(_ record: LanDeviceRecord) throws { try filesystem.publishDevice(record) }
    var sharedLogURL: URL { filesystem.sharedLogURL }
    var syncDirectory: URL { filesystem.syncDirectory }
    func ensureSharedLog() throws { try filesystem.ensureSharedLog() }
    func loadSharedEvents() throws -> [DrinkSyncEvent] { try filesystem.loadSharedEvents() }
    func appendShared(_ event: DrinkSyncEvent) throws { try filesystem.appendShared(event) }
    func appendMissingShared(drinks: [Drink]) throws {
        try filesystem.appendMissingShared(drinks: drinks, source: "Mac")
    }
    func migrateLegacyFiles(backupDirectory: URL) throws -> [DrinkSyncEvent] {
        try filesystem.migrateLegacyFiles(backupDirectory: backupDirectory)
    }
    func enqueue(_ event: DrinkSyncEvent) throws { try filesystem.enqueue(event) }
    func enqueueMissing(drinks: [Drink]) throws { try filesystem.enqueueMissing(drinks: drinks, source: "mac") }
    func flushOutbox(sourceDeviceID: String? = nil) throws {
        try filesystem.flushOutbox(sourceDeviceID: sourceDeviceID)
    }
    func publishSettings(goal: Int, serving: Int) throws {
        try filesystem.publishSettings(goal: goal, serving: serving)
    }
    func publishTodaySummary(drinks: [Drink], goal: Int, now: Date) throws {
        try filesystem.publishTodaySummary(drinks: drinks, goal: goal, now: now)
    }
    func todaySummary(drinks: [Drink], goal: Int, now: Date) throws -> DrinkSyncTodaySummary {
        try filesystem.todaySummary(drinks: drinks, goal: goal, now: now)
    }
}
