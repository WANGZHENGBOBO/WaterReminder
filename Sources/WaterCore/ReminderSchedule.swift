import Foundation

public enum ReminderSchedule {
    public static func rule(on date: Date, preferences: Preferences, calendar: Calendar = .current) -> Schedule {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday == 1 || weekday == 7) ? preferences.weekend : preferences.weekday
    }

    // Start is inclusive; the end is an exclusive quiet-time boundary.
    public static func next(after date: Date, preferences: Preferences, pausedDay: Date? = nil,
                            completedDay: Date? = nil, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if let pausedDay, calendar.isDate(day, inSameDayAs: pausedDay) { continue }
            if let completedDay, calendar.isDate(day, inSameDayAs: completedDay) { continue }
            let schedule = rule(on: day, preferences: preferences, calendar: calendar)
            guard schedule.enabled && schedule.isValid else { continue }
            for minute in stride(from: schedule.start, to: schedule.end, by: schedule.interval) {
                guard let candidate = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) else { continue }
                if candidate > date { return candidate }
            }
        }
        return nil
    }

    public static func canSnooze(to date: Date, from now: Date, preferences: Preferences,
                                 calendar: Calendar = .current) -> Bool {
        let rule = rule(on: date, preferences: preferences, calendar: calendar)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return rule.enabled && calendar.isDate(now, inSameDayAs: date) && minute >= rule.start && minute < rule.end
    }
}
