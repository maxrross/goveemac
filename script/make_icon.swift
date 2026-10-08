// Generates the project's original vector-drawn icon using AppKit.
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let folder = root.appendingPathComponent("work/GoveeMac.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

func drawIcon(size: Int, name: String) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 512
    let transform = AffineTransform(scale: scale)
    (transform as NSAffineTransform).concat()
    let bounds = NSRect(x: 22, y: 22, width: 468, height: 468)
    let background = NSBezierPath(roundedRect: bounds, xRadius: 108, yRadius: 108)
    NSGradient(colors: [NSColor(srgbRed: 0.05, green: 0.76, blue: 0.67, alpha: 1), NSColor(srgbRed: 0.025, green: 0.30, blue: 0.38, alpha: 1)])!.draw(in: background, angle: -70)
    NSColor.white.withAlphaComponent(0.07).setFill()
    NSBezierPath(ovalIn: NSRect(x: 56, y: 56, width: 400, height: 400)).fill()
    NSColor.white.withAlphaComponent(0.08).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 86, y: 86, width: 340, height: 340))
    ring.lineWidth = 2; ring.stroke()
    NSColor.white.setStroke()
    let bulb = NSBezierPath()
    bulb.move(to: NSPoint(x: 220, y: 178))
    bulb.line(to: NSPoint(x: 220, y: 205))
    bulb.curve(to: NSPoint(x: 180, y: 285), controlPoint1: NSPoint(x: 214, y: 228), controlPoint2: NSPoint(x: 180, y: 242))
    bulb.curve(to: NSPoint(x: 256, y: 363), controlPoint1: NSPoint(x: 180, y: 331), controlPoint2: NSPoint(x: 213, y: 363))
    bulb.curve(to: NSPoint(x: 332, y: 285), controlPoint1: NSPoint(x: 299, y: 363), controlPoint2: NSPoint(x: 332, y: 331))
    bulb.curve(to: NSPoint(x: 292, y: 205), controlPoint1: NSPoint(x: 332, y: 242), controlPoint2: NSPoint(x: 298, y: 228))
    bulb.line(to: NSPoint(x: 292, y: 178))
    bulb.line(to: NSPoint(x: 220, y: 178))
    bulb.lineWidth = 15; bulb.lineJoinStyle = .round; bulb.lineCapStyle = .round; bulb.stroke()
    let base = NSBezierPath()
    base.move(to: NSPoint(x: 231, y: 150)); base.line(to: NSPoint(x: 281, y: 150))
    base.lineWidth = 13; base.lineCapStyle = .round; base.stroke()
    let filament = NSBezierPath()
    filament.move(to: NSPoint(x: 234, y: 214)); filament.line(to: NSPoint(x: 234, y: 265))
    filament.line(to: NSPoint(x: 278, y: 265)); filament.line(to: NSPoint(x: 278, y: 214))
    filament.lineWidth = 9; filament.lineJoinStyle = .round; filament.lineCapStyle = .round; filament.stroke()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not render icon") }
    try data.write(to: folder.appendingPathComponent(name))
    if size == 512 { try data.write(to: root.appendingPathComponent("docs/icon.png")) }
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size, name: "icon_\(size)x\(size).png")
    try drawIcon(size: size * 2, name: "icon_\(size)x\(size)@2x.png")
}
