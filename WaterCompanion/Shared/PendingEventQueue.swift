import Foundation

public struct PendingEventQueue: Codable, Equatable, Sendable {
    public private(set) var events: [PhoneDrinkEvent]

    public init(events: [PhoneDrinkEvent] = []) {
        var seen = Set<String>()
        self.events = events
            .filter { seen.insert($0.recordID).inserted }
            .sorted(by: Self.isOrderedBefore)
    }

    @discardableResult
    public mutating func enqueue(_ event: PhoneDrinkEvent) -> Bool {
        guard !events.contains(where: { $0.recordID == event.recordID }) else {
            return false
        }
        events.append(event)
        events.sort(by: Self.isOrderedBefore)
        return true
    }

    @discardableResult
    public mutating func remove(recordID: String) -> PhoneDrinkEvent? {
        guard let index = events.firstIndex(where: { $0.recordID == recordID }) else {
            return nil
        }
        return events.remove(at: index)
    }

    private static func isOrderedBefore(_ left: PhoneDrinkEvent, _ right: PhoneDrinkEvent) -> Bool {
        if left.timestamp != right.timestamp {
            return left.timestamp < right.timestamp
        }
        return left.recordID < right.recordID
    }
}
