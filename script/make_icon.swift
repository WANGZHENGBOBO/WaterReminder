import AppKit
import Foundation

// Use the system's water-drop artwork, rendered at every macOS icon size.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let extent = CGFloat(pixels)
        let base = NSBezierPath(roundedRect: NSRect(x: extent * 0.08, y: extent * 0.08,
            width: extent * 0.84, height: extent * 0.84), xRadius: extent * 0.19, yRadius: extent * 0.19)
        NSColor(calibratedRed: 0.94, green: 0.98, blue: 1, alpha: 1).setFill()
        base.fill()
        let symbol = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "水滴")!
            .withSymbolConfiguration(.init(paletteColors: [NSColor(calibratedRed: 0.08, green: 0.58, blue: 0.96, alpha: 1)]))!
        let ratio = symbol.size.width / symbol.size.height
        let height = extent * 0.62
        let width = height * ratio
        symbol.draw(in: NSRect(x: (extent - width) / 2, y: (extent - height) / 2, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
