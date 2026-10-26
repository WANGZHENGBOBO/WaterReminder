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
}
