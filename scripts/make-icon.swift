// Renders Cleen's app icon into an .iconset folder.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit
import CoreGraphics

let output = URL(filePath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(size: Int) -> Data? {
    let scale = CGFloat(size) / 1024
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.displayP3)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high

    // macOS icon grid: 824 pt body centered on a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)
    let space = CGColorSpace(name: CGColorSpace.displayP3)!

    // A native-utility look: saturated blue squircle, light from above, one white glyph.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let background = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [0.36, 0.67, 1.0, 1])!,
        CGColor(colorSpace: space, components: [0.10, 0.40, 0.96, 1])!,
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Soft sheen across the top half, like the system icons.
    let sheen = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [1, 1, 1, 0.22])!,
        CGColor(colorSpace: space, components: [1, 1, 1, 0])!,
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 520), options: [])
    context.restoreGState()

    // Hairline rim.
    context.saveGState()
    context.addPath(shape)
    context.setLineWidth(3)
    context.setStrokeColor(CGColor(colorSpace: space, components: [1, 1, 1, 0.25])!)
    context.strokePath()
    context.restoreGState()

    // The glyph: SF Symbols' internal drive, white, with a soft drop shadow.
    let configuration = NSImage.SymbolConfiguration(pointSize: 360, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let size = symbol.size
        let rect = CGRect(x: 512 - size.width / 2, y: 505 - size.height / 2, width: size.width, height: size.height)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(colorSpace: space, components: [0, 0.1, 0.4, 0.35])!)
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        symbol.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

for base in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = base * factor
        let name = factor == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        guard let data = render(size: pixels) else { fatalError("Render failed at \(pixels)px") }
        try data.write(to: output.appending(path: name))
    }
}
print("Wrote \(output.path)")
