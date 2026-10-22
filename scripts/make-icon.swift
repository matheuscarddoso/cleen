// Renders Cleen's app icon into an .iconset folder.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit
import CoreGraphics

let output = URL(filePath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// A four-point glint whose sides curve inward. `pinch` sets how thin the arms are.
func glint(center: CGPoint, radius: CGFloat, pinch: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let tips = [
        CGPoint(x: center.x, y: center.y + radius),
        CGPoint(x: center.x + radius, y: center.y),
        CGPoint(x: center.x, y: center.y - radius),
        CGPoint(x: center.x - radius, y: center.y),
    ]
    path.move(to: tips[0])
    for index in 0..<4 {
        let next = tips[(index + 1) % 4]
        path.addQuadCurve(to: next, control: CGPoint(
            x: center.x + (tips[index].x - center.x + next.x - center.x) * pinch,
            y: center.y + (tips[index].y - center.y + next.y - center.y) * pinch
        ))
    }
    path.closeSubpath()
    return path
}

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

    context.saveGState()
    context.addPath(shape)
    context.clip()
    let background = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [0.13, 0.12, 0.12, 1])!,
        CGColor(colorSpace: space, components: [0.035, 0.035, 0.04, 1])!,
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Warm light pooling behind the glint.
    let glow = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [0.91, 0.79, 0.56, 0.32])!,
        CGColor(colorSpace: space, components: [0.91, 0.79, 0.56, 0])!,
    ] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 520), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 520), endRadius: 400, options: [])
    context.restoreGState()

    // Hairline rim, brighter at the top like light catching an edge.
    context.saveGState()
    context.addPath(shape)
    context.setLineWidth(3)
    context.replacePathWithStrokedPath()
    context.clip()
    let rim = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [1, 1, 1, 0.22])!,
        CGColor(colorSpace: space, components: [1, 1, 1, 0.03])!,
    ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(rim, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // Main glint with a champagne-to-pale gradient.
    let star = glint(center: CGPoint(x: 512, y: 520), radius: 250, pinch: 0.13)
    context.saveGState()
    context.addPath(star)
    context.clip()
    let metal = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [1.0, 0.95, 0.84, 1])!,
        CGColor(colorSpace: space, components: [0.91, 0.79, 0.56, 1])!,
        CGColor(colorSpace: space, components: [0.72, 0.58, 0.36, 1])!,
    ] as CFArray, locations: [0, 0.55, 1])!
    context.drawLinearGradient(metal, start: CGPoint(x: 400, y: 770), end: CGPoint(x: 640, y: 270), options: [])
    context.restoreGState()

    // A small companion glint, top right.
    context.addPath(glint(center: CGPoint(x: 718, y: 724), radius: 64, pinch: 0.15))
    context.setFillColor(CGColor(colorSpace: space, components: [1.0, 0.94, 0.82, 0.9])!)
    context.fillPath()

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
