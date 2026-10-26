import SwiftUI

@MainActor
final class WaterReminderDelegate: NSObject, NSApplicationDelegate {
    let store = WaterStore()
    private var menuBar: MenuBarPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarPanelController(store: store)
        DispatchQueue.main.async { WelcomeWindow.shared.showIfNeeded() }
    }
}

@main
struct WaterReminderApp: App {
    @NSApplicationDelegateAdaptor(WaterReminderDelegate.self) private var delegate
    var body: some Scene {
        Settings {
            SettingsView(store: delegate.store)
        }
    }
}
