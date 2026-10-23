import AppKit
import QuartzCore

/// Raycast's confetti: a burst from the bottom corners of the screen under the pointer,
/// in a click-through window that goes away on its own.
enum Confetti {
    private static var window: NSWindow?

    static func fire() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main else { return }
        window?.orderOut(nil)

        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hasShadow = false
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        window.contentView = view
        window.orderFrontRegardless()
        self.window = window

        for corner in [CGFloat(0), screen.frame.width] {
            let emitter = CAEmitterLayer()
            emitter.emitterPosition = CGPoint(x: corner, y: 0)
            emitter.emitterShape = .point
            emitter.emitterCells = cells(towardsRight: corner == 0)
            emitter.beginTime = CACurrentMediaTime()
            view.layer?.addSublayer(emitter)
            // A burst, not a fountain.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { emitter.birthRate = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak window] in
            window?.orderOut(nil)
            if Self.window === window { Self.window = nil }
        }
    }

    private static func cells(towardsRight: Bool) -> [CAEmitterCell] {
        let colors: [NSColor] = [.systemPink, .systemYellow, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal, .white]
        return colors.flatMap { color in
            [confettiImage(width: 9, height: 5), confettiImage(width: 6, height: 6)].map { image in
                let cell = CAEmitterCell()
                cell.contents = image
                cell.color = color.cgColor
                cell.birthRate = 38
                cell.lifetime = 4.2
                cell.velocity = 1250
                cell.velocityRange = 420
                // Up and in towards the middle of the screen.
                cell.emissionLongitude = towardsRight ? .pi / 2.9 : .pi - .pi / 2.9
                cell.emissionRange = .pi / 9
                cell.yAcceleration = -900
                cell.spin = 4
                cell.spinRange = 8
                cell.scale = 1.1
                cell.scaleRange = 0.5
                cell.alphaSpeed = -0.18
                return cell
            }
        }
    }

    private static func confettiImage(width: Int, height: Int) -> CGImage? {
        let context = CGContext(data: nil, width: width * 2, height: height * 2, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(gray: 1, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: width * 2, height: height * 2))
        return context?.makeImage()
    }
}
