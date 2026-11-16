public enum SettingsSaveFlow {
    @discardableResult
    public static func perform(save: () -> Bool, close: () -> Void) -> Bool {
        guard save() else { return false }
        close()
        return true
    }
}
