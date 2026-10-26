public enum WelcomePolicy {
    public static func shouldShow(completed: Bool, existingState: Bool) -> Bool {
        !completed && !existingState
    }
}
