import Foundation
import CoreGraphics
import WaterCore

private func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line)
}
private func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, file: file, line: line) }
private func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(!value, file: file, line: line) }
private func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value == nil, file: file, line: line) }

@main
final class ReminderTests {
    static func main() throws {
        let suite = ReminderTests()
        suite.testDefaultSlotsAndEndBoundary()
        suite.testWeekendAndDisabledRules()
        suite.testPauseAndCompletionOnlySkipTheirDay()
        suite.testSnoozeRespectsEndAndMidnight()
        try suite.testTotalsRolloverAndPersistence()
        suite.testInvalidSettings()
        suite.testMilestonesFollowConfiguredGoal()
        suite.testMilestoneCanReplayAfterUndo()
        suite.testMilestoneUpdateUsesHighestCrossedLevel()
        suite.testMilestoneReconciliationFindsMissedLevel()
        try suite.testFreshInstallEnablesICloudSync()
        suite.testDrinkSyncReadiness()
        try suite.testWaveAppearanceAndLegacySettings()
        try suite.testWaveOpacityPersistsAndLegacyDefaults()
        try suite.testFishCountSettingsAndIndependentMotion()
        try suite.testAppearanceThemeDefaultsAndLegacySettings()
        suite.testColorPickerHexConversion()
        suite.testWaveLayerVariation()
        suite.testWaterMotionHasVariedWavesAndFishPath()
        suite.testFishFollowsTapOnlyInWater()
        suite.testFishSwimmingPace()
        suite.testFishPaceVariesSmoothly()
        suite.testFishLeapEligibility()
        suite.testConsecutiveWaterTaps()
        suite.testFishLeapArcAndLanding()
        suite.testFishPerspectiveAndTailBeat()
        suite.testFishWeavesThroughDigits()
        suite.testFishRestAndPeckOverride()
        suite.testDailyCardCalendarAndPhrases()
        suite.testHistoryBucketsAndIntensity()
        suite.testHistoryCellLabelsAmountsWithoutClutteringYear()
        suite.testHistoryExportRange()
        try suite.testDrinkSourcePersistenceAndMerge()
        suite.testWelcomeEligibility()
        suite.testSettingsSaveClosesOnlyOnSuccess()
        suite.testPopoverKeepsTopEdgeWhenContentHeightChanges()
        suite.testPopoverUsesScreenContainingMenuBarButton()
        suite.testAutomaticLoginItemPolicy()
        try suite.testDrinkSyncProtocolAndMerge()
        try suite.testDrinkSyncFilesystemAndOutbox()
        try suite.testDrinkSyncTodaySummary()
        try suite.testPhoneLogsReachMacSummary()
        try suite.testSharedCSVPhoneEventsAdvanceSummaryCursor()
        try suite.testSharedCSVCodec()
        try suite.testSharedCSVFilesystemAndMigration()
        try suite.testMigrationSkipsEventsDirectory()
        try suite.testAppendMissingSharedRecognizesResolvedRecordIDs()
        try suite.testAppendMissingSharedWritesEventFile()
        try suite.testSharedCSVReconciliation()
        try suite.testDeviceFilesAreIndependent()
        try suite.testMalformedDeviceFileIsIgnored()
        suite.testDeviceShortNamesAreCompactAndUnique()
        suite.testLANHTTPParser()
        try suite.testLANDrinkServer()
        suite.testLANEndpointSelection()
        try suite.testLANDeviceSelection()
        try suite.testLANTokenPersistence()
        suite.testCustomMacSuffixValidation()
        try suite.testRemoteDuplicateSuffixResolvesDeterministically()
        try suite.testEventsPreserveDeviceIdentity()
        try suite.testSimultaneousMacEventsBothSurvive()
        try suite.testSameEventFromTwoDevicesCountsOnce()
        try suite.testMacEventsSurviveCSVConflict()
        suite.testLegacySourceStillNormalizes()
        try suite.testLANPreferencesCompatibility()
        suite.testDrinkDeviceDisplayLabel()
        suite.testHistoryCSVIncludesDeviceColumns()
        try suite.testRenamingDeviceUpdatesMatchingHistory()
        suite.testReminderNotificationAutoDismissDelay()
        print("PASS: 69 groups — schedule, weekend, pause/goal, snooze, totals/persistence, validation, milestones, undo/replay, milestone display, milestone reconciliation, wave settings, wave opacity, fish count, appearance theme, color picker, wave variation, water motion, fish interaction, fish pace, fish leap rules, triple-tap leap, fish leap arc, fish perspective, fish weave, fish rest/peck, daily card, history/history labels, export/device columns, drink source, welcome, settings close, popover anchor, screen placement, automatic login, iCloud sync protocol, iCloud filesystem, iPhone today summary, phone-to-Mac summary, shared CSV phone cursor, shared CSV, shared CSV filesystem, migration directories, resolved record IDs, shared CSV reconciliation, device files, LAN HTTP server, address/device selection, token persistence, custom suffix, simultaneous Mac events, origin identity, LAN preferences, shared event backup, reminder auto-dismiss")
    }
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    func testDefaultSlotsAndEndBoundary() {
        let p = Preferences()
        XCTAssertEqual(ReminderSchedule.next(after: date(22, 10), preferences: p, calendar: calendar), date(22, 11))
        XCTAssertEqual(ReminderSchedule.next(after: date(22, 11), preferences: p, calendar: calendar), date(22, 11, 45))
        XCTAssertEqual(ReminderSchedule.next(after: date(22, 18, 30), preferences: p, calendar: calendar), date(23, 11))
    }
    func testWeekendAndDisabledRules() {
        var p = Preferences()
        p.weekend.start = 12 * 60
        XCTAssertEqual(ReminderSchedule.next(after: date(23, 20), preferences: p, calendar: calendar), date(24, 12))
        p.weekend.enabled = false
        XCTAssertEqual(ReminderSchedule.next(after: date(23, 20), preferences: p, calendar: calendar), date(26, 11))
        p.weekday.enabled = false
        XCTAssertNil(ReminderSchedule.next(after: date(23, 20), preferences: p, calendar: calendar))
    }
    func testPauseAndCompletionOnlySkipTheirDay() {
        let p = Preferences()
        XCTAssertEqual(ReminderSchedule.next(after: date(22, 12), preferences: p, pausedDay: date(22, 9), calendar: calendar), date(23, 11))
        XCTAssertEqual(ReminderSchedule.next(after: date(22, 12), preferences: p, completedDay: date(22, 9), calendar: calendar), date(23, 11))
    }
    func testSnoozeRespectsEndAndMidnight() {
        XCTAssertTrue(ReminderSchedule.canSnooze(to: date(22, 18, 59), from: date(22, 18, 49), preferences: Preferences(), calendar: calendar))
        XCTAssertFalse(ReminderSchedule.canSnooze(to: date(22, 19), from: date(22, 18, 50), preferences: Preferences(), calendar: calendar))
        XCTAssertFalse(ReminderSchedule.canSnooze(to: date(23, 11), from: date(22, 18), preferences: Preferences(), calendar: calendar))
    }
    func testTotalsRolloverAndPersistence() throws {
        var state = SavedState()
        state.drinks = (0..<9).map { _ in Drink(date: date(22, 12), grams: 197) }
        XCTAssertEqual(state.total(on: date(22, 23), calendar: calendar), 1773)
        state.drinks.append(Drink(date: date(22, 13), grams: 197))
        XCTAssertEqual(state.total(on: date(22, 23), calendar: calendar), 1970)
        XCTAssertEqual(state.total(on: date(23, 0), calendar: calendar), 0)
        let restored = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.drinks, state.drinks)
        XCTAssertEqual(restored.preferences, state.preferences)
        XCTAssertNil(restored.celebratedMilestones)
    }
    func testInvalidSettings() {
        var p = Preferences()
        p.goal = 0
        XCTAssertFalse(p.isValid)
        p.goal = 1800
        p.weekday.end = p.weekday.start
        XCTAssertFalse(p.isValid)
    }
    func testMilestonesFollowConfiguredGoal() {
        XCTAssertEqual(Milestones.crossed(from: 0, to: 197, goal: 300, alreadyCelebrated: []), [60])
        XCTAssertEqual(Milestones.crossed(from: 197, to: 394, goal: 300, alreadyCelebrated: [60]), [80, 100])
        XCTAssertEqual(Milestones.crossed(from: 394, to: 591, goal: 300, alreadyCelebrated: [60, 80, 100]), [])
        XCTAssertEqual(Milestones.crossed(from: 985, to: 1182, goal: 1800, alreadyCelebrated: []), [60])
        XCTAssertEqual(Milestones.crossed(from: 1773, to: 1970, goal: 1800, alreadyCelebrated: [60, 80]), [100])
    }
    func testMilestoneCanReplayAfterUndo() {
        // 985/1800 is below 60%; old persisted flags must not suppress a new crossing.
        XCTAssertEqual(Milestones.crossed(from: 985, to: 1182, goal: 1800,
                                           alreadyCelebrated: [60, 80, 100]), [60])
    }
    func testMilestoneUpdateUsesHighestCrossedLevel() {
        let first = Milestones.update(celebrated: [], from: 985, to: 1182, goal: 1800)
        XCTAssertEqual(first.celebrated, [60])
        XCTAssertEqual(first.triggered, 60)

        let repeated = Milestones.update(celebrated: first.celebrated, from: 1182, to: 1379, goal: 1800)
        XCTAssertEqual(repeated.celebrated, [60])
        XCTAssertNil(repeated.triggered)

        let jumped = Milestones.update(celebrated: first.celebrated, from: 1182, to: 1800, goal: 1800)
        XCTAssertEqual(jumped.celebrated, [60, 80, 100])
        XCTAssertEqual(jumped.triggered, 100)
    }
    func testMilestoneReconciliationFindsMissedLevel() {
        let missed = Milestones.reconcile(celebrated: [60], total: 1576, goal: 1800)
        XCTAssertEqual(missed.celebrated, [60, 80])
        XCTAssertEqual(missed.triggered, 80)

        let settled = Milestones.reconcile(celebrated: missed.celebrated, total: 1576, goal: 1800)
        XCTAssertEqual(settled.celebrated, [60, 80])
        XCTAssertNil(settled.triggered)
    }
    func testFreshInstallEnablesICloudSync() throws {
        XCTAssertTrue(Preferences().iCloudSyncEnabled == true)
        let oldJSON = """
        {"weekday":{"enabled":true,"start":660,"end":1140,"interval":45},
         "weekend":{"enabled":true,"start":660,"end":1140,"interval":45},
         "serving":197,"goal":1800,"snooze":10,"stopAtGoal":true}
        """
        let legacy = try JSONDecoder().decode(Preferences.self, from: Data(oldJSON.utf8))
        XCTAssertNil(legacy.iCloudSyncEnabled)
    }
    func testDrinkSyncReadiness() {
        XCTAssertEqual(
            DrinkSyncReadiness.classify(
                enabled: false, phoneEventCount: 0, syncedAt: date(23, 9)
            ),
            .disabled
        )
        XCTAssertEqual(
            DrinkSyncReadiness.classify(
                enabled: true, phoneEventCount: 0, syncedAt: date(23, 9)
            ),
            .waiting
        )
        XCTAssertEqual(
            DrinkSyncReadiness.classify(
                enabled: true,
                phoneEventCount: 2,
                syncedAt: date(23, 10)
            ),
            .healthy(date(23, 10))
        )
    }
    func testWaveAppearanceAndLegacySettings() throws {
        let oldJSON = """
        {"weekday":{"enabled":true,"start":660,"end":1140,"interval":45},
         "weekend":{"enabled":true,"start":660,"end":1140,"interval":45},
         "serving":197,"goal":1800,"snooze":10,"stopAtGoal":true}
        """
        var legacy = try JSONDecoder().decode(Preferences.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(legacy.waveAppearance ?? WaveAppearance(), WaveAppearance())
        XCTAssertFalse(legacy.iCloudSyncEnabled ?? false)
        legacy.iCloudSyncEnabled = true
        var appearance = WaveAppearance()
        appearance.height = 7
        appearance.speed = 1.5
        appearance.baseHex = "#12ABEF"
        appearance.frontHex = "#ffee22"
        legacy.waveAppearance = appearance
        XCTAssertTrue(legacy.isValid)
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(restored.waveAppearance, appearance)
        XCTAssertTrue(restored.iCloudSyncEnabled ?? false)
        appearance.frontHex = "#XYZ123"
        legacy.waveAppearance = appearance
        XCTAssertFalse(legacy.isValid)
    }
    func testWaveOpacityPersistsAndLegacyDefaults() throws {
        let oldWave = Data(##"{"height":3,"speed":0.8,"baseHex":"#0080FF","frontHex":"#FFFFFF"}"##.utf8)
        let legacy = try JSONDecoder().decode(WaveAppearance.self, from: oldWave)
        let defaultJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        XCTAssertEqual(defaultJSON["baseOpacity"] as? Double, 1)
        XCTAssertEqual(defaultJSON["frontOpacity"] as? Double, 0.16)

        let customWave = Data(##"{"height":3,"speed":0.8,"baseHex":"#0080FF","frontHex":"#FFFFFF","baseOpacity":0.45,"frontOpacity":0.7}"##.utf8)
        let custom = try JSONDecoder().decode(WaveAppearance.self, from: customWave)
        let customJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(custom)) as! [String: Any]
        XCTAssertEqual(customJSON["baseOpacity"] as? Double, 0.45)
        XCTAssertEqual(customJSON["frontOpacity"] as? Double, 0.7)
        XCTAssertTrue(custom.isValid)

        let invalidWave = Data(##"{"height":3,"speed":0.8,"baseHex":"#0080FF","frontHex":"#FFFFFF","baseOpacity":1.2,"frontOpacity":0.7}"##.utf8)
        XCTAssertFalse(try JSONDecoder().decode(WaveAppearance.self, from: invalidWave).isValid)
    }
    func testFishCountSettingsAndIndependentMotion() throws {
        let oldWave = Data(##"{"height":3,"speed":0.8,"baseHex":"#0080FF","frontHex":"#FFFFFF"}"##.utf8)
        let legacy = try JSONDecoder().decode(WaveAppearance.self, from: oldWave)
        XCTAssertEqual(legacy.fishCount, 1)
        var appearance = legacy
        appearance.fishCount = 4
        XCTAssertEqual(try JSONDecoder().decode(WaveAppearance.self,
                       from: JSONEncoder().encode(appearance)).fishCount, 4)
        appearance.fishCount = 7
        XCTAssertFalse(appearance.isValid)
        let first = WaterMotion.fish(at: 8, level: 0.65, index: 0)!
        let second = WaterMotion.fish(at: 8, level: 0.65, index: 1)!
        XCTAssertTrue(hypot(first.x - second.x, first.y - second.y) > 0.05)
    }
    func testAppearanceThemeDefaultsAndLegacySettings() throws {
        XCTAssertEqual(Preferences().appearanceTheme, .classicBlue)

        let oldJSON = """
        {"weekday":{"enabled":true,"start":660,"end":1140,"interval":45},
         "weekend":{"enabled":true,"start":660,"end":1140,"interval":45},
         "serving":197,"goal":1800,"snooze":10,"stopAtGoal":true}
        """
        let legacy = try JSONDecoder().decode(Preferences.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(legacy.appearanceTheme, .classicBlue)

        var preferences = Preferences()
        preferences.appearanceTheme = .obsidian
        let restored = try JSONDecoder().decode(
            Preferences.self, from: JSONEncoder().encode(preferences)
        )
        XCTAssertEqual(restored.appearanceTheme, .obsidian)

        var wave = WaveAppearance()
        wave.height = 6.5
        wave.speed = 1.5
        wave.fishCount = 3
        let obsidianWave = AppearanceTheme.obsidian.applying(to: wave)
        XCTAssertEqual(obsidianWave.baseHex, "#090A0C")
        XCTAssertEqual(obsidianWave.frontHex, "#666970")
        XCTAssertEqual(obsidianWave.baseOpacity, 1)
        XCTAssertEqual(obsidianWave.frontOpacity, 0.38)
        XCTAssertEqual(obsidianWave.height, 6.5)
        XCTAssertEqual(obsidianWave.speed, 1.5)
        XCTAssertEqual(obsidianWave.fishCount, 3)

        let classicWave = AppearanceTheme.classicBlue.applying(to: obsidianWave)
        XCTAssertEqual(classicWave.baseHex, WaveAppearance().baseHex)
        XCTAssertEqual(classicWave.frontHex, WaveAppearance().frontHex)
        XCTAssertEqual(classicWave.baseOpacity, WaveAppearance().baseOpacity)
        XCTAssertEqual(classicWave.frontOpacity, WaveAppearance().frontOpacity)
    }
    func testColorPickerHexConversion() {
        XCTAssertEqual(WaveAppearance.hex(red: 0, green: 128.0 / 255, blue: 1), "#0080FF")
        XCTAssertEqual(WaveAppearance.hex(red: 1, green: 1, blue: 1), "#FFFFFF")
        XCTAssertEqual(WaveAppearance.hex(red: -0.5, green: 0.5, blue: 2), "#0080FF")
    }
    func testWaveLayerVariation() {
        var appearance = WaveAppearance()
        appearance.height = 4
        appearance.speed = 1.2
        XCTAssertTrue(abs(appearance.frontHeight - 3.4) < 0.0001)
        XCTAssertTrue(abs(appearance.frontSpeed - 1.38) < 0.0001)
    }
    func testWaterMotionHasVariedWavesAndFishPath() {
        let left = WaterMotion.waveScale(position: 0.1, phase: 0)
        let right = WaterMotion.waveScale(position: 0.6, phase: 0)
        XCTAssertTrue((0.6...1.4).contains(left))
        XCTAssertTrue((0.6...1.4).contains(right))
        XCTAssertTrue(abs(left - right) > 0.01)
        XCTAssertTrue(abs(left - WaterMotion.waveScale(position: 0.1, phase: 1)) > 0.01)

        XCTAssertNil(WaterMotion.fish(at: 0, level: 0.29))
        let start = WaterMotion.fish(at: 0, level: 0.3)!
        let later = (1...36).map { WaterMotion.fish(at: Double($0), level: 0.6)! }
        XCTAssertTrue((0...1).contains(start.x) && (0.7...1).contains(start.y))
        XCTAssertTrue(later.map(\.x).max()! - later.map(\.x).min()! > 0.2)
        XCTAssertTrue(later.contains { !$0.facingRight } && later.contains { $0.facingRight })
        XCTAssertTrue(later.map(\.y).max()! - later.map(\.y).min()! > 0.02)
    }
    func testFishFollowsTapOnlyInWater() {
        let surface = WaterMotion.surfaceY(x: 100, width: 200, height: 200, level: 0.6,
                                           phase: 0, amplitude: 3)
        XCTAssertNil(WaterMotion.target(x: 100, y: surface - 1, width: 200, height: 200,
                                        level: 0.6, phase: 0, amplitude: 3))
        XCTAssertNil(WaterMotion.target(x: 100, y: 190, width: 200, height: 200,
                                        level: 0.29, phase: 0, amplitude: 3))
        let target = WaterMotion.target(x: 160, y: 150, width: 200, height: 200,
                                        level: 0.6, phase: 0, amplitude: 3)!
        let start = WaterMotion.fish(at: 0, level: 0.6)!
        let command = FishCommand(start: start, targetX: target.x, targetY: target.y, startedAt: 0)
        let chasing = WaterMotion.fish(at: 0.7, level: 0.6, command: command)!
        XCTAssertTrue(chasing.x > start.x)
        let arrivalTime = WaterMotion.travelDuration(from: start, toX: target.x, y: target.y)
        let arrived = WaterMotion.fish(at: arrivalTime, level: 0.6, command: command)!
        XCTAssertTrue(abs(arrived.x - target.x) < 0.01)
        XCTAssertTrue(abs(arrived.y - target.y) < 0.01)
        let afterArrival = WaterMotion.fish(at: arrivalTime + 0.6, level: 0.6, command: command)!
        XCTAssertTrue(hypot(afterArrival.x - arrived.x, afterArrival.y - arrived.y) > 0.005)
        let nearArrival = WaterMotion.fish(at: arrivalTime - 0.01, level: 0.6, command: command)!
        XCTAssertTrue(hypot(nearArrival.x - arrived.x, nearArrival.y - arrived.y) < 0.01)
    }
    func testFishSwimmingPace() {
        let start = WaterMotion.fish(at: 0, level: 0.7)!
        let next = WaterMotion.fish(at: 1, level: 0.7)!
        XCTAssertTrue(hypot(next.x - start.x, next.y - start.y) < 0.07)
        XCTAssertTrue(WaterMotion.travelDuration(from: start, toX: 0.9, y: 0.8) > 3.5)
    }
    func testFishPaceVariesSmoothly() {
        let early = WaterMotion.roamingTime(at: 4) - WaterMotion.roamingTime(at: 3)
        let later = WaterMotion.roamingTime(at: 17) - WaterMotion.roamingTime(at: 16)
        XCTAssertTrue(early > 0 && later > 0)
        XCTAssertTrue(abs(early - later) > 0.1)
    }
    func testFishLeapEligibility() {
        XCTAssertFalse(WaterMotion.canLeap(level: 0.29, fishCount: 1, reduceMotion: false,
                                           todayCount: 0, secondsSinceLast: 8_000))
        XCTAssertTrue(WaterMotion.canLeap(level: 0.98, fishCount: 1, reduceMotion: false,
                                          todayCount: 0, secondsSinceLast: 8_000))
        XCTAssertFalse(WaterMotion.canLeap(level: 1, fishCount: 1, reduceMotion: false,
                                           todayCount: 0, secondsSinceLast: 8_000))
        XCTAssertFalse(WaterMotion.canLeap(level: 0.6, fishCount: 0, reduceMotion: false,
                                           todayCount: 0, secondsSinceLast: 8_000))
        XCTAssertFalse(WaterMotion.canLeap(level: 0.6, fishCount: 1, reduceMotion: true,
                                           todayCount: 0, secondsSinceLast: 8_000))
        XCTAssertFalse(WaterMotion.canLeap(level: 0.6, fishCount: 1, reduceMotion: false,
                                           todayCount: 3, secondsSinceLast: 8_000))
        XCTAssertFalse(WaterMotion.canLeap(level: 0.6, fishCount: 1, reduceMotion: false,
                                           todayCount: 1, secondsSinceLast: 7_199))
        XCTAssertTrue(WaterMotion.canLeap(level: 0.6, fishCount: 1, reduceMotion: false,
                                          todayCount: 1, secondsSinceLast: 7_200))
    }
    func testConsecutiveWaterTaps() {
        var taps = ConsecutiveTapTracker(maxInterval: 0.65, requiredCount: 3)
        XCTAssertFalse(taps.register(at: 1.0))
        XCTAssertFalse(taps.register(at: 1.4))
        XCTAssertTrue(taps.register(at: 1.8))
        XCTAssertFalse(taps.register(at: 2.0))
        XCTAssertFalse(taps.register(at: 3.0))
        XCTAssertFalse(taps.register(at: 3.4))
        XCTAssertTrue(taps.register(at: 3.8))
    }
    func testFishLeapArcAndLanding() {
        let start = WaterMotion.fish(at: 0, level: 0.6)!
        let low = FishLeap(start: start, startedAt: 0, direction: 1, high: false, index: 0)
        let high = FishLeap(start: start, startedAt: 0, direction: 1, high: true, index: 0)
        let beginning = WaterMotion.leapFrame(low, at: 0, level: 0.6, width: 314, height: 218,
                                              phase: 0, amplitude: 3)!
        XCTAssertTrue(abs(beginning.x - start.x) < 0.0001)
        XCTAssertTrue(abs(beginning.y - start.y) < 0.0001)
        let apex = WaterMotion.leapFrame(low, at: 1.15, level: 0.6, width: 314, height: 218,
                                         phase: 0, amplitude: 3)!
        let highApex = WaterMotion.leapFrame(high, at: 1.3, level: 0.6, width: 314, height: 218,
                                             phase: 0, amplitude: 3)!
        let surface = WaterMotion.surfaceY(x: apex.x * 314, width: 314, height: 218,
                                           level: 0.6, phase: 0, amplitude: 3) / 218
        XCTAssertTrue(apex.y < surface)
        XCTAssertTrue(highApex.y < apex.y)
        let splash = WaterMotion.leapFrame(low, at: 1.8, level: 0.6, width: 314, height: 218,
                                           phase: 0, amplitude: 3)!
        XCTAssertTrue(splash.splash > 0)
        XCTAssertNil(WaterMotion.leapFrame(low, at: 3, level: 0.6, width: 314, height: 218,
                                           phase: 0, amplitude: 3))
    }
    func testPopoverKeepsTopEdgeWhenContentHeightChanges() {
        let anchor = PopoverAnchor(frame: CGRect(x: 400, y: 300, width: 350, height: 500))
        XCTAssertEqual(anchor.origin(for: CGSize(width: 350, height: 700)).y, 100)
        XCTAssertEqual(anchor.origin(for: CGSize(width: 350, height: 400)).y, 400)
        XCTAssertEqual(anchor.origin(for: CGSize(width: 350, height: 400)).x, 400)
        let menuBarAnchor = PopoverAnchor(frame: CGRect(x: 400, y: 300, width: 350, height: 500), topY: 900)
        XCTAssertEqual(menuBarAnchor.origin(for: CGSize(width: 350, height: 400)).y, 500)
        let recenteredBySystem = CGRect(x: 400, y: 350, width: 350, height: 400)
        XCTAssertEqual(menuBarAnchor.correctedFrame(recenteredBySystem).origin.y, 500)
        let button = CGRect(x: 500, y: 900, width: 75, height: 24)
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 900)
        let short = PopoverAnchor.panelFrame(button: button, content: CGSize(width: 350, height: 400), visible: visible)
        let tall = PopoverAnchor.panelFrame(button: button, content: CGSize(width: 350, height: 600), visible: visible)
        XCTAssertEqual(short.maxY, button.minY)
        XCTAssertEqual(tall.maxY, button.minY)
        XCTAssertEqual(short.origin.x, tall.origin.x)
        XCTAssertEqual(tall.origin.y, short.origin.y - 200)
        let right = PopoverAnchor.panelFrame(button: CGRect(x: 980, y: 900, width: 20, height: 24),
                                             content: CGSize(width: 350, height: 400), visible: visible)
        XCTAssertEqual(right.maxX, 1000)
        let overflow = PopoverAnchor.panelFrame(button: button, content: CGSize(width: 350, height: 1400), visible: visible)
        XCTAssertEqual(overflow.maxY, button.minY)
        XCTAssertEqual(overflow.minY, visible.minY)
        XCTAssertEqual(overflow.height, visible.height)
    }
    func testPopoverUsesScreenContainingMenuBarButton() {
        let main = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let displayAbove = CGRect(x: -125, y: -1296, width: 2304, height: 1296)
        let menuBarButton = CGRect(x: 1040, y: 1084, width: 70, height: 24)
        XCTAssertEqual(
            PopoverAnchor.screenContaining(menuBarButton, screens: [displayAbove, main]),
            main
        )
        XCTAssertNil(PopoverAnchor.screenContaining(
            CGRect(x: 3000, y: 400, width: 20, height: 24),
            screens: [displayAbove, main]
        ))
    }
    func testAutomaticLoginItemPolicy() {
        XCTAssertTrue(LaunchAtLoginPolicy.shouldRegister(
            preference: .automatic,
            status: .notRegistered
        ))
        XCTAssertTrue(LaunchAtLoginPolicy.shouldRegister(
            preference: .automatic,
            status: .unavailable
        ))
        XCTAssertFalse(LaunchAtLoginPolicy.shouldRegister(
            preference: .automatic,
            status: .enabled
        ))
        XCTAssertFalse(LaunchAtLoginPolicy.shouldRegister(
            preference: .disabled,
            status: .notRegistered
        ))
        XCTAssertFalse(LaunchAtLoginPolicy.shouldRegister(
            preference: .automatic,
            status: .requiresApproval
        ))
    }
    func testFishPerspectiveAndTailBeat() {
        let near = WaterMotion.fish(at: 0, level: 0.7)!
        let far = (1...36).map { WaterMotion.fish(at: Double($0), level: 0.7)! }
            .max { abs($0.scale - near.scale) < abs($1.scale - near.scale) }!
        XCTAssertTrue((0.6...1.3).contains(near.scale))
        XCTAssertTrue((0.6...1.3).contains(far.scale))
        XCTAssertTrue(abs(near.scale - far.scale) > 0.08)
        XCTAssertEqual(WaterMotion.tailAngle(at: 0, chasing: false), 0)
        XCTAssertTrue(abs(WaterMotion.tailAngle(at: 0.15, chasing: false)) > 5)
        XCTAssertTrue(abs(WaterMotion.tailAngle(at: 0.15, chasing: true)
                          - WaterMotion.tailAngle(at: 0.15, chasing: false)) > 1)
        XCTAssertEqual(WaterMotion.tailSpread(angle: 0), 1)
        XCTAssertTrue(WaterMotion.tailSpread(angle: 20) < 0.8)
        XCTAssertEqual(WaterMotion.pitch(dx: 0.1, dy: -0.1), -18)
        XCTAssertEqual(WaterMotion.pitch(dx: -0.1, dy: -0.1), 18)
    }
    func testFishWeavesThroughDigits() {
        XCTAssertEqual(WaterMotion.frontDigitIndices(count: 4), [0, 2])
        XCTAssertEqual(WaterMotion.frontDigitIndices(count: 1), [0])
        XCTAssertEqual(WaterMotion.frontDigitIndices(count: 0), [])
        XCTAssertEqual(WaterMotion.frontGlyphMask(for: "1,379"), [true, false, false, true, false])
    }
    func testFishRestAndPeckOverride() {
        XCTAssertEqual(WaterMotion.behavior(at: 51, index: 0, hasCommand: false), .rest)
        XCTAssertEqual(WaterMotion.behavior(at: 69, index: 0, hasCommand: false), .peck)
        XCTAssertEqual(WaterMotion.behavior(at: 69, index: 0, hasCommand: true), .swim)
        let resting = WaterMotion.fish(at: 52, level: 0.75)!
        let restingLater = WaterMotion.fish(at: 53, level: 0.75)!
        XCTAssertTrue(hypot(resting.x - restingLater.x, resting.y - restingLater.y) < 0.015)
        let peck = WaterMotion.fish(at: 70, level: 0.75)!
        XCTAssertTrue((0.18...0.3).contains(peck.x))
        let before = WaterMotion.fish(at: 66.99, level: 0.75)!
        let after = WaterMotion.fish(at: 67.01, level: 0.75)!
        XCTAssertTrue(hypot(before.x - after.x, before.y - after.y) < 0.01)
    }
    func testDailyCardCalendarAndPhrases() {
        let today = DailyCardText.forDate(date(23, 12), calendar: calendar)
        XCTAssertEqual(today.dateLine, "10月23日 周五")
        XCTAssertEqual(today.lunarLine, "农历九月十四")
        XCTAssertEqual(DailyCardText.forDate(date(24, 12), calendar: calendar).solarTerm, "霜降")
        XCTAssertEqual(DailyCardText.forDate(date(7, 12), calendar: calendar).solarTerm, "秋分")
        XCTAssertEqual(DailyCardText.phrases.count, 100)
        XCTAssertEqual(Set(DailyCardText.phrases).count, 100)
        XCTAssertTrue(DailyCardText.phrases.allSatisfy { $0.count <= 16 })
        XCTAssertEqual(today.phrase, DailyCardText.forDate(date(23, 18), calendar: calendar).phrase)
        let nextHundred = (0..<100).map { offset in
            DailyCardText.forDate(calendar.date(byAdding: .day, value: offset, to: date(23, 12))!, calendar: calendar).phrase
        }
        XCTAssertEqual(Set(nextHundred).count, 100)
    }
    func testHistoryBucketsAndIntensity() {
        let drinks = [Drink(date: date(22, 12), grams: 197), Drink(date: date(23, 9), grams: 197),
                      Drink(date: date(23, 9, 30), grams: 197)]
        let day = HistoryReport.cells(drinks: drinks, period: .day, anchor: date(23, 12),
                                      goal: 1800, serving: 197, calendar: calendar)
        XCTAssertEqual(day.count, 24)
        XCTAssertEqual(day[9].grams, 394)
        XCTAssertEqual(day[9].count, 2)
        XCTAssertEqual(day[9].intensity, 5)
        XCTAssertEqual(day[10].intensity, 0)
        let week = HistoryReport.cells(drinks: drinks, period: .week, anchor: date(23, 12),
                                       goal: 1800, serving: 197, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(calendar.component(.day, from: week[0].start), 19)
        XCTAssertEqual(week[4].grams, 394)
        XCTAssertEqual(week[4].intensity, 2)
        let month = HistoryReport.cells(drinks: drinks, period: .month, anchor: date(23, 12),
                                        goal: 1800, serving: 197, calendar: calendar)
        XCTAssertTrue(month.count == 35 || month.count == 42)
        XCTAssertEqual(month.filter { $0.inPeriod && $0.grams > 0 }.count, 2)
        let year = HistoryReport.cells(drinks: drinks, period: .year, anchor: date(23, 12),
                                       goal: 1800, serving: 197, calendar: calendar)
        XCTAssertEqual(year.count, 371)
        XCTAssertEqual(year.filter { $0.inPeriod && $0.grams > 0 }.count, 2)
    }
    func testHistoryCellLabelsAmountsWithoutClutteringYear() {
        XCTAssertEqual(HistoryReport.cellLabel(grams: 394, period: .day), "394")
        XCTAssertEqual(HistoryReport.cellLabel(grams: 1800, period: .week), "1800")
        XCTAssertEqual(HistoryReport.cellLabel(grams: 250, period: .month), "250")
        XCTAssertNil(HistoryReport.cellLabel(grams: 0, period: .month))
        XCTAssertNil(HistoryReport.cellLabel(grams: 1800, period: .year))
    }
    func testHistoryExportRange() {
        let drinks = [Drink(date: date(21, 23), grams: 150), Drink(date: date(22, 8), grams: 197),
                      Drink(date: date(23, 18), grams: 250), Drink(date: date(24, 0), grams: 300)]
        let csv = HistoryReport.csv(drinks: drinks, from: date(22, 12), through: date(23, 12), calendar: calendar)
        XCTAssertTrue(csv?.hasPrefix("\u{FEFF}日期,时间,喝水量(ml),设备,完整设备名,来源\r\n") == true)
        XCTAssertTrue(csv?.contains("2026-10-22,08:00:00,197,,,mac\r\n") == true)
        XCTAssertTrue(csv?.contains("2026-10-23,18:00:00,250,,,mac\r\n") == true)
        XCTAssertFalse(csv?.contains("150") == true)
        XCTAssertFalse(csv?.contains("300") == true)
        XCTAssertNil(HistoryReport.csv(drinks: drinks, from: date(20, 12), through: date(20, 12), calendar: calendar))
        XCTAssertNil(HistoryReport.csv(drinks: drinks, from: date(23, 12), through: date(22, 12), calendar: calendar))
    }
    func testDrinkSourcePersistenceAndMerge() throws {
        let phone = try DrinkSyncEvent(
            id: "phone-source", kind: .drink, recordID: "phone-source-record",
            timestamp: date(23, 9), milliliters: 197, source: "iphone-shortcut"
        )
        let computer = try DrinkSyncEvent(
            id: "mac-source", kind: .drink, recordID: "mac-source-record",
            timestamp: date(23, 10), milliliters: 250, source: "Mac"
        )
        let merged = DrinkSyncMerge.apply(events: [phone, computer], to: [])
        XCTAssertEqual(merged.map(\.source), [.phone, .mac])
        XCTAssertEqual(merged.map(\.source.label), ["手机", "电脑"])

        let encoded = try JSONEncoder().encode(merged)
        let restored = try JSONDecoder().decode([Drink].self, from: encoded)
        XCTAssertEqual(restored, merged)

        let legacy = """
        {"id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","date":0,"grams":197}
        """
        let legacyDrink = try JSONDecoder().decode(Drink.self, from: Data(legacy.utf8))
        XCTAssertEqual(legacyDrink.source, .unknown)
        XCTAssertEqual(legacyDrink.source.label, "来源未知")

        let phoneID = merged.first { $0.source == .phone }!.id
        let enriched = DrinkSyncMerge.apply(
            events: [phone],
            to: [Drink(id: phoneID, date: date(23, 9), grams: 197, source: .unknown)]
        )
        XCTAssertEqual(enriched.first?.source, .phone)
    }
    func testWelcomeEligibility() {
        XCTAssertTrue(WelcomePolicy.shouldShow(completed: false, existingState: false))
        XCTAssertFalse(WelcomePolicy.shouldShow(completed: false, existingState: true))
        XCTAssertFalse(WelcomePolicy.shouldShow(completed: true, existingState: false))
        XCTAssertFalse(WelcomePolicy.shouldShow(completed: true, existingState: true))
    }
    func testSettingsSaveClosesOnlyOnSuccess() {
        var closeCount = 0
        XCTAssertFalse(SettingsSaveFlow.perform(save: { false }, close: { closeCount += 1 }))
        XCTAssertEqual(closeCount, 0)
        XCTAssertTrue(SettingsSaveFlow.perform(save: { true }, close: { closeCount += 1 }))
        XCTAssertEqual(closeCount, 1)
    }

    func testDrinkSyncProtocolAndMerge() throws {
        let recordID = "11111111-1111-1111-1111-111111111111"
        let eventID = "20261027T101530.123-48291"
        let added = try DrinkSyncEvent(
            id: eventID, kind: .drink, recordID: recordID,
            timestamp: date(23, 9, 30), milliliters: 197, source: "iphone-shortcut"
        )
        let roundTrip = try DrinkSyncEvent.decode(added.encoded())
        XCTAssertEqual(roundTrip, added)

        let duplicate = try DrinkSyncEvent(
            id: "20261027T101530.124-48292",
            kind: .drink, recordID: recordID,
            timestamp: date(23, 9, 30), milliliters: 197, source: "mac"
        )
        let merged = DrinkSyncMerge.apply(events: [added, duplicate], to: [])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.id.uuidString.lowercased(), recordID)
        XCTAssertEqual(merged.first?.grams, 197)

        let shortcutAdded = try DrinkSyncEvent(
            id: "iphone-log-0", kind: .drink, recordID: "iphone-log-0",
            timestamp: date(23, 9, 45), milliliters: 197, source: "iphone-shortcut"
        )
        let shortcutFirstMerge = DrinkSyncMerge.apply(events: [shortcutAdded], to: [])
        XCTAssertEqual(DrinkSyncMerge.apply(events: [shortcutAdded], to: shortcutFirstMerge).count, 1)
        XCTAssertEqual(DrinkSyncMerge.apply(
            events: [shortcutAdded], to: shortcutFirstMerge + shortcutFirstMerge
        ).count, 1)

        let deleted = try DrinkSyncEvent(
            id: "20261027T101600.000-48293",
            kind: .delete, recordID: recordID,
            timestamp: date(23, 10), milliliters: nil, source: "mac"
        )
        XCTAssertEqual(DrinkSyncMerge.apply(events: [deleted, added], to: []).count, 0)

        for invalidAmount in [0, 2001] {
            do {
                _ = try DrinkSyncEvent(
                    id: UUID().uuidString, kind: .drink, recordID: UUID().uuidString, timestamp: date(23, 12),
                    milliliters: invalidAmount, source: "iphone-shortcut"
                )
                preconditionFailure("Expected invalid amount \(invalidAmount) to be rejected")
            } catch {}
        }
        do {
            _ = try DrinkSyncEvent.decode(Data("{not-json}".utf8))
            preconditionFailure("Expected malformed JSON to be rejected")
        } catch {}
    }

    func testDrinkSyncFilesystemAndOutbox() throws {
        let shortcutPath = DrinkSyncFilesystem.shortcutSyncDirectory(
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        ).path
        XCTAssertEqual(shortcutPath, "/Users/example/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/喝水BO～/Sync")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let outbox = root.appendingPathComponent("outbox")
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(outboxDirectory: outbox, syncDirectory: cloud)

        let phoneEvents = cloud.appendingPathComponent("Events", isDirectory: true)
        try FileManager.default.createDirectory(at: phoneEvents, withIntermediateDirectories: true)
        let phoneEvent = try DrinkSyncEvent(
            id: "iphone-event-1", kind: .drink,
            recordID: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            timestamp: date(23, 8, 30), milliliters: 197, source: "iphone-shortcut"
        )
        try phoneEvent.encoded().write(to: phoneEvents.appendingPathComponent("valid.json"))
        try phoneEvent.encoded().write(to: phoneEvents.appendingPathComponent("duplicate.json"))
        let textPhoneEvent = try DrinkSyncEvent(
            id: "iphone-event-2", kind: .drink,
            recordID: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF",
            timestamp: date(23, 8, 45), milliliters: 250, source: "iphone-shortcut"
        )
        try textPhoneEvent.encoded().write(to: phoneEvents.appendingPathComponent("valid.txt"))
        try textPhoneEvent.encoded().write(to: phoneEvents.appendingPathComponent("duplicate.txt"))
        try Data().write(to: phoneEvents.appendingPathComponent("empty.json"))
        try Data().write(to: phoneEvents.appendingPathComponent("empty.txt"))
        try Data("{broken}".utf8).write(to: phoneEvents.appendingPathComponent("malformed.json"))
        try Data("{broken}".utf8).write(to: phoneEvents.appendingPathComponent("malformed.txt"))
        try Data("""
        {"schemaVersion":1,"id":"bad-amount","kind":"drink","recordID":"bad-amount","timestamp":"2026-10-23T08:31:00Z","milliliters":2001,"source":"iphone-shortcut"}
        """.utf8).write(to: phoneEvents.appendingPathComponent("invalid-amount.json"))
        XCTAssertEqual(
            try storage.loadEvents().filter { $0.id.hasPrefix("iphone-event-") }.map(\.id),
            ["iphone-event-1", "iphone-event-2"]
        )

        let first = Drink(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                          date: date(23, 9), grams: 197)
        try storage.enqueueMissing(drinks: [first], source: "mac")
        try storage.enqueueMissing(drinks: [first], source: "mac")
        XCTAssertEqual(try storage.loadEvents().filter { $0.kind == .drink && $0.source == "mac" }.count, 1)
        try storage.flushOutbox()
        XCTAssertEqual(try storage.loadSharedEvents().filter { $0.kind == .drink }.count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outbox.path).count, 0)

        try Data("{broken}".utf8).write(to: cloud.appendingPathComponent("broken.json"))
        XCTAssertEqual(try storage.loadSharedEvents().filter { $0.kind == .drink }.count, 1)

        let deleted = try DrinkSyncEvent(
            id: UUID().uuidString, kind: .delete, recordID: first.id.uuidString,
            timestamp: date(23, 10), milliliters: nil, source: "mac"
        )
        try storage.enqueue(deleted)
        try storage.flushOutbox()
        XCTAssertEqual(DrinkSyncMerge.apply(events: try storage.loadSharedEvents(), to: [first]).count, 0)

        try storage.publishSettings(goal: 1800, serving: 197)
        let settings = try JSONDecoder().decode(
            DrinkSyncSettings.self,
            from: Data(contentsOf: cloud.appendingPathComponent("settings.json"))
        )
        XCTAssertEqual(settings.goal, 1800)
        XCTAssertEqual(settings.serving, 197)

        try Data("197\n250\n".utf8).write(to: cloud.appendingPathComponent("iphone-amounts.txt"))
        try Data("2026-10-23T10:15:00+08:00\n2026年10月23日 11:20\n".utf8)
            .write(to: cloud.appendingPathComponent("iphone-times.txt"))
        let shortcutEvents = try storage.loadEvents().filter { $0.recordID.hasPrefix("iphone-log-") }
        XCTAssertEqual(shortcutEvents.map(\.milliliters), [197, 250])
        XCTAssertEqual(shortcutEvents.map(\.recordID), ["iphone-log-0", "iphone-log-1"])

        let blockedRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: blockedRoot) }
        try Data("not-a-directory".utf8).write(to: blockedRoot)
        let offline = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("offline-outbox"),
            syncDirectory: blockedRoot.appendingPathComponent("cloud")
        )
        let pending = try DrinkSyncEvent(
            id: UUID().uuidString, kind: .drink, recordID: UUID().uuidString,
            timestamp: date(23, 12), milliliters: 250, source: "mac"
        )
        try offline.enqueue(pending)
        do {
            try offline.flushOutbox()
            preconditionFailure("Expected unavailable sync destination to fail")
        } catch {}
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("offline-outbox"),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }.count, 1)
    }

    func testDrinkSyncTodaySummary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let storage = DrinkSyncFilesystem(outboxDirectory: root.appendingPathComponent("outbox"), syncDirectory: cloud)

        try Data("197\ninvalid\n250\n".utf8).write(to: cloud.appendingPathComponent("iphone-amounts.txt"))
        try Data("2026/10/23 09:15\n2026/10/23 09:30\n2026/10/23 11:20\nextra\n".utf8)
            .write(to: cloud.appendingPathComponent("iphone-times.txt"))
        let drinks = [
            Drink(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, date: date(23, 11, 20), grams: 250),
            Drink(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, date: date(23, 9, 15), grams: 197),
            Drink(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!, date: date(22, 18), grams: 600)
        ]

        try storage.publishTodaySummary(drinks: drinks, goal: 1800, now: date(23, 18), calendar: calendar)
        let summary = try JSONDecoder().decode(
            DrinkSyncTodaySummary.self,
            from: Data(contentsOf: cloud.appendingPathComponent("today-summary.json"))
        )
        XCTAssertEqual(summary.schemaVersion, 1)
        XCTAssertEqual(summary.day, "2026-10-23")
        XCTAssertEqual(summary.goal, 1800)
        XCTAssertEqual(summary.total, 447)
        XCTAssertEqual(summary.phoneLogCount, 3)
        XCTAssertEqual(summary.records.map(\.milliliters), [197, 250])
        XCTAssertEqual(summary.records.map(\.displayTime), ["09:15", "11:20"])
        XCTAssertEqual(summary.records.map(\.recordID), [
            "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        ])
        XCTAssertEqual(summary.records.map(\.deviceShortName), ["mac", "mac"])
    }

    func testPhoneLogsReachMacSummary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )

        try Data("197\n250\n\n".utf8).write(
            to: cloud.appendingPathComponent("iphone-amounts.txt")
        )
        try Data("2026/10/23 09:15\n2026/10/23 11:20\n\n".utf8).write(
            to: cloud.appendingPathComponent("iphone-times.txt")
        )

        let drinks = DrinkSyncMerge.apply(events: try storage.loadEvents(), to: [])
        try storage.publishTodaySummary(
            drinks: drinks,
            goal: 1800,
            now: date(23, 18),
            calendar: calendar
        )

        let summaryURL = cloud.appendingPathComponent("today-summary.json")
        let first = try JSONDecoder().decode(
            DrinkSyncTodaySummary.self,
            from: Data(contentsOf: summaryURL)
        )
        XCTAssertEqual(first.total, 447)
        XCTAssertEqual(first.phoneLogCount, 2)
        XCTAssertEqual(first.records.map(\.displayTime), ["09:15", "11:20"])

        let repeatedDrinks = DrinkSyncMerge.apply(
            events: try storage.loadEvents(),
            to: drinks
        )
        try storage.publishTodaySummary(
            drinks: repeatedDrinks,
            goal: 1800,
            now: date(23, 19),
            calendar: calendar
        )
        let repeated = try JSONDecoder().decode(
            DrinkSyncTodaySummary.self,
            from: Data(contentsOf: summaryURL)
        )
        XCTAssertEqual(repeated, first)
    }

    func testSharedCSVPhoneEventsAdvanceSummaryCursor() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )
        let first = try DrinkSyncEvent(
            id: "iphone-1", kind: .drink, recordID: "iphone-1",
            timestamp: date(23, 9), milliliters: 197, source: "iPhone"
        )
        let second = try DrinkSyncEvent(
            id: "iphone-2", kind: .drink, recordID: "iphone-2",
            timestamp: date(23, 10), milliliters: 250, source: "iPhone"
        )
        try storage.appendShared(first)
        try storage.appendShared(second)
        let drinks = DrinkSyncMerge.apply(events: try storage.loadSharedEvents(), to: [])

        try storage.publishTodaySummary(
            drinks: drinks, goal: 1800, now: date(23, 18), calendar: calendar
        )

        let summary = try JSONDecoder().decode(
            DrinkSyncTodaySummary.self,
            from: Data(contentsOf: cloud.appendingPathComponent("today-summary.json"))
        )
        XCTAssertEqual(summary.total, 447)
        XCTAssertEqual(summary.phoneLogCount, 2)
    }

    func testSharedCSVCodec() throws {
        let timestamp = date(23, 9, 30)
        let drink = try DrinkSyncEvent(
            id: "event-1",
            kind: .drink,
            recordID: "record-1",
            timestamp: timestamp,
            milliliters: 197,
            source: "iPhone"
        )
        XCTAssertTrue(DrinkSyncCSV.header.hasPrefix("\u{FEFF}"))
        let encodedDrink = try DrinkSyncCSV.encode(drink)
        XCTAssertEqual(
            encodedDrink,
            "event-1,drink,record-1,2026-10-23T01:30:00Z,197,iPhone\r\n"
        )
        XCTAssertEqual(DrinkSyncCSV.decode(DrinkSyncCSV.header + encodedDrink), [drink])

        let invalid = DrinkSyncCSV.header
            + "missing,fields\r\n"
            + "bad-time,drink,record-2,not-a-date,197,iPhone\r\n"
            + "bad-amount,drink,record-3,2026-10-23T01:31:00Z,0,iPhone\r\n"
        XCTAssertTrue(DrinkSyncCSV.decode(invalid).isEmpty)

        XCTAssertEqual(
            DrinkSyncCSV.decode(DrinkSyncCSV.header + encodedDrink + encodedDrink).count,
            1
        )

        let deleted = try DrinkSyncEvent(
            id: "event-2",
            kind: .delete,
            recordID: "record-1",
            timestamp: timestamp.addingTimeInterval(60),
            milliliters: nil,
            source: "iPhone"
        )
        let encodedDeleted = try DrinkSyncCSV.encode(deleted)
        let events = DrinkSyncCSV.decode(
            DrinkSyncCSV.header + encodedDeleted + encodedDrink
        )
        XCTAssertEqual(DrinkSyncMerge.apply(events: events, to: []), [])
    }

    func testSharedCSVFilesystemAndMigration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        let backup = root.appendingPathComponent("backup")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )

        XCTAssertEqual(storage.sharedLogURL.lastPathComponent, "喝水记录.csv")
        try storage.ensureSharedLog()
        let headerData = try Data(contentsOf: storage.sharedLogURL)
        XCTAssertEqual(Array(headerData.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertTrue(
            String(data: headerData.dropFirst(3), encoding: .utf8)?
                .hasPrefix("事件ID,类型,记录ID,时间,水量(ml),来源") == true
        )

        let first = try DrinkSyncEvent(
            id: "shared-1",
            kind: .drink,
            recordID: "record-1",
            timestamp: date(23, 8),
            milliliters: 197,
            source: "iPhone"
        )
        let second = try DrinkSyncEvent(
            id: "shared-2",
            kind: .drink,
            recordID: "record-2",
            timestamp: date(23, 9),
            milliliters: 250,
            source: "Mac"
        )
        try storage.appendShared(first)
        try storage.appendShared(second)
        try storage.appendShared(first)
        XCTAssertEqual(try storage.loadSharedEvents(), [first, second])
        let handle = try FileHandle(forWritingTo: storage.sharedLogURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("broken,row\r\n".utf8))
        try handle.close()

        let legacy = try DrinkSyncEvent(
            id: "legacy-mac",
            kind: .drink,
            recordID: "legacy-record",
            timestamp: date(23, 10),
            milliliters: 300,
            source: "Mac"
        )
        try legacy.encoded().write(to: cloud.appendingPathComponent("legacy-mac.json"))
        try Data("197\n".utf8).write(to: cloud.appendingPathComponent("iphone-amounts.txt"))
        try Data("2026/10/23 11:00\n".utf8).write(to: cloud.appendingPathComponent("iphone-times.txt"))
        try Data("{}".utf8).write(to: cloud.appendingPathComponent("settings.json"))
        try Data("{}".utf8).write(to: cloud.appendingPathComponent("today-summary.json"))

        let migrated = try storage.migrateLegacyFiles(backupDirectory: backup)
        XCTAssertEqual(Set(migrated.map(\.id)), ["shared-1", "shared-2", "legacy-mac", "iphone-log-0"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("legacy-mac.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("iphone-amounts.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("settings.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("legacy-mac.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("iphone-amounts.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("settings.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("today-summary.json").path))
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: cloud.path).sorted(),
            ["settings.json", "today-summary.json", "喝水记录.csv"]
        )
    }

    func testMigrationSkipsEventsDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        let backup = root.appendingPathComponent("backup")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )

        let events = cloud.appendingPathComponent("Events", isDirectory: true)
        try FileManager.default.createDirectory(at: events, withIntermediateDirectories: true)
        let phone = try DrinkSyncEvent(
            id: "phone-in-events", kind: .drink, recordID: "phone-in-events",
            timestamp: date(23, 9), milliliters: 197, source: "iphone-shortcut"
        )
        try phone.encoded().write(to: events.appendingPathComponent("phone.json"))

        let migrated = try storage.migrateLegacyFiles(backupDirectory: backup)
        XCTAssertEqual(migrated.map(\.id), ["phone-in-events"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: events.path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: backup.appendingPathComponent("Events").path)
        )
    }

    func testAppendMissingSharedRecognizesResolvedRecordIDs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )
        let phone = try DrinkSyncEvent(
            id: "phone-event", kind: .drink, recordID: "phone-record-without-uuid",
            timestamp: date(23, 9), milliliters: 197, source: "iphone-shortcut"
        )
        try storage.appendShared(phone)
        let merged = DrinkSyncMerge.apply(events: [phone], to: [])

        try storage.appendMissingShared(drinks: merged, source: "Mac")

        let shared = try storage.loadSharedEvents()
        XCTAssertEqual(shared.count, 1)
        XCTAssertEqual(shared.filter { $0.source == "Mac" }.count, 0)
    }

    func testAppendMissingSharedWritesEventFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )
        let drink = Drink(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            date: date(23, 9), grams: 197, source: .mac,
            deviceID: "mac-A", deviceName: "MacBook Pro", deviceShortName: "M1"
        )
        try storage.appendMissingShared(drinks: [drink], source: "Mac")
        let events = cloud.appendingPathComponent("Events")
        let files = try FileManager.default.contentsOfDirectory(atPath: events.path)
        XCTAssertEqual(files.filter { $0.hasSuffix(".json") }.count, 1)
        let loaded = try storage.loadEvents().first { $0.recordID == drink.id.uuidString }
        XCTAssertEqual(loaded?.deviceShortName, "M1")
        XCTAssertEqual(loaded?.source, "mac")
    }

    func testSharedCSVReconciliation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        let outbox = root.appendingPathComponent("outbox")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(outboxDirectory: outbox, syncDirectory: cloud)

        let phoneOne = try DrinkSyncEvent(
            id: "phone-1", kind: .drink, recordID: "phone-record-1",
            timestamp: date(23, 9), milliliters: 197, source: "iPhone"
        )
        let phoneTwo = try DrinkSyncEvent(
            id: "phone-2", kind: .drink, recordID: "phone-record-2",
            timestamp: date(23, 10), milliliters: 250, source: "iPhone"
        )
        try storage.appendShared(phoneOne)
        try storage.appendShared(phoneTwo)
        let merged = DrinkSyncMerge.apply(events: try storage.loadSharedEvents(), to: [])
        XCTAssertEqual(merged.reduce(0) { $0 + $1.grams }, 447)

        let deleted = try DrinkSyncEvent(
            id: "phone-delete-1", kind: .delete, recordID: "phone-record-1",
            timestamp: date(23, 11), milliliters: nil, source: "iPhone"
        )
        try storage.appendShared(deleted)
        XCTAssertEqual(
            DrinkSyncMerge.apply(events: try storage.loadSharedEvents(), to: merged).map(\.id.uuidString),
            ["phone-record-2"].map { _ in
                DrinkSyncMerge.apply(events: [phoneTwo], to: []).first!.id.uuidString
            }
        )

        let local = Drink(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            date: date(23, 12),
            grams: 300
        )
        try storage.appendMissingShared(drinks: [local, local], source: "Mac")
        try storage.appendMissingShared(drinks: [local], source: "Mac")
        XCTAssertEqual(
            try storage.loadSharedEvents().filter { $0.recordID == local.id.uuidString }.count,
            1
        )

        let pending = try DrinkSyncEvent(
            id: "pending-event", kind: .delete, recordID: local.id.uuidString,
            timestamp: date(23, 13), milliliters: nil, source: "Mac"
        )
        try storage.enqueue(pending)
        try storage.flushOutbox()
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: outbox.path).count,
            0
        )
        XCTAssertTrue(try storage.loadSharedEvents().contains { $0.id == pending.id })
    }

    func testDeviceFilesAreIndependent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )
        let first = try LanDeviceRecord(
            deviceID: "mac-A",
            name: "BOBO 的 MacBook Pro",
            shortName: "M1",
            role: .standby,
            lanURL: "http://mac-a.local:47832",
            lanFallbackURL: "http://192.168.1.20:47832",
            lanSubnet: "192.168.1",
            lanToken: "token-a",
            lastSeen: "2026-11-13T11:30:00+08:00"
        )
        let second = try LanDeviceRecord(
            deviceID: "mac-B",
            name: "BOBO 的 Mac mini",
            shortName: "OFFICE",
            role: .primary,
            lanURL: "http://mac-b.local:47833",
            lanFallbackURL: "http://192.168.1.21:47833",
            lanSubnet: "192.168.1",
            lanToken: "token-b",
            lastSeen: "2026-11-13T11:31:00+08:00"
        )

        try storage.publishDevice(first)
        try storage.publishDevice(second)

        let records = try storage.loadDevices()
        XCTAssertEqual(records.map(\.deviceID).sorted(), ["mac-A", "mac-B"])
        XCTAssertEqual(records.map(\.shortName).sorted(), ["M1", "OFFICE"])
        XCTAssertEqual(Set(records.map(\.lanToken)), ["token-a", "token-b"])
    }

    func testMalformedDeviceFileIsIgnored() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(
            outboxDirectory: root.appendingPathComponent("outbox"),
            syncDirectory: cloud
        )
        let devices = cloud.appendingPathComponent("Devices", isDirectory: true)
        try FileManager.default.createDirectory(at: devices, withIntermediateDirectories: true)
        try Data("{broken}".utf8).write(to: devices.appendingPathComponent("bad.json"))

        XCTAssertEqual(try storage.loadDevices().count, 0)
    }

    func testDeviceShortNamesAreCompactAndUnique() {
        XCTAssertEqual(LanDeviceNamer.nextShortName(existing: []), "M1")
        XCTAssertEqual(LanDeviceNamer.nextShortName(existing: ["M1"]), "M2")
        XCTAssertEqual(LanDeviceNamer.nextShortName(existing: ["M1", "M3"]), "M2")
    }

    func testLANHTTPParser() {
        let valid = Data("""
        POST /v1/drink HTTP/1.1\r
        Authorization: Bearer secret\r
        Content-Length: 2\r
        \r
        {}
        """.utf8)
        guard case .request(let request) = LanHTTPRequestParser.parse(valid) else {
            preconditionFailure("Expected a complete HTTP request")
        }
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/v1/drink")
        XCTAssertEqual(request.headers["authorization"], "Bearer secret")
        XCTAssertEqual(request.body, Data("{}".utf8))

        let incomplete = Data("POST /v1/drink HTTP/1.1\r\nContent-Length: 2\r\n\r\n".utf8)
        XCTAssertEqual(LanHTTPRequestParser.parse(incomplete), .incomplete)

        guard case .request(let todayRequest) = LanHTTPRequestParser.parse(
            Data("GET /v1/today HTTP/1.1\r\nAuthorization: Bearer secret\r\n\r\n".utf8)
        ) else {
            preconditionFailure("Expected a bodyless GET request to parse")
        }
        XCTAssertEqual(todayRequest.method, "GET")
        XCTAssertEqual(todayRequest.path, "/v1/today")
        XCTAssertEqual(todayRequest.body, Data())

        var oversized = Data("POST /v1/drink HTTP/1.1\r\nContent-Length: 8193\r\n\r\n".utf8)
        oversized.append(Data(repeating: 65, count: 8193))
        XCTAssertEqual(LanHTTPRequestParser.parse(oversized), .invalid)
    }

    func testLANDrinkServer() throws {
        final class Counter {
            var handled = 0
            var todayHandled = 0
        }
        let counter = Counter()
        let summary = DrinkSyncTodaySummary(
            day: "2026-11-13", goal: 1800, total: 1182,
            phoneLogCount: 11, records: []
        )
        let server = LanDrinkServer(
            token: "secret",
            handler: { event in
                counter.handled += 1
                return .accepted(duplicate: event.id == "duplicate")
            },
            todayHandler: {
                counter.todayHandled += 1
                return .today(summary)
            }
        )
        let port = try server.start(preferredPort: 0)
        defer { server.stop() }
        let event = try DrinkSyncEvent(
            id: "http-1", kind: .drink, recordID: "http-1",
            timestamp: date(23, 9), milliliters: 197, source: "iphone"
        )

        let accepted = sendHTTP(
            port: port,
            method: "POST",
            path: "/v1/drink",
            headers: ["Authorization": "Bearer secret"],
            body: try event.encoded()
        )
        XCTAssertEqual(accepted.status, 200)
        XCTAssertEqual(String(decoding: accepted.body, as: UTF8.self).contains("\"ok\":true"), true)
        XCTAssertEqual(counter.handled, 1)

        let unauthorized = sendHTTP(
            port: port,
            method: "POST",
            path: "/v1/drink",
            headers: ["Authorization": "Bearer wrong"],
            body: try event.encoded()
        )
        XCTAssertEqual(unauthorized.status, 401)
        XCTAssertEqual(counter.handled, 1)

        let today = sendHTTP(
            port: port,
            method: "GET",
            path: "/v1/today",
            headers: ["Authorization": "Bearer secret"],
            body: Data()
        )
        XCTAssertEqual(today.status, 200)
        XCTAssertEqual(try JSONDecoder().decode(DrinkSyncTodaySummary.self, from: today.body), summary)
        XCTAssertEqual(counter.todayHandled, 1)
        XCTAssertEqual(counter.handled, 1)

        let todayUnauthorized = sendHTTP(
            port: port,
            method: "GET",
            path: "/v1/today",
            headers: ["Authorization": "Bearer wrong"],
            body: Data()
        )
        XCTAssertEqual(todayUnauthorized.status, 401)
        XCTAssertEqual(counter.todayHandled, 1)

        let notFound = sendHTTP(
            port: port,
            method: "POST",
            path: "/wrong",
            headers: ["Authorization": "Bearer secret"],
            body: try event.encoded()
        )
        XCTAssertEqual(notFound.status, 404)

        server.stop()
        let closed = sendHTTP(
            port: port,
            method: "POST",
            path: "/v1/drink",
            headers: ["Authorization": "Bearer secret"],
            body: try event.encoded()
        )
        XCTAssertEqual(closed.status, 0)
    }

    func testLANEndpointSelection() {
        let addresses = ["127.0.0.1", "169.254.2.3", "8.8.8.8", "192.168.1.20"]
        XCTAssertEqual(LanAddressSelector.privateIPv4(in: addresses), "192.168.1.20")
        XCTAssertEqual(LanAddressSelector.privateIPv4(in: ["10.0.0.8"]), "10.0.0.8")
        XCTAssertEqual(LanAddressSelector.privateIPv4(in: ["172.16.3.9"]), "172.16.3.9")
        XCTAssertNil(LanAddressSelector.privateIPv4(in: ["172.32.3.9", "224.0.0.1"]))
        XCTAssertEqual(LanAddressSelector.subnet(forIPv4: "192.168.1.20"), "192.168.1")

        let endpoint = LanAddressSelector.endpoint(
            hostName: "BOBOs-MacBook-Pro", addresses: ["192.168.1.20"], port: 47832
        )
        XCTAssertEqual(endpoint?.hostName, "bobos-macbook-pro.local")
        XCTAssertEqual(endpoint?.url, "http://bobos-macbook-pro.local:47832")
        XCTAssertEqual(endpoint?.fallbackURL, "http://192.168.1.20:47832")
    }

    func testLANDeviceSelection() throws {
        let now = date(23, 12)
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let older = try LanDeviceRecord(
            deviceID: "mac-A", name: "MacBook", shortName: "M1", role: .standby,
            lanURL: "http://mac-a.local:47832",
            lanFallbackURL: "http://192.168.1.20:47832", lanSubnet: "192.168.1",
            lanToken: "a", lastSeen: formatter.string(from: now.addingTimeInterval(-120))
        )
        let primary = try LanDeviceRecord(
            deviceID: "mac-B", name: "Mac mini", shortName: "OFFICE", role: .primary,
            lanURL: "http://mac-b.local:47832",
            lanFallbackURL: "http://192.168.1.21:47832", lanSubnet: "192.168.1",
            lanToken: "b", lastSeen: formatter.string(from: now.addingTimeInterval(-300))
        )
        let otherNetwork = try LanDeviceRecord(
            deviceID: "mac-C", name: "Other", shortName: "M3", role: .primary,
            lanURL: "http://mac-c.local:47832",
            lanFallbackURL: "http://192.168.2.21:47832", lanSubnet: "192.168.2",
            lanToken: "c", lastSeen: formatter.string(from: now)
        )
        let stale = try LanDeviceRecord(
            deviceID: "mac-D", name: "Stale", shortName: "M4", role: .primary,
            lanURL: "http://mac-d.local:47832",
            lanFallbackURL: "http://192.168.1.22:47832", lanSubnet: "192.168.1",
            lanToken: "d", lastSeen: formatter.string(from: now.addingTimeInterval(-8 * 86_400))
        )

        let selected = LanDeviceSelector.candidates(
            [older, primary, otherNetwork, stale], phoneIPv4: "192.168.1.50", now: now
        )
        XCTAssertEqual(selected.map(\.deviceID), ["mac-B", "mac-A"])
        XCTAssertEqual(LanDeviceSelector.select(selected, phoneIPv4: "192.168.1.50", now: now)?.deviceID, "mac-B")
    }

    func testLANTokenPersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("lan-token")
        let first = try LanSyncSupport.loadOrCreateToken(at: url)
        let second = try LanSyncSupport.loadOrCreateToken(at: url)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 43)
        XCTAssertTrue(first.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    func testReminderNotificationAutoDismissDelay() {
        XCTAssertEqual(ReminderNotificationPresentation.autoDismissDelay, 3)
    }

    func testCustomMacSuffixValidation() {
        XCTAssertTrue(LanDeviceNamer.isValidShortName("OFFICE"))
        XCTAssertTrue(LanDeviceNamer.isValidShortName("HOME"))
        XCTAssertTrue(LanDeviceNamer.isValidShortName("MBP"))
        XCTAssertFalse(LanDeviceNamer.isValidShortName(""))
        XCTAssertFalse(LanDeviceNamer.isValidShortName("TOOLONG99"))
        XCTAssertFalse(LanDeviceNamer.isValidShortName("O F"))
        XCTAssertFalse(LanDeviceNamer.isValidShortName("IPH"))
    }

    func testRemoteDuplicateSuffixResolvesDeterministically() throws {
        let first = try LanDeviceRecord(
            deviceID: "mac-A", name: "MacBook", shortName: "M1", role: .standby,
            lanURL: "http://a.local:47832", lanFallbackURL: "http://192.168.1.20:47832",
            lanSubnet: "192.168.1", lanToken: "a", lastSeen: "2026-11-13T11:30:00+08:00"
        )
        let second = try LanDeviceRecord(
            deviceID: "mac-B", name: "Mac mini", shortName: "M1", role: .standby,
            lanURL: "http://b.local:47832", lanFallbackURL: "http://192.168.1.21:47832",
            lanSubnet: "192.168.1", lanToken: "b", lastSeen: "2026-11-13T11:30:00+08:00"
        )
        XCTAssertEqual(
            LanDeviceNamer.resolvedShortName(configured: "M1", deviceID: "mac-A", others: [second]),
            "M1"
        )
        XCTAssertEqual(
            LanDeviceNamer.resolvedShortName(configured: "M1", deviceID: "mac-B", others: [first]),
            "M2"
        )
    }

    func testEventsPreserveDeviceIdentity() throws {
        let event = try DrinkSyncEvent(
            id: "mac-event", kind: .drink, recordID: "mac-record",
            timestamp: date(23, 9), milliliters: 250, source: "mac",
            deviceID: "mac-A", deviceName: "BOBO 的 MacBook Pro", deviceShortName: "M1"
        )
        let merged = LanDrinkIngestor.ingest(event, into: SavedState())
        XCTAssertFalse(merged.duplicate)
        XCTAssertEqual(merged.state.drinks.count, 1)
        XCTAssertEqual(merged.state.drinks[0].deviceID, "mac-A")
        XCTAssertEqual(merged.state.drinks[0].deviceName, "BOBO 的 MacBook Pro")
        XCTAssertEqual(merged.state.drinks[0].deviceShortName, "M1")
        XCTAssertEqual(merged.state.drinks[0].sourceSuffix, "mac")
    }

    func testSimultaneousMacEventsBothSurvive() throws {
        let first = try DrinkSyncEvent(
            id: "mac-A-event", kind: .drink, recordID: "mac-A-record",
            timestamp: date(23, 9), milliliters: 197, source: "mac",
            deviceID: "mac-A", deviceName: "MacBook Pro", deviceShortName: "M1"
        )
        let second = try DrinkSyncEvent(
            id: "mac-B-event", kind: .drink, recordID: "mac-B-record",
            timestamp: date(23, 9), milliliters: 197, source: "mac",
            deviceID: "mac-B", deviceName: "Mac mini", deviceShortName: "M2"
        )
        let once = LanDrinkIngestor.ingest(first, into: SavedState()).state
        let twice = LanDrinkIngestor.ingest(second, into: once).state
        XCTAssertEqual(twice.drinks.count, 2)
        XCTAssertEqual(Set(twice.drinks.compactMap(\.deviceShortName)), ["M1", "M2"])
    }

    func testSameEventFromTwoDevicesCountsOnce() throws {
        let first = try DrinkSyncEvent(
            id: "same-event", kind: .drink, recordID: "same-record",
            timestamp: date(23, 9), milliliters: 197, source: "mac",
            deviceID: "mac-A", deviceName: "MacBook Pro", deviceShortName: "M1"
        )
        let second = try DrinkSyncEvent(
            id: "same-event-copy", kind: .drink, recordID: "same-record",
            timestamp: date(23, 9), milliliters: 197, source: "mac",
            deviceID: "mac-B", deviceName: "Mac mini", deviceShortName: "M2"
        )
        let once = LanDrinkIngestor.ingest(first, into: SavedState()).state
        let twice = LanDrinkIngestor.ingest(second, into: once)
        XCTAssertTrue(twice.duplicate)
        XCTAssertEqual(twice.state.drinks.count, 1)
        XCTAssertEqual(twice.state.drinks[0].deviceShortName, "M1")
    }

    func testMacEventsSurviveCSVConflict() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cloud = root.appendingPathComponent("cloud")
        let outbox = root.appendingPathComponent("outbox")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = DrinkSyncFilesystem(outboxDirectory: outbox, syncDirectory: cloud)
        let event = try DrinkSyncEvent(
            id: "event-1", kind: .drink, recordID: "record-1",
            timestamp: date(23, 9), milliliters: 197, source: "mac",
            deviceID: "mac-A", deviceName: "MacBook Pro", deviceShortName: "M1"
        )
        try storage.enqueue(event)
        try storage.flushOutbox(sourceDeviceID: "mac-A")
        try Data(DrinkSyncCSV.header.utf8).write(to: storage.sharedLogURL, options: .atomic)

        let loaded = try storage.loadEvents()
        XCTAssertEqual(loaded.filter { $0.id == "event-1" }.count, 1)
    }

    func testLegacySourceStillNormalizes() {
        let source = Drink.Source(syncSource: "iphone-shortcut")
        XCTAssertEqual(source, .phone)
        XCTAssertEqual(Drink.Source(syncSource: "Mac"), .mac)
    }

    func testLANPreferencesCompatibility() throws {
        XCTAssertTrue(Preferences().lanSyncEnabled == true)
        XCTAssertFalse(Preferences().lanPrimaryEnabled == true)
        XCTAssertNil(Preferences().lanShortName)
        let legacy = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
        XCTAssertTrue(legacy.lanSyncEnabled == nil)
        XCTAssertTrue(legacy.iCloudSyncEnabled == nil)
    }

    func testDrinkDeviceDisplayLabel() {
        let mac = Drink(
            date: date(23, 9), grams: 197, source: .mac, deviceID: "mac-A",
            deviceName: "BOBO 的 MacBook Pro", deviceShortName: "M1"
        )
        XCTAssertEqual(mac.sourceDisplayLabel, "M1")
        XCTAssertEqual(mac.sourceDetailLabel, "BOBO 的 MacBook Pro")
        XCTAssertEqual(mac.sourceSuffix, "mac")
        let phone = Drink(
            date: date(23, 10), grams: 197, source: .phone, deviceID: "iphone",
            deviceName: "BOBO 的 iPhone", deviceShortName: "iPH"
        )
        XCTAssertEqual(phone.sourceDisplayLabel, "iPH")
        XCTAssertEqual(phone.sourceSuffix, "iphone")
        let old = Drink(date: date(23, 11), grams: 197, source: .mac)
        XCTAssertEqual(old.sourceDisplayLabel, "电脑")
        XCTAssertEqual(old.sourceDetailLabel, "电脑")
    }

    func testHistoryCSVIncludesDeviceColumns() {
        let drink = Drink(
            date: date(23, 9), grams: 197, source: .mac, deviceID: "mac-A",
            deviceName: "BOBO, MacBook Pro", deviceShortName: "M1"
        )
        let phone = Drink(
            date: date(23, 10), grams: 197, source: .phone, deviceID: "iphone",
            deviceName: "BOBO 的 iPhone", deviceShortName: "iPH"
        )
        let csv = HistoryReport.csv(drinks: [drink, phone], from: date(23, 0), through: date(23, 23), calendar: calendar)
        XCTAssertTrue(csv?.hasPrefix("\u{FEFF}日期,时间,喝水量(ml),设备,完整设备名,来源\r\n") == true)
        XCTAssertTrue(csv?.contains("2026-10-23,09:00:00,197,M1,\"BOBO, MacBook Pro\",mac\r\n") == true)
        XCTAssertTrue(csv?.contains("2026-10-23,10:00:00,197,iPH,BOBO 的 iPhone,iphone\r\n") == true)
    }

    func testRenamingDeviceUpdatesMatchingHistory() throws {
        let id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var state = SavedState()
        state.drinks = [Drink(
            id: id, date: date(23, 9), grams: 197, source: .mac,
            deviceID: "mac-A", deviceName: "Old name", deviceShortName: "M1"
        )]
        let record = try LanDeviceRecord(
            deviceID: "mac-A", name: "BOBO 的 MacBook Pro", shortName: "OFFICE", role: .standby,
            lanURL: "http://mac-a.local:47832",
            lanFallbackURL: "http://192.168.1.20:47832", lanSubnet: "192.168.1",
            lanToken: "token", lastSeen: "2026-11-13T11:30:00+08:00"
        )
        let updated = LanDrinkIngestor.applyDeviceAliases([record], to: state)
        XCTAssertTrue(updated.changed)
        XCTAssertEqual(updated.state.drinks[0].id, id)
        XCTAssertEqual(updated.state.drinks[0].deviceShortName, "OFFICE")
        XCTAssertEqual(updated.state.drinks[0].deviceName, "BOBO 的 MacBook Pro")
    }

    private func sendHTTP(port: UInt16, method: String, path: String,
                          headers: [String: String], body: Data) -> (status: Int, body: Data) {
        let semaphore = DispatchSemaphore(value: 0)
        var response: (Int, Data) = (0, Data())
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let task = URLSession.shared.dataTask(with: request) { data, urlResponse, _ in
            response = ((urlResponse as? HTTPURLResponse)?.statusCode ?? 0, data ?? Data())
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        return response
    }
}
