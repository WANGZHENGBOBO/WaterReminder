import AppKit
import SwiftUI
import WaterCore

@MainActor
final class SetupGuideWindow {
    static let shared = SetupGuideWindow()
    private var window: NSWindow?

    func show(store: WaterStore) {
        if window == nil {
            let content = SetupGuideView(store: store) { [weak self] in
                self?.window?.close()
            }
            let host = NSHostingView(rootView: content)
            let size = host.fittingSize
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "喝水BO～ 首次设置说明"
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
