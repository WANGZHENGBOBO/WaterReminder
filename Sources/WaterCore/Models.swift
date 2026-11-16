import Foundation

public struct Schedule: Codable, Equatable {
    public var enabled = true
    public var start = 11 * 60
    public var end = 19 * 60
    public var interval = 45
    public init() {}
    public var isValid: Bool { start >= 0 && end < 1440 && start < end && interval >= 5 && interval <= 240 }
}

public enum AppearanceTheme: String, Codable, CaseIterable {
    case classicBlue
    case obsidian

    public func applying(to appearance: WaveAppearance) -> WaveAppearance {
        var themed = appearance
        switch self {
        case .classicBlue:
            let defaults = WaveAppearance()
            themed.baseHex = defaults.baseHex
            themed.frontHex = defaults.frontHex
            themed.baseOpacity = defaults.baseOpacity
            themed.frontOpacity = defaults.frontOpacity
        case .obsidian:
            themed.baseHex = "#090A0C"
            themed.frontHex = "#666970"
            themed.baseOpacity = 1
            themed.frontOpacity = 0.38
        }
        return themed
    }

    public var defaultWaveAppearance: WaveAppearance {
        applying(to: WaveAppearance())
    }
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
    // Fresh installations opt in; decoded legacy settings without this key remain nil.
    public var iCloudSyncEnabled: Bool? = true
    public var lanSyncEnabled: Bool? = true
    public var lanPrimaryEnabled: Bool? = false
    public var lanShortName: String?
    public var appearanceTheme: AppearanceTheme = .classicBlue
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case weekday, weekend, serving, goal, snooze, stopAtGoal
        case waveAppearance, iCloudSyncEnabled, appearanceTheme
        case lanSyncEnabled, lanPrimaryEnabled, lanShortName
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        weekday = try values.decodeIfPresent(Schedule.self, forKey: .weekday) ?? weekday
        weekend = try values.decodeIfPresent(Schedule.self, forKey: .weekend) ?? weekend
        serving = try values.decodeIfPresent(Int.self, forKey: .serving) ?? serving
        goal = try values.decodeIfPresent(Int.self, forKey: .goal) ?? goal
        snooze = try values.decodeIfPresent(Int.self, forKey: .snooze) ?? snooze
        stopAtGoal = try values.decodeIfPresent(Bool.self, forKey: .stopAtGoal) ?? stopAtGoal
        waveAppearance = try values.decodeIfPresent(WaveAppearance.self, forKey: .waveAppearance)
        iCloudSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled)
        lanSyncEnabled = try values.decodeIfPresent(Bool.self, forKey: .lanSyncEnabled)
        lanPrimaryEnabled = try values.decodeIfPresent(Bool.self, forKey: .lanPrimaryEnabled)
        lanShortName = try values.decodeIfPresent(String.self, forKey: .lanShortName)
        appearanceTheme = try values.decodeIfPresent(AppearanceTheme.self, forKey: .appearanceTheme)
            ?? .classicBlue
    }
    public var isValid: Bool {
        weekday.isValid && weekend.isValid && (1...2000).contains(serving)
        && (1...10000).contains(goal) && (1...120).contains(snooze)
        && (waveAppearance?.isValid ?? true)
        && (lanShortName.map(LanDeviceNamer.isValidShortName) ?? true)
    }
}

public struct Drink: Codable, Identifiable, Equatable {
    public enum Source: String, Codable, Equatable {
        case phone
        case mac
        case unknown

        public init(syncSource: String) {
            let normalized = syncSource.lowercased()
            self = normalized.contains("iphone") || normalized.contains("phone") ? .phone : .mac
        }

        public var label: String {
            switch self {
            case .phone: "手机"
            case .mac: "电脑"
            case .unknown: "来源未知"
            }
        }
    }

    public var id: UUID
    public var date: Date
    public var grams: Int
    public var source: Source
    public var deviceID: String?
    public var deviceName: String?
    public var deviceShortName: String?
    public init(date: Date = Date(), grams: Int, source: Source = .mac,
                deviceID: String? = nil, deviceName: String? = nil,
                deviceShortName: String? = nil) {
        self.id = UUID(); self.date = date; self.grams = grams; self.source = source
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceShortName = deviceShortName
    }
    public init(id: UUID, date: Date, grams: Int, source: Source = .mac,
                deviceID: String? = nil, deviceName: String? = nil,
                deviceShortName: String? = nil) {
        self.id = id; self.date = date; self.grams = grams; self.source = source
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceShortName = deviceShortName
    }
    private enum CodingKeys: String, CodingKey {
        case id, date, grams, source, deviceID, deviceName, deviceShortName
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        date = try values.decode(Date.self, forKey: .date)
        grams = try values.decode(Int.self, forKey: .grams)
        source = try values.decodeIfPresent(Source.self, forKey: .source) ?? .unknown
        deviceID = try values.decodeIfPresent(String.self, forKey: .deviceID)
        deviceName = try values.decodeIfPresent(String.self, forKey: .deviceName)
        deviceShortName = try values.decodeIfPresent(String.self, forKey: .deviceShortName)
    }

    public var sourceSuffix: String {
        switch source {
        case .phone: "iphone"
        case .mac: "mac"
        case .unknown: "unknown"
        }
    }

    public var sourceDisplayLabel: String {
        if let deviceShortName, !deviceShortName.isEmpty { return deviceShortName }
        if source == .phone { return "iPH" }
        return source.label
    }

    public var sourceDetailLabel: String {
        if let deviceName, !deviceName.isEmpty { return deviceName }
        return source.label
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
