#!/usr/bin/env swift
// Draws the installer window's background: a pale window with a cone of Cleen-blue
// light running from the app down to Aplicativos, a halftone of dots inside the light,
// and a trail of grabbing hands showing the drag.
//   swift scripts/make-dmg-background.swift <out.png> <scale>
// Layout (points, top-left origin) must match the icon positions in scripts/dmg.sh.
import AppKit
import CoreImage

let size = CGSize(width: 480, height: 560)
let app = CGPoint(x: 240, y: 168)
let folder = CGPoint(x: 240, y: 408)

let output = URL(filePath: CommandLine.arguments[1])
let scale = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 2
let pixels = CGSize(width: size.width * scale, height: size.height * scale)
let space = CGColorSpace(name: CGColorSpace.displayP3)!

func context() -> CGContext {
    let context = CGContext(
        data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Top-left origin in points, like the Finder's icon positions.
    context.translateBy(x: 0, y: pixels.height)
    context.scaleBy(x: scale, y: -scale)
    return context
}

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

// MARK: Light

/// The cone: soft ellipses stacked from the icon (wide, pale) to the folder (narrow,
/// saturated), then blurred together.
func light() -> CGImage {
    let context = context()
    let steps = 28
    for step in 0..<steps {
        let t = Double(step) / Double(steps - 1)
        // Wide and pale at the icon, narrowing and deepening down to the folder: a V.
        let center = CGPoint(x: app.x, y: app.y - 10 + (folder.y - app.y - 20) * t)
        let radius = 210 - 135 * t
        let alpha = 0.03 + 0.26 * pow(t, 1.5)
        let gradient = CGGradient(colorsSpace: space, colors: [
            color(0.16 - 0.06 * t, 0.42 - 0.04 * t, 1, alpha),
            color(0.36, 0.67, 1, 0),
        ] as CFArray, locations: [0, 1])!
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: 1, y: 0.72)
        context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        context.restoreGState()
    }
    let sharp = CIImage(cgImage: context.makeImage()!)
    let blurred = sharp.clampedToExtent().applyingGaussianBlur(sigma: 24 * scale).cropped(to: sharp.extent)
    return CIContext().createCGImage(blurred, from: sharp.extent, format: .RGBA8, colorSpace: space)!
}

// MARK: Compose

let canvas = context()

// A barely cool white, lighter at the bottom.
let paper = CGGradient(colorsSpace: space, colors: [color(0.95, 0.965, 0.985), color(1, 1, 1)] as CFArray, locations: [0, 1])!
canvas.drawLinearGradient(paper, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

// The light is drawn in device space, so undo the flip around it.
let lightImage = light()
canvas.saveGState()
canvas.scaleBy(x: 1 / scale, y: -1 / scale)
canvas.translateBy(x: 0, y: -pixels.height)
canvas.draw(lightImage, in: CGRect(origin: .zero, size: pixels))
canvas.restoreGState()

// Halftone: a fine grid of white dots, visible only where the light is.
canvas.saveGState()
let mask = CIImage(cgImage: lightImage)
let maskBitmap = NSBitmapImageRep(ciImage: mask)
let spacing = 5.0
var y = spacing / 2
while y < size.height {
    var x = spacing / 2 + (Int(y / spacing) % 2 == 0 ? 0 : spacing / 2)
    while x < size.width {
        let sample = maskBitmap.colorAt(x: Int(x * scale), y: Int(y * scale))
        let strength = min(1, (sample?.alphaComponent ?? 0) * 2.2)
        if strength > 0.08 {
            canvas.setFillColor(color(1, 1, 1, 0.55 * strength))
            canvas.fillEllipse(in: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4))
        }
        x += spacing
    }
    y += spacing
}
canvas.restoreGState()

// MARK: Hands

/// The trail of the drag: open hands fading in from the icon, ending in a grab just
/// above the folder.
let graphics = NSGraphicsContext(cgContext: canvas, flipped: true)
NSGraphicsContext.current = graphics
let trail: [(CGPoint, Double, NSCursor)] = [
    (CGPoint(x: 316, y: 214), 0.22, .openHand),
    (CGPoint(x: 340, y: 256), 0.42, .openHand),
    (CGPoint(x: 344, y: 302), 0.68, .openHand),
    (CGPoint(x: 322, y: 346), 1.0, .closedHand),
]
for (point, alpha, cursor) in trail {
    let image = cursor.image
    let side = 46.0
    let rect = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
    canvas.saveGState()
    canvas.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: color(0, 0.1, 0.4, 0.18 * alpha))
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    canvas.restoreGState()
}
NSGraphicsContext.current = nil

// MARK: Caption

let caption = NSAttributedString(string: "Arraste o Cleen para Aplicativos", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(white: 0.45, alpha: 1),
])
NSGraphicsContext.current = graphics
let captionSize = caption.size()
caption.draw(at: CGPoint(x: (size.width - captionSize.width) / 2, y: size.height - 46))
NSGraphicsContext.current = nil

let image = canvas.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
rep.size = size
try rep.representation(using: .png, properties: [:])!.write(to: output)
