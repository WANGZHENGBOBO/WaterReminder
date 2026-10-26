import AppKit
import Combine
import SwiftUI
import WaterCore

@MainActor
final class MenuBarPanelController: NSObject {
    private let store: WaterStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: NSPanel?
    private var anchorButton: NSRect = .zero
    private var anchorScreen: NSRect = .zero
    private var globalClick: Any?
    private var localClick: Any?
    private var subscriptions = Set<AnyCancellable>()

    init(store: WaterStore) {
        self.store = store
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "喝水BO～")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.font = .systemFont(ofSize: 11)
            button.target = self
            button.action = #selector(togglePanel)
        }
        updateLabel()
        store.$state.combineLatest(store.$now).sink { [weak self] _, _ in
            self?.updateLabel()
        }.store(in: &subscriptions)
    }

    private func updateLabel() {
        item.button?.title = store.completed ? "✓" : "\(Int(store.progress * 100))%"
        item.button?.setAccessibilityLabel("喝水BO～，今日完成百分之\(Int(store.progress * 100))")
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { closePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let button = item.button, let buttonWindow = button.window else { return }
        anchorButton = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        anchorScreen = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchorButton
        let maximumHeight = min(anchorButton.minY, anchorScreen.maxY) - anchorScreen.minY
        let view = TopAnchoredViewport(maximumHeight: maximumHeight, onSizeChange: { [weak self] size in
            // Resize in the same layout transaction. Deferring one run-loop turn
            // briefly drew the footer over newly inserted history cells.
            self?.resizePanel(to: size)
        }) { [weak self, store = self.store] in
            DashboardView(store: store,
                                 onOpenSettings: { [weak self] in
                                     guard let self else { return }
                                     self.closePanel()
                                     SettingsWindow.shared.show(store: self.store)
                                 })
        }
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        let size = CGSize(width: 350, height: min(480, maximumHeight))
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.contentView = host
        self.panel = panel
        placePanel(size: size)
        panel.makeKeyAndOrderFront(nil)
        globalClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
        localClick = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel, weak buttonWindow] event in
            if event.window !== panel && event.window !== buttonWindow { self?.closePanel() }
            return event
        }
    }

    private func resizePanel(to size: CGSize) {
        guard let panel, panel.isVisible, size.width > 0, size.height > 0 else { return }
        let old = panel.frame.size
        guard abs(old.width - size.width) > 0.5 || abs(old.height - size.height) > 0.5 else { return }
        placePanel(size: size)
    }

    private func placePanel(size: CGSize) {
        guard let panel else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(PopoverAnchor.panelFrame(button: anchorButton, content: size, visible: anchorScreen), display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        CATransaction.commit()
    }

    private func closePanel() {
        panel?.orderOut(nil)
        panel = nil
        if let globalClick { NSEvent.removeMonitor(globalClick); self.globalClick = nil }
        if let localClick { NSEvent.removeMonitor(localClick); self.localClick = nil }
    }

    deinit {
        if let globalClick { NSEvent.removeMonitor(globalClick) }
        if let localClick { NSEvent.removeMonitor(localClick) }
        NSStatusBar.system.removeStatusItem(item)
    }
}
