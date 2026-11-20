import Foundation
import XCTest
@testable import WaterCompanionCore

final class WaterCompanionCoreTests: XCTestCase {
    func testPayloadDefaultsAndBounds() throws {
        XCTAssertEqual(try WatchDrinkPayload.default().milliliters, 197)
        XCTAssertNoThrow(try WatchDrinkPayload(milliliters: 1))
        XCTAssertNoThrow(try WatchDrinkPayload(milliliters: 2000))
        XCTAssertThrowsError(try WatchDrinkPayload(milliliters: 0))
        XCTAssertThrowsError(try WatchDrinkPayload(milliliters: 2001))
    }

    func testWatchMessageRoundTripAndRejectsMalformedData() throws {
        let payload = try WatchDrinkPayload(milliliters: 250)
        let message = try WatchMessageCodec.encode(payload)
        XCTAssertEqual(try WatchMessageCodec.decode(message), payload)
        XCTAssertThrowsError(try WatchMessageCodec.decode(["payload": Data("{}".utf8)]))
    }

    func testPhoneEventUsesMacSchemaAndWatchIdentity() throws {
        let payload = try WatchDrinkPayload(milliliters: 250)
        let event = PhoneDrinkEvent(payload)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: event.encoded()) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["kind"] as? String, "drink")
        XCTAssertEqual(object["recordID"] as? String, payload.id.uuidString.lowercased())
        XCTAssertEqual(object["milliliters"] as? Int, 250)
        XCTAssertEqual(object["source"] as? String, "iphone-watch")
        XCTAssertEqual(object["deviceShortName"] as? String, "WCH")
        XCTAssertNotNil(object["timestamp"] as? String)
    }

    func testPendingQueueDeduplicatesAndRemoves() throws {
        let first = PhoneDrinkEvent(try WatchDrinkPayload(milliliters: 197))
        var queue = PendingEventQueue()
        XCTAssertTrue(queue.enqueue(first))
        XCTAssertFalse(queue.enqueue(first))
        XCTAssertEqual(queue.events.count, 1)
        XCTAssertEqual(queue.remove(recordID: first.recordID), first)
        XCTAssertTrue(queue.events.isEmpty)
    }

    func testEventWriterCreatesStableJSONFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let event = PhoneDrinkEvent(try WatchDrinkPayload(milliliters: 197))

        let url = try EventFileWriter.write(event, to: directory)

        XCTAssertEqual(url.lastPathComponent, "\(event.recordID).json")
        XCTAssertEqual(try Data(contentsOf: url), try event.encoded())
        XCTAssertEqual(try EventFileWriter.write(event, to: directory), url)
    }

    func testPendingStorageRoundTripAndCorruptFileFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = PendingEventStorage(
            fileURL: directory.appendingPathComponent("pending.json")
        )
        var queue = PendingEventQueue()
        XCTAssertTrue(queue.enqueue(PhoneDrinkEvent(
            try WatchDrinkPayload(milliliters: 197)
        )))

        try storage.save(queue)

        XCTAssertEqual(try storage.load(), queue)
        try Data("{broken}".utf8).write(to: storage.fileURL)
        XCTAssertThrowsError(try storage.load())
    }

    func testPendingWatchPayloadsPersistAndDeduplicate() throws {
        let first = try WatchDrinkPayload(milliliters: 197)
        var pending = PendingWatchPayloads()

        XCTAssertTrue(pending.enqueue(first))
        XCTAssertFalse(pending.enqueue(first))
        XCTAssertEqual(
            try JSONDecoder().decode(
                PendingWatchPayloads.self,
                from: JSONEncoder().encode(pending)
            ),
            pending
        )
        XCTAssertEqual(pending.popFirst(), first)
        XCTAssertNil(pending.popFirst())
    }

    func testCompanionSettingsDecodeMacReminderRules() throws {
        let json = """
        {
          "schemaVersion": 1,
          "goal": 1800,
          "serving": 250,
          "weekday": {"enabled": true, "start": 600, "end": 720, "interval": 30},
          "weekend": {"enabled": false, "start": 660, "end": 1140, "interval": 45},
          "snooze": 15,
          "stopAtGoal": false
        }
        """
        let settings = try JSONDecoder().decode(CompanionSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.serving, 250)
        XCTAssertEqual(settings.snooze, 15)
        XCTAssertEqual(settings.stopAtGoal, false)
        XCTAssertEqual(settings.weekday?.interval, 30)
    }

    func testCompanionSettingsDecodeLegacySettings() throws {
        let json = #"{"schemaVersion":1,"goal":1800,"serving":250}"#
        let settings = try JSONDecoder().decode(CompanionSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.serving, 250)
        XCTAssertNil(settings.weekday)
        XCTAssertNil(settings.weekend)
        XCTAssertEqual(settings.snooze, 10)
        XCTAssertTrue(settings.stopAtGoal)
    }

    func testReminderOccurrencesRespectScheduleAndWeekend() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let mondayAfterStart = calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 16, hour: 10, minute: 0)
        )!
        let settings = CompanionSettings(
            goal: 1800,
            serving: 197,
            weekday: CompanionSchedule(enabled: true, start: 600, end: 720, interval: 30),
            weekend: CompanionSchedule(enabled: false, start: 600, end: 720, interval: 30),
            snooze: 10,
            stopAtGoal: true
        )

        let occurrences = settings.reminderOccurrences(
            after: mondayAfterStart,
            limit: 3,
            calendar: calendar
        )

        XCTAssertEqual(occurrences.count, 3)
        XCTAssertEqual(calendar.component(.hour, from: occurrences[0]), 10)
        XCTAssertEqual(calendar.component(.minute, from: occurrences[0]), 30)
        XCTAssertTrue(occurrences.allSatisfy {
            let weekday = calendar.component(.weekday, from: $0)
            return weekday != 1 && weekday != 7
        })
    }

    func testTodaySummaryOnlySuppressesCurrentDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 18, hour: 12)
        )!
        let yesterday = CompanionTodaySummary(day: "2026-11-17", goal: 1800, total: 1800)
        let today = CompanionTodaySummary(day: "2026-11-18", goal: 1800, total: 1800)

        XCTAssertFalse(yesterday.isCurrentDay(now: now, calendar: calendar))
        XCTAssertTrue(today.isCurrentDay(now: now, calendar: calendar))
    }
}
