import AppKit

// Asset packaging only: preserve the selected artwork, fit it into a macOS
// rounded tile with transparent outer margins, and export every 1x/2x slot.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let source = root.appendingPathComponent("selected-origami.png")
let output = root.appendingPathComponent("../../Toolbox/Assets.xcassets/AppIcon.appiconset").standardizedFileURL
guard let image = NSImage(contentsOf: source) else { fatalError("Missing selected artwork") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for size in [16, 32, 64, 128, 256, 512, 1024] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Bitmap allocation failed") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let scale = CGFloat(size) / 1024
    let tile = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    NSBezierPath(roundedRect: tile, xRadius: 185 * scale, yRadius: 185 * scale).addClip()
    image.draw(in: tile, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
    try png.write(to: output.appendingPathComponent("icon-\(size).png"))
}
print("Exported AppIcon sizes 16–1024 px to \(output.path)")
