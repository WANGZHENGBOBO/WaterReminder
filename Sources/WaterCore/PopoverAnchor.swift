import Foundation
import CoreGraphics

public struct PopoverAnchor {
    private let topLeft: CGPoint

    public init(frame: CGRect, topY: CGFloat? = nil) {
        topLeft = CGPoint(x: frame.origin.x, y: topY ?? (frame.origin.y + frame.size.height))
    }

    public func origin(for size: CGSize) -> CGPoint {
        CGPoint(x: topLeft.x, y: topLeft.y - size.height)
    }

    public func correctedFrame(_ frame: CGRect) -> CGRect {
        CGRect(origin: origin(for: frame.size), size: frame.size)
    }

    public static func screenContaining(_ button: CGRect, screens: [CGRect]) -> CGRect? {
        let center = CGPoint(x: button.midX, y: button.midY)
        return screens.first { $0.contains(center) }
    }

    public static func panelFrame(button: CGRect, content: CGSize, visible: CGRect) -> CGRect {
        let top = min(button.minY, visible.maxY)
        let width = min(content.width, visible.width)
        let height = min(content.height, max(0, top - visible.minY))
        let x = min(max(button.midX - width / 2, visible.minX), visible.maxX - width)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}
