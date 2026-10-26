import Foundation

public enum HistoryPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    public var id: String { rawValue }
    public var title: String {
        switch self { case .day: "日"; case .week: "周"; case .month: "月"; case .year: "年" }
    }
    public var component: Calendar.Component {
        switch self { case .day: .day; case .week: .weekOfYear; case .month: .month; case .year: .year }
    }
}

public struct HistoryBucket: Identifiable {
    public let start: Date
    public let grams: Int
    public let count: Int
    public let inPeriod: Bool
    public let intensity: Int
    public var id: Date { start }
}

public enum HistoryReport {
    private static func mondayCalendar(_ calendar: Calendar) -> Calendar {
        var result = calendar
        result.firstWeekday = 2
        result.minimumDaysInFirstWeek = 4
        return result
    }

    public static func interval(for period: HistoryPeriod, anchor: Date, calendar: Calendar = .current) -> DateInterval {
        let calendar = mondayCalendar(calendar)
        return calendar.dateInterval(of: period.component, for: anchor)!
    }

    public static func cells(drinks: [Drink], period: HistoryPeriod, anchor: Date,
                             goal: Int, serving: Int, calendar: Calendar = .current) -> [HistoryBucket] {
        let calendar = mondayCalendar(calendar)
        let range = interval(for: period, anchor: anchor, calendar: calendar)
        if period == .day {
            return (0..<24).map { hour in
                let start = calendar.date(byAdding: .hour, value: hour, to: range.start)!
                let end = calendar.date(byAdding: .hour, value: 1, to: start)!
                return bucket(drinks: drinks, start: start, end: end, inPeriod: true, target: serving)
            }
        }
        let gridStart = period == .week ? range.start : calendar.dateInterval(of: .weekOfYear, for: range.start)!.start
        let gridEnd = period == .week ? range.end : calendar.dateInterval(of: .weekOfYear,
                                for: range.end.addingTimeInterval(-1))!.end
        var result: [HistoryBucket] = []
        var cursor = gridStart
        while cursor < gridEnd {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor)!
            result.append(bucket(drinks: drinks, start: cursor, end: next,
                                 inPeriod: cursor >= range.start && cursor < range.end, target: goal))
            cursor = next
        }
        return result
    }

    private static func bucket(drinks: [Drink], start: Date, end: Date, inPeriod: Bool, target: Int) -> HistoryBucket {
        let matches = drinks.filter { $0.date >= start && $0.date < end }
        let grams = matches.reduce(0) { $0 + $1.grams }
        let ratio = Double(grams) / Double(max(target, 1))
        let intensity = grams == 0 ? 0 : ratio < 0.2 ? 1 : ratio < 0.4 ? 2 : ratio < 0.6 ? 3 : ratio < 0.8 ? 4 : 5
        return HistoryBucket(start: start, grams: grams, count: matches.count, inPeriod: inPeriod, intensity: intensity)
    }

    public static func csv(drinks: [Drink], from start: Date, through end: Date,
                           calendar: Calendar = .current) -> String? {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        guard first <= last, let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        let selected = drinks.filter { $0.date >= first && $0.date < exclusiveEnd }.sorted { $0.date < $1.date }
        guard !selected.isEmpty else { return nil }
        let dayFormat = DateFormatter()
        dayFormat.calendar = calendar
        dayFormat.timeZone = calendar.timeZone
        dayFormat.locale = Locale(identifier: "en_US_POSIX")
        dayFormat.dateFormat = "yyyy-MM-dd"
        let timeFormat = DateFormatter()
        timeFormat.calendar = calendar
        timeFormat.timeZone = calendar.timeZone
        timeFormat.locale = Locale(identifier: "en_US_POSIX")
        timeFormat.dateFormat = "HH:mm:ss"
        let rows = selected.map { "\(dayFormat.string(from: $0.date)),\(timeFormat.string(from: $0.date)),\($0.grams)" }
        return "\u{FEFF}日期,时间,喝水量(ml)\r\n" + rows.joined(separator: "\r\n") + "\r\n"
    }
}
