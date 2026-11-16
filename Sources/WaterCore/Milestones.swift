public struct MilestoneUpdate: Equatable {
    public let celebrated: [Int]
    public let triggered: Int?

    public init(celebrated: [Int], triggered: Int?) {
        self.celebrated = celebrated
        self.triggered = triggered
    }
}

public enum Milestones {
    public static let levels = [60, 80, 100]

    public static func retained(_ celebrated: [Int], at total: Int, goal: Int) -> [Int] {
        guard goal > 0 else { return [] }
        return celebrated.filter { total * 100 >= goal * $0 }
    }

    public static func crossed(from oldTotal: Int, to newTotal: Int, goal: Int,
                               alreadyCelebrated: [Int]) -> [Int] {
        guard goal > 0 else { return [] }
        let stillCelebrated = retained(alreadyCelebrated, at: oldTotal, goal: goal)
        return levels.filter { level in
            !stillCelebrated.contains(level)
                && oldTotal * 100 < goal * level
                && newTotal * 100 >= goal * level
        }
    }

    public static func update(celebrated: [Int], from oldTotal: Int, to newTotal: Int,
                              goal: Int) -> MilestoneUpdate {
        let retained = retained(celebrated, at: oldTotal, goal: goal)
        let crossed = crossed(from: oldTotal, to: newTotal, goal: goal,
                              alreadyCelebrated: retained)
        return MilestoneUpdate(
            celebrated: Array(Set(retained).union(crossed)).sorted(),
            triggered: crossed.max()
        )
    }

    public static func reconcile(celebrated: [Int], total: Int, goal: Int) -> MilestoneUpdate {
        guard goal > 0 else { return MilestoneUpdate(celebrated: [], triggered: nil) }
        let retained = retained(celebrated, at: total, goal: goal)
        let missing = levels.filter {
            !retained.contains($0) && total * 100 >= goal * $0
        }
        return MilestoneUpdate(
            celebrated: Array(Set(retained).union(missing)).sorted(),
            triggered: missing.max()
        )
    }
}
