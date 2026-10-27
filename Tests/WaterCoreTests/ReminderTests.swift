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
        try suite.testWaveAppearanceAndLegacySettings()
        try suite.testWaveOpacityPersistsAndLegacyDefaults()
        try suite.testFishCountSettingsAndIndependentMotion()
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
        suite.testHistoryExportRange()
        suite.testWelcomeEligibility()
        suite.testSettingsSaveClosesOnlyOnSuccess()
        suite.testPopoverKeepsTopEdgeWhenContentHeightChanges()
        try suite.testDrinkSyncProtocolAndMerge()
        try suite.testDrinkSyncFilesystemAndOutbox()
        try suite.testDrinkSyncTodaySummary()
        print("PASS: 31 groups — schedule, weekend, pause/goal, snooze, totals/persistence, validation, milestones, undo/replay, wave settings, wave opacity, fish count, color picker, wave variation, water motion, fish interaction, fish pace, fish leap rules, triple-tap leap, fish leap arc, fish perspective, fish weave, fish rest/peck, daily card, history, export, welcome, settings close, popover anchor, iCloud sync protocol, iCloud filesystem, iPhone today summary")
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
    func testHistoryExportRange() {
        let drinks = [Drink(date: date(21, 23), grams: 150), Drink(date: date(22, 8), grams: 197),
                      Drink(date: date(23, 18), grams: 250), Drink(date: date(24, 0), grams: 300)]
        let csv = HistoryReport.csv(drinks: drinks, from: date(22, 12), through: date(23, 12), calendar: calendar)
        XCTAssertTrue(csv?.hasPrefix("\u{FEFF}日期,时间,喝水量(ml)\r\n") == true)
        XCTAssertTrue(csv?.contains("2026-10-22,08:00:00,197\r\n") == true)
        XCTAssertTrue(csv?.contains("2026-10-23,18:00:00,250\r\n") == true)
        XCTAssertFalse(csv?.contains("150") == true)
        XCTAssertFalse(csv?.contains("300") == true)
        XCTAssertNil(HistoryReport.csv(drinks: drinks, from: date(20, 12), through: date(20, 12), calendar: calendar))
        XCTAssertNil(HistoryReport.csv(drinks: drinks, from: date(23, 12), through: date(22, 12), calendar: calendar))
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

        let first = Drink(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                          date: date(23, 9), grams: 197)
        try storage.enqueueMissing(drinks: [first], source: "mac")
        try storage.enqueueMissing(drinks: [first], source: "mac")
        XCTAssertEqual(try storage.loadEvents().filter { $0.kind == .drink }.count, 1)
        try storage.flushOutbox()
        XCTAssertEqual(try storage.loadEvents().filter { $0.kind == .drink }.count, 1)

        try Data("{broken}".utf8).write(to: cloud.appendingPathComponent("broken.json"))
        XCTAssertEqual(try storage.loadEvents().filter { $0.kind == .drink }.count, 1)

        let deleted = try DrinkSyncEvent(
            id: UUID().uuidString, kind: .delete, recordID: first.id.uuidString,
            timestamp: date(23, 10), milliliters: nil, source: "mac"
        )
        try storage.enqueue(deleted)
        XCTAssertEqual(DrinkSyncMerge.apply(events: try storage.loadEvents(), to: [first]).count, 0)

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
        let shortcutEvents = try storage.loadEvents().filter { $0.source == "iphone-shortcut" }
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
        XCTAssertEqual(summary.records.map(\.recordID), [
            "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        ])
    }
}
