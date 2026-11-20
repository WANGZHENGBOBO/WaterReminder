import Foundation

@main
struct InspectWaterEvents {
    static func main() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let filesystem = DrinkSyncFilesystem(
            outboxDirectory: home
                .appendingPathComponent("Library/Application Support/com.bobo.WaterReminder/outbox"),
            syncDirectory: DrinkSyncFilesystem.shortcutSyncDirectory(homeDirectory: home)
        )
        let events = try filesystem.loadEvents()
        print("events=\(events.count)")
        print("contains-16:18=\(events.contains { $0.id.contains("471193718") })")
        let stateURL = home
            .appendingPathComponent("Library/Application Support/com.bobo.WaterReminder/state.json")
        let stateData = try Data(contentsOf: stateURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        struct StoredState: Decodable {
            let drinks: [Drink]
        }
        let state = try decoder.decode(StoredState.self, from: stateData)
        let merged = DrinkSyncMerge.apply(events: events, to: state.drinks)
        let mergedIDs = Set(merged.map(\.id))
        print("stored=\(state.drinks.count) merged=\(merged.count)")
        print("contains-merged-16:18=\(mergedIDs.contains(DrinkSyncMerge.resolvedUUID(for: "watch-20261118161827-471193718")))")
        if let target = events.first(where: { $0.id.contains("471193718") }) {
            let targetID = DrinkSyncMerge.resolvedUUID(for: target.recordID)
            print("target", target.kind, target.recordID, target.milliliters ?? -1, targetID, mergedIDs.contains(targetID))
            for event in events where DrinkSyncMerge.resolvedUUID(for: event.recordID) == targetID {
                print("same-id-event", event.kind, event.id, event.recordID)
            }
        }
        for event in events.suffix(4) {
            print(event.timestamp, event.milliliters ?? -1, event.source, event.id)
        }
    }
}
