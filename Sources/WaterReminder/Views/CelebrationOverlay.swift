import AppKit
import QuartzCore
import SwiftUI

private struct Celebration: Identifiable {
    let id: UUID
    let level: Int
}

struct CelebrationOverlay: View {
    let feedback: DrinkFeedback?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active: Celebration?

    var body: some View {
        GeometryReader { _ in
            if let active, !reduceMotion {
                ConfettiEmitter(id: active.id, level: active.level)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: feedback?.id) { id in
            guard let id, let level = feedback?.milestone, !reduceMotion else { return }
            Task { @MainActor in
                active = Celebration(id: id, level: level)
                try? await Task.sleep(for: .seconds(3.5))
                if active?.id == id { active = nil }
            }
        }
    }
}

private struct ConfettiEmitter: NSViewRepresentable {
    let id: UUID
    let level: Int

    func makeNSView(context: Context) -> ConfettiView {
        ConfettiView()
    }

    func updateNSView(_ view: ConfettiView, context: Context) {
        view.celebrate(id: id, level: level)
    }
}

private final class ConfettiView: NSView {
    private var shownID: UUID?
    private var emitter: CAEmitterLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        emitter?.frame = bounds
        emitter?.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.57)
    }

    func celebrate(id: UUID, level: Int) {
        guard shownID != id else { return }
        shownID = id
        emitter?.removeFromSuperlayer()

        let colors: [NSColor] = [.systemBlue, .systemGreen, .systemYellow, .systemPink, .systemPurple, .systemOrange]
        let colorCount = level >= 100 ? 6 : level >= 80 ? 5 : 4
        let rate: Float = level >= 100 ? 18 : level >= 80 ? 12 : 7
        let cells = colors.prefix(colorCount).flatMap { color in
            (0..<3).map { shape in
                let cell = CAEmitterCell()
                cell.contents = Self.particleImage(shape: shape)
                cell.color = color.cgColor
                cell.birthRate = rate * (shape == 0 ? 0.7 : 1)
                cell.lifetime = 3.2
                cell.lifetimeRange = 0.5
                cell.velocity = 150
                cell.velocityRange = 75
                cell.emissionLongitude = .pi / 2
                cell.emissionRange = .pi * 0.9
                cell.yAcceleration = -95
                cell.spin = 1.5
                cell.spinRange = 3
                cell.scale = 0.7
                cell.scaleRange = 0.25
                return cell
            }
        }
        let layer = CAEmitterLayer()
        layer.frame = bounds
        layer.emitterPosition = CGPoint(x: bounds.midX, y: bounds.height * 0.57)
        layer.emitterShape = .point
        layer.emitterCells = cells
        self.layer?.addSublayer(layer)
        emitter = layer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak layer] in layer?.birthRate = 0 }
    }

    private static func particleImage(shape: Int) -> CGImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: 28, height: 28, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        switch shape {
        case 0: // Curved streamer.
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(3.5)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: 3, y: 3))
            context.addCurve(to: CGPoint(x: 24, y: 25), control1: CGPoint(x: 29, y: 6), control2: CGPoint(x: 0, y: 21))
            context.strokePath()
        case 1: // Five-point star.
            for point in 0..<10 {
                let angle = CGFloat(point) * .pi / 5 - .pi / 2
                let radius: CGFloat = point.isMultiple(of: 2) ? 12 : 5
                let vertex = CGPoint(x: 14 + cos(angle) * radius, y: 14 + sin(angle) * radius)
                if point == 0 { context.move(to: vertex) } else { context.addLine(to: vertex) }
            }
            context.closePath()
            context.fillPath()
        default: // Small dot.
            context.fillEllipse(in: CGRect(x: 9, y: 9, width: 10, height: 10))
        }
        return context.makeImage()
    }
}
