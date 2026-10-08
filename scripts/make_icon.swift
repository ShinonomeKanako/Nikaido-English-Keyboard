import AppKit
import Foundation

let directory = URL(fileURLWithPath: "Resources/EnKeyBoard.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let frame = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.87, alpha: 1).setFill()
        NSBezierPath(roundedRect: frame.insetBy(dx: Double(pixels) * 0.03, dy: Double(pixels) * 0.03),
                     xRadius: Double(pixels) * 0.21, yRadius: Double(pixels) * 0.21).fill()
        let pixelSize = CGFloat(pixels)
        let title = NSAttributedString(string: "en", attributes: [
            .font: NSFont.systemFont(ofSize: pixelSize * 0.49, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        let bounds = title.size()
        title.draw(at: NSPoint(x: (pixelSize - bounds.width) / 2,
                               y: (pixelSize - bounds.height) / 2 + pixelSize * 0.02))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
