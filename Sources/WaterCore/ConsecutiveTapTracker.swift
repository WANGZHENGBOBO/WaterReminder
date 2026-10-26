import Foundation

public struct ConsecutiveTapTracker {
    private let maxInterval: TimeInterval
    private let requiredCount: Int
    private var count = 0
    private var lastTap: TimeInterval?

    public init(maxInterval: TimeInterval = 0.65, requiredCount: Int = 3) {
        self.maxInterval = maxInterval
        self.requiredCount = max(requiredCount, 1)
    }

    public mutating func register(at time: TimeInterval) -> Bool {
        if let lastTap, time - lastTap > maxInterval || time < lastTap {
            count = 0
        }
        count += 1
        lastTap = time
        guard count >= requiredCount else { return false }
        count = 0
        lastTap = nil
        return true
    }
}
