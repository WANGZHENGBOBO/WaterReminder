import AppKit
import SwiftUI

@MainActor
final class LayoutProbe: ObservableObject {
    @Published var height: CGFloat = 400
    weak var header: NSView?
}

struct HeaderProbe: NSViewRepresentable {
    let probe: LayoutProbe
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        probe.header = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

struct ProbeDocument: View {
    @ObservedObject var probe: LayoutProbe
    var body: some View {
        VStack(spacing: 0) {
            HeaderProbe(probe: probe).frame(height: 20)
            Color.blue.frame(height: probe.height - 20)
        }.frame(width: 350)
    }
}

@main
struct PopupLayoutChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard let screen = NSScreen.main else { fatalError("No desktop screen available") }
        let visible = screen.visibleFrame
        let button = CGRect(x: visible.midX, y: visible.maxY, width: 50, height: 24)
        let probe = LayoutProbe()
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        let root = TopAnchoredViewport(maximumHeight: visible.height, onSizeChange: { size in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            panel.setFrame(PopoverAnchor.panelFrame(button: button, content: size, visible: visible), display: false)
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
            CATransaction.commit()
        }) { ProbeDocument(probe: probe) }
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(PopoverAnchor.panelFrame(button: button, content: CGSize(width: 350, height: 480), visible: visible), display: true)
        panel.orderFrontRegardless()
        Task { @MainActor in
            // Repeated expand/collapse includes content larger than the screen.
            for height: CGFloat in [400, 650, visible.height + 300, 400, 700, 400] {
                probe.height = height
                // Inspect intermediate frames too, not just the settled geometry.
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(16))
                    if let header = probe.header {
                        let top = panel.convertToScreen(header.convert(header.bounds, to: nil)).maxY
                        precondition(abs(top - button.minY) < 1, "Transient header jump: \(top)")
                    }
                }
                let expectedHeight = min(height, visible.height)
                precondition(abs(panel.frame.maxY - button.minY) < 1, "Window top moved: \(panel.frame)")
                precondition(abs(panel.frame.height - expectedHeight) < 1, "Wrong viewport height: \(panel.frame.height), expected \(expectedHeight)")
                guard let header = probe.header else { fatalError("Header not mounted") }
                let headerFrame = panel.convertToScreen(header.convert(header.bounds, to: nil))
                precondition(abs(headerFrame.maxY - panel.frame.maxY) < 1,
                             "Header clipped/centered: header=\(headerFrame), panel=\(panel.frame)")
                print("PASS content=\(height), viewport=\(panel.frame.height), windowTop=\(panel.frame.maxY), headerTop=\(headerFrame.maxY)")
            }
            panel.orderOut(nil)
            exit(0)
        }
        app.run()
    }
}
