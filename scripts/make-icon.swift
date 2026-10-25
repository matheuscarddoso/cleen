// Renders Cleen's app icon into an .iconset folder from the artwork in
// Support/Icon/artwork.png: the illustrated squircle on a white page.
// Usage: swift scripts/make-icon.swift <output.iconset> [master.png]
//
// The page is cut away along the artwork's own outline: the white reachable from the
// image's edges is the page, the rest is the icon. The outline is pulled a few pixels in
// and softened, so no white fringe survives, and the body is placed on the macOS icon
// grid (824 pt on a 1024 canvas) with the template's soft shadow.
import AppKit
import CoreGraphics
import CoreImage

let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = URL(filePath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
let masterOutput = CommandLine.arguments.count > 2 ? URL(filePath: CommandLine.arguments[2]) : nil
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

guard let source = NSImage(contentsOf: root.appending(path: "Support/Icon/artwork.png")),
      let artwork = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let bitmap = NSBitmapImageRep(data: source.tiffRepresentation!)
else { fatalError("Support/Icon/artwork.png is missing") }

/// The artwork's straight edges: where the middle row and column stop being white.
func bounds() -> CGRect {
    func white(_ x: Int, _ y: Int) -> Bool {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return true }
        return min(color.redComponent, color.greenComponent, color.blueComponent) > 0.965
    }
    let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
    let columns = (0..<width).filter { !white($0, height / 2) }
    let rows = (0..<height).filter { !white(width / 2, $0) }
    guard let left = columns.first, let right = columns.last, let top = rows.first, let bottom = rows.last else { fatalError("no artwork found") }
    // Bitmap rows run top-down; CoreGraphics' y runs up.
    return CGRect(x: left, y: height - 1 - bottom, width: right - left + 1, height: bottom - top + 1)
}

/// The icon's silhouette as a grayscale mask the size of the artwork: flood-fills the
/// near-white page in from the borders, then erodes and softens the edge.
func silhouette(erode: Int = 3, soften: Double = 1.1) -> CGImage {
    let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
    var page = [Bool](repeating: false, count: width * height)
    func paper(_ x: Int, _ y: Int) -> Bool {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return true }
        return min(color.redComponent, color.greenComponent, color.blueComponent) > 0.93
    }
    var queue: [(Int, Int)] = []
    for x in 0..<width { queue.append((x, 0)); queue.append((x, height - 1)) }
    for y in 0..<height { queue.append((0, y)); queue.append((width - 1, y)) }
    var head = 0
    while head < queue.count {
        let (x, y) = queue[head]; head += 1
        guard x >= 0, y >= 0, x < width, y < height, !page[y * width + x], paper(x, y) else { continue }
        page[y * width + x] = true
        queue.append((x + 1, y)); queue.append((x - 1, y)); queue.append((x, y + 1)); queue.append((x, y - 1))
    }
    // Pull the edge in: any pixel within `erode` of the page joins it.
    var grown = page
    for y in 0..<height {
        for x in 0..<width where page[y * width + x] {
            for dy in -erode...erode {
                for dx in -erode...erode where dx * dx + dy * dy <= erode * erode {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0, ny >= 0, nx < width, ny < height { grown[ny * width + nx] = true }
                }
            }
        }
    }
    var pixels = grown.map { $0 ? UInt8(0) : UInt8(255) }
    let gray = CGColorSpaceCreateDeviceGray()
    let hard = pixels.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue)!.makeImage()!
    }
    let soft = CIImage(cgImage: hard).clampedToExtent().applyingGaussianBlur(sigma: soften).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    return CIContext().createCGImage(soft, from: soft.extent, format: .L8, colorSpace: gray)!
}

let space = CGColorSpace(name: CGColorSpace.displayP3)!
let art = bounds()
let mask = silhouette()

/// The 1024 master: the cut-out body on the grid, with the template's drop shadow.
func master() -> CGImage {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    // The artwork, scaled so its edges meet the body's.
    let scaleX = body.width / art.width, scaleY = body.height / art.height
    let drawn = CGRect(
        x: body.minX - art.minX * scaleX,
        y: body.minY - art.minY * scaleY,
        width: CGFloat(artwork.width) * scaleX,
        height: CGFloat(artwork.height) * scaleY
    )
    // Shadow first, cast by the silhouette.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: CGColor(gray: 0, alpha: 0.3))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.clip(to: drawn, mask: mask)
    context.setFillColor(CGColor(srgbRed: 0.72, green: 0.84, blue: 0.98, alpha: 1))
    context.fill(drawn)
    context.endTransparencyLayer()
    context.restoreGState()
    context.saveGState()
    context.clip(to: drawn, mask: mask)
    context.draw(artwork, in: drawn)
    context.restoreGState()
    return context.makeImage()!
}

func png(_ image: CGImage, size: Int) -> Data? {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let scaled = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: scaled).representation(using: .png, properties: [:])
}

let image = master()
if let masterOutput, let data = png(image, size: 1024) { try data.write(to: masterOutput) }
for base in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let size = base * factor
        let name = factor == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try png(image, size: size)?.write(to: output.appending(path: name))
    }
}
