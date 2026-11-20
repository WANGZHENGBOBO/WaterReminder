import Foundation

public struct CompanionSchedule: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var start: Int
    public var end: Int
    public var interval: Int

    public init(enabled: Bool, start: Int, end: Int, interval: Int) {
        self.enabled = enabled
        self.start = start
        self.end = end
        self.interval = interval
    }

    public var isValid: Bool {
        enabled && (0..<1440).contains(start) && (0..<1440).contains(end)
            && start < end && (5...240).contains(interval)
    }
}

public struct CompanionSettings: Codable, Equatable, Sendable {
    public let goal: Int
    public let serving: Int
    public let weekday: CompanionSchedule?
    public let weekend: CompanionSchedule?
    public let snooze: Int
    public let stopAtGoal: Bool

    public init(
        goal: Int,
        serving: Int,
        weekday: CompanionSchedule?,
        weekend: CompanionSchedule?,
        snooze: Int,
        stopAtGoal: Bool
    ) {
        self.goal = goal
        self.serving = serving
        self.weekday = weekday
        self.weekend = weekend
        self.snooze = snooze
        self.stopAtGoal = stopAtGoal
    }

    public static let fallback = CompanionSettings(
        goal: 1800,
        serving: 197,
        weekday: CompanionSchedule(enabled: true, start: 660, end: 1140, interval: 45),
        weekend: CompanionSchedule(enabled: true, start: 660, end: 1140, interval: 45),
        snooze: 10,
        stopAtGoal: true
    )

    private enum CodingKeys: String, CodingKey {
        case goal, serving, weekday, weekend, snooze, stopAtGoal
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.fallback
        goal = try values.decodeIfPresent(Int.self, forKey: .goal) ?? fallback.goal
        serving = try values.decodeIfPresent(Int.self, forKey: .serving) ?? fallback.serving
        weekday = try values.decodeIfPresent(CompanionSchedule.self, forKey: .weekday)
        weekend = try values.decodeIfPresent(CompanionSchedule.self, forKey: .weekend)
        snooze = try values.decodeIfPresent(Int.self, forKey: .snooze) ?? fallback.snooze
        stopAtGoal = try values.decodeIfPresent(Bool.self, forKey: .stopAtGoal)
            ?? fallback.stopAtGoal
    }

    public func reminderOccurrences(
        after date: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0 else { return [] }
        let today = calendar.startOfDay(for: date)
        var result: [Date] = []
        for offset in 0...14 {
            guard result.count < limit,
                  let day = calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }
            let weekdayNumber = calendar.component(.weekday, from: day)
            let schedule = (weekdayNumber == 1 || weekdayNumber == 7) ? weekend : weekday
            guard let schedule, schedule.isValid else { continue }
            for minute in stride(from: schedule.start, to: schedule.end, by: schedule.interval) {
                guard result.count < limit,
                      let candidate = calendar.date(
                        bySettingHour: minute / 60,
                        minute: minute % 60,
                        second: 0,
                        of: day
                      ) else {
                    continue
                }
                if candidate > date {
                    result.append(candidate)
                }
            }
        }
        return result
    }
}

public struct CompanionTodaySummary: Codable, Equatable, Sendable {
    public let day: String
    public let goal: Int
    public let total: Int

    public init(day: String, goal: Int, total: Int) {
        self.day = day
        self.goal = goal
        self.total = total
    }

    public func isCurrentDay(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let currentDay = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return day == currentDay
    }
}
