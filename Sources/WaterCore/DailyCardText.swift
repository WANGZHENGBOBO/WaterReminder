import Foundation

/// All copy and calendar information shown on the water gauge is generated locally.
public struct DailyCardText {
    public let dateLine: String
    public let lunarLine: String
    public let solarTerm: String?
    public let phrase: String

    private static let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
    private static let dayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                                   "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                                   "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    private static let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private static let firstParts = [
        "今天慢慢来，", "给自己微笑，", "轻轻松口气，", "别忘了喝水，", "留一点从容，",
        "把心放晴朗，", "小步也很好，", "先照顾自己，", "此刻歇一歇，", "继续向前吧，"
    ]
    private static let secondParts = [
        "好事在路上。", "你已经很好。", "一切有可能。", "清爽一点点。", "这节奏刚好。",
        "今天会发光。", "努力会发芽。", "平静有力量。", "生活有点甜。", "明天更可爱。"
    ]
    public static let phrases: [String] = firstParts.flatMap { first in secondParts.map { first + $0 } }

    public static func forDate(_ date: Date, calendar: Calendar = .current) -> DailyCardText {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let weekday = weekdays[max(0, min((parts.weekday ?? 1) - 1, 6))]

        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = calendar.timeZone
        let lunar: DateComponents
        let leapPrefix: String
        if #available(macOS 14, *) {
            lunar = chinese.dateComponents([.month, .day, .isLeapMonth], from: date)
            leapPrefix = lunar.isLeapMonth == true ? "闰" : ""
        } else {
            lunar = chinese.dateComponents([.month, .day], from: date)
            leapPrefix = ""
        }
        let lunarMonth = monthNames[max(0, min((lunar.month ?? 1) - 1, 11))]
        let lunarDay = dayNames[max(0, min((lunar.day ?? 1) - 1, 29))]
        let term = SolarTerms.current(year: parts.year ?? 0, month: month, day: day)
        let lunarLine = "农历\(leapPrefix)\(lunarMonth)月\(lunarDay)"

        let reference = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1))!
        let dayNumber = calendar.dateComponents([.day], from: reference, to: calendar.startOfDay(for: date)).day ?? 0
        let index = ((dayNumber * 37 + 17) % phrases.count + phrases.count) % phrases.count
        return DailyCardText(dateLine: "\(month)月\(day)日 \(weekday)", lunarLine: lunarLine,
                             solarTerm: term, phrase: phrases[index])
    }
}

private enum SolarTerms {
    private static let names = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
                                "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]

    static func current(year: Int, month: Int, day: Int) -> String? {
        guard let dates = datesByYear[year] else { return nil }
        let monthDay = month * 100 + day
        let index = dates.lastIndex(where: { $0 <= monthDay })
        return names[index ?? names.count - 1]
    }

    // Date-only solar terms from Hong Kong Observatory's Gregorian–Lunar
    // conversion tables (2024–2040), bundled for offline use.
    // https://www.weather.gov.hk/en/gts/time/conversion.htm
    private static let datesByYear: [Int: [Int]] = [
        2024: [106, 120, 204, 219, 305, 320, 404, 419, 505, 520, 605, 621, 706, 722, 807, 822, 907, 922, 1008, 1023, 1107, 1122, 1206, 1221],
        2025: [105, 120, 203, 218, 305, 320, 404, 420, 505, 521, 605, 621, 707, 722, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1221],
        2026: [105, 120, 204, 218, 305, 320, 405, 420, 505, 521, 605, 621, 707, 723, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2027: [105, 120, 204, 219, 306, 321, 405, 420, 506, 521, 606, 621, 707, 723, 808, 823, 908, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2028: [106, 120, 204, 219, 305, 320, 404, 419, 505, 520, 605, 621, 706, 722, 807, 822, 907, 922, 1008, 1023, 1107, 1122, 1206, 1221],
        2029: [105, 120, 203, 218, 305, 320, 404, 420, 505, 521, 605, 621, 707, 722, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1221],
        2030: [105, 120, 204, 218, 305, 320, 405, 420, 505, 521, 605, 621, 707, 723, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2031: [105, 120, 204, 219, 306, 321, 405, 420, 506, 521, 606, 621, 707, 723, 808, 823, 908, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2032: [106, 120, 204, 219, 305, 320, 404, 419, 505, 520, 605, 621, 706, 722, 807, 822, 907, 922, 1008, 1023, 1107, 1122, 1206, 1221],
        2033: [105, 120, 203, 218, 305, 320, 404, 420, 505, 521, 605, 621, 707, 722, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1221],
        2034: [105, 120, 204, 218, 305, 320, 405, 420, 505, 521, 605, 621, 707, 723, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2035: [105, 120, 204, 219, 306, 321, 405, 420, 505, 521, 606, 621, 707, 723, 807, 823, 908, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2036: [106, 120, 204, 219, 305, 320, 404, 419, 505, 520, 605, 621, 706, 722, 807, 822, 907, 922, 1008, 1023, 1107, 1122, 1206, 1221],
        2037: [105, 120, 203, 218, 305, 320, 404, 420, 505, 521, 605, 621, 707, 722, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1221],
        2038: [105, 120, 204, 218, 305, 320, 405, 420, 505, 521, 605, 621, 707, 723, 807, 823, 907, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2039: [105, 120, 204, 219, 306, 321, 405, 420, 505, 521, 606, 621, 707, 723, 807, 823, 908, 923, 1008, 1023, 1107, 1122, 1207, 1222],
        2040: [106, 120, 204, 219, 305, 320, 404, 419, 505, 520, 605, 621, 706, 722, 807, 822, 907, 922, 1008, 1023, 1107, 1122, 1206, 1221]
    ]
}
