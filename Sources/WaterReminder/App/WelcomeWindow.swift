import AppKit
import SwiftUI
import WaterCore

@MainActor
final class WelcomeWindow {
    static let shared = WelcomeWindow()
    private let completedKey = "welcomeCompleted.v1"
    private var window: NSWindow?

    func showIfNeeded() {
        let stateFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bobo.WaterReminder/state.json")
        let existingState = FileManager.default.fileExists(atPath: stateFile.path)
        let defaults = UserDefaults.standard
        guard WelcomePolicy.shouldShow(completed: defaults.bool(forKey: completedKey),
                                       existingState: existingState) else {
            if existingState { defaults.set(true, forKey: completedKey) }
            return
        }
        show()
    }

    func show() {
        if window == nil {
            let content = WelcomeView { [weak self] in
                guard let self else { return }
                UserDefaults.standard.set(true, forKey: self.completedKey)
                self.window?.close()
            }
            let host = NSHostingView(rootView: content)
            let size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "欢迎使用 喝水BO～"
            window.contentView = host
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
