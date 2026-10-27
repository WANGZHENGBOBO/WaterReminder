import Foundation

public struct Schedule: Codable, Equatable {
    public var enabled = true
    public var start = 11 * 60
    public var end = 19 * 60
    public var interval = 45
    public init() {}
    public var isValid: Bool { start >= 0 && end < 1440 && start < end && interval >= 5 && interval <= 240 }
}

public struct WaveAppearance: Codable, Equatable {
    public var height = 3.0
    public var speed = 0.8
    public var frontHeight: Double { height * 0.85 }
    public var frontSpeed: Double { speed * 1.15 }
    public var baseHex = "#0080FF"
    public var frontHex = "#FFFFFF"
    public var baseOpacity = 1.0
    public var frontOpacity = 0.16
    public var fishCount = 1
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case height, speed, baseHex, frontHex, baseOpacity, frontOpacity, fishCount
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        height = try values.decodeIfPresent(Double.self, forKey: .height) ?? height
        speed = try values.decodeIfPresent(Double.self, forKey: .speed) ?? speed
        baseHex = try values.decodeIfPresent(String.self, forKey: .baseHex) ?? baseHex
        frontHex = try values.decodeIfPresent(String.self, forKey: .frontHex) ?? frontHex
        baseOpacity = try values.decodeIfPresent(Double.self, forKey: .baseOpacity) ?? baseOpacity
        frontOpacity = try values.decodeIfPresent(Double.self, forKey: .frontOpacity) ?? frontOpacity
        fishCount = try values.decodeIfPresent(Int.self, forKey: .fishCount) ?? fishCount
    }
    public var isValid: Bool {
        (0...10).contains(height) && (0.2...3).contains(speed)
            && (0...1).contains(baseOpacity) && (0...1).contains(frontOpacity)
            && (0...6).contains(fishCount)
            && Self.isHexColor(baseHex) && Self.isHexColor(frontHex)
    }
    public static func isHexColor(_ value: String) -> Bool {
        value.count == 7 && value.first == "#" && UInt32(value.dropFirst(), radix: 16) != nil
    }
    public static func hex(red: Double, green: Double, blue: Double) -> String {
        func channel(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }
}

public struct Preferences: Codable, Equatable {
    public var weekday = Schedule()
    public var weekend = Schedule()
    public var serving = 197
    public var goal = 1800
    public var snooze = 10
    public var stopAtGoal = true
    // Optional so pre-wave settings decode without migration.
    public var waveAppearance: WaveAppearance?
    // Optional so existing local-only settings remain readable and opt out by default.
    public var iCloudSyncEnabled: Bool?
    public init() {}
    public var isValid: Bool {
        weekday.isValid && weekend.isValid && (1...2000).contains(serving)
        && (1...10000).contains(goal) && (1...120).contains(snooze)
        && (waveAppearance?.isValid ?? true)
    }
}

public struct Drink: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var grams: Int
    public init(date: Date = Date(), grams: Int) {
        self.id = UUID(); self.date = date; self.grams = grams
    }
    public init(id: UUID, date: Date, grams: Int) {
        self.id = id; self.date = date; self.grams = grams
    }
}

public struct SavedState: Codable {
    public var preferences = Preferences()
    public var drinks: [Drink] = []
    public var pausedDay: Date?
    public var handledNotifications: [String] = []
    // Optional so existing state.json files remain readable.
    public var celebratedMilestones: [String: [Int]]?
    public init() {}
    public func total(on date: Date, calendar: Calendar = .current) -> Int {
        drinks.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.grams }
    }
}
