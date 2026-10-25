// Renders the menu bar icon from the cut-out mascot, its light halo pulled in, trimmed
// and scaled to 64 px tall (16 pt at 4x).
// Usage: swift scripts/make-menubar-icon.swift Support/Icon/mascot.png Support/Brand/MenuBarIcon.png
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
let src = CIImage(contentsOf: URL(filePath: CommandLine.arguments[1]))!
let out = URL(filePath: CommandLine.arguments[2])
// Alpha as a mask, eroded 6 px (the halo), softened.
let alpha = src.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
let hard = alpha.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.85])
let eroded = hard.applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": 6]).applyingGaussianBlur(sigma: 1.2).cropped(to: src.extent)
let clean = src.applyingFilter("CIBlendWithMask", parameters: ["inputBackgroundImage": CIImage.empty(), "inputMaskImage": eroded])
let ctx = CIContext()
let cg = ctx.createCGImage(clean, from: src.extent)!
// Trim to the visible pixels.
let rep = NSBitmapImageRep(cgImage: cg)
var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
for y in stride(from: 0, to: rep.pixelsHigh, by: 2) { for x in stride(from: 0, to: rep.pixelsWide, by: 2) where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
let box = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
let trimmed = cg.cropping(to: box)!
// 64 px tall (4x of 16 pt), width to scale.
let h = 64.0, w = (h * box.width / box.height).rounded()
let c = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
c.interpolationQuality = .high
c.draw(trimmed, in: CGRect(x: 0, y: 0, width: w, height: h))
try! NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: out)
print(Int(w), Int(h))
