import Foundation
import WaterCore

struct ICloudDrinkSync {
    let filesystem: DrinkSyncFilesystem

    static func live(fileManager: FileManager = .default) -> Self {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bobo.WaterReminder", isDirectory: true)
        let cloud = DrinkSyncFilesystem.shortcutSyncDirectory(
            homeDirectory: fileManager.homeDirectoryForCurrentUser
        )
        return Self(filesystem: DrinkSyncFilesystem(
            outboxDirectory: applicationSupport.appendingPathComponent("sync-outbox", isDirectory: true),
            syncDirectory: cloud,
            fileManager: fileManager
        ))
    }

    func loadEvents() throws -> [DrinkSyncEvent] { try filesystem.loadEvents() }
    func enqueue(_ event: DrinkSyncEvent) throws { try filesystem.enqueue(event) }
    func enqueueMissing(drinks: [Drink]) throws { try filesystem.enqueueMissing(drinks: drinks, source: "mac") }
    func flushOutbox() throws { try filesystem.flushOutbox() }
    func publishSettings(goal: Int, serving: Int) throws {
        try filesystem.publishSettings(goal: goal, serving: serving)
    }
}
