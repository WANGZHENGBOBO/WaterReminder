import SwiftUI

@MainActor
final class WaterReminderDelegate: NSObject, NSApplicationDelegate {
    // Capture installation state before WaterStore performs startup sync, which
    // may create state.json and would otherwise suppress first-run onboarding.
    private let hadExistingStateAtLaunch: Bool = {
        let stateFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bobo.WaterReminder/state.json")
        return FileManager.default.fileExists(atPath: stateFile.path)
    }()
    let store = WaterStore()
    private var menuBar: MenuBarPanelController?
    private var backgroundActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep,
                      .suddenTerminationDisabled,
                      .automaticTerminationDisabled],
            reason: "保持喝水提醒和 iCloud 同步在后台运行"
        )
        LaunchAtLoginController.shared.prepareAtLaunch()
        menuBar = MenuBarPanelController(store: store)
        DispatchQueue.main.async {
            WelcomeWindow.shared.showIfNeeded(
                store: self.store,
                existingState: self.hadExistingStateAtLaunch
            )
        }
        store.refreshSync()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        store.refreshSync()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.shutdown()
        if let backgroundActivity {
            ProcessInfo.processInfo.endActivity(backgroundActivity)
        }
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
