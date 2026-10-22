import AppKit
import SwiftUI

/// The "something is playing" glyph: thin bars breathing out of phase.
///
/// Animated by Core Animation, not by SwiftUI frames: the render server drives the
/// motion at the display's own refresh rate, so it never hitches when the app is busy
/// and stays smooth on a 1× external monitor. Only horizontal edges are snapped to the
/// pixel grid (crisp bars); heights stay fractional so motion is continuous, not stepped.
struct SoundBars: NSViewRepresentable {
    var isPlaying = true
    var color = NSColor.white.withAlphaComponent(0.92)

    static let barCount = 4
    static let barWidth = 2.0
    static let spacing = 2.0
    static let maxHeight = 13.0
    static let minHeight = 3.0

    static var size: CGSize {
        CGSize(width: Double(barCount) * barWidth + Double(barCount - 1) * spacing, height: maxHeight)
    }

    func makeNSView(context: Context) -> SoundBarsView {
        SoundBarsView()
    }

    func updateNSView(_ view: SoundBarsView, context: Context) {
        view.color = color
        view.isPlaying = isPlaying
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SoundBarsView, context: Context) -> CGSize? {
        Self.size
    }
}

final class SoundBarsView: NSView {
    private var bars: [CALayer] = []

    var color = NSColor.white {
        didSet { bars.forEach { $0.backgroundColor = color.cgColor } }
    }

    var isPlaying = false {
        didSet { if isPlaying != oldValue { restartAnimations() } }
    }

    override init(frame: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: SoundBars.size))
        wantsLayer = true
        for _ in 0..<SoundBars.barCount {
            let bar = CALayer()
            bar.cornerRadius = SoundBars.barWidth / 2
            bar.backgroundColor = color.cgColor
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layoutBars()
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    private func layoutBars() {
        let scale = window?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            bar.contentsScale = scale
            // Whole device pixels horizontally, centred vertically.
            let x = ((Double(index) * (SoundBars.barWidth + SoundBars.spacing)) * scale).rounded() / scale
            bar.bounds = CGRect(x: 0, y: 0, width: SoundBars.barWidth, height: SoundBars.minHeight)
            bar.position = CGPoint(x: x + SoundBars.barWidth / 2, y: bounds.midY)
        }
        CATransaction.commit()
        restartAnimations()
    }

    private func restartAnimations() {
        for (index, bar) in bars.enumerated() {
            bar.removeAllAnimations()
            guard isPlaying else {
                bar.bounds.size.height = SoundBars.minHeight
                continue
            }
            bar.add(Self.breathing(index: index), forKey: "breathing")
        }
    }

    /// A looping height animation with its own rhythm per bar, so they never sync up.
    private static func breathing(index: Int) -> CAKeyframeAnimation {
        let patterns: [[Double]] = [
            [0.35, 0.9, 0.5, 1.0, 0.3, 0.75, 0.35],
            [0.8, 0.4, 1.0, 0.55, 0.85, 0.3, 0.8],
            [0.5, 1.0, 0.35, 0.7, 0.45, 0.95, 0.5],
            [0.9, 0.45, 0.7, 0.3, 1.0, 0.6, 0.9],
        ]
        let durations = [1.9, 2.3, 1.7, 2.1]
        let levels = patterns[index % patterns.count]
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
        animation.values = levels.map { SoundBars.minHeight + (SoundBars.maxHeight - SoundBars.minHeight) * $0 }
        animation.duration = durations[index % durations.count]
        animation.calculationMode = .cubic
        animation.repeatCount = .infinity
        // Different starting points in the loop.
        animation.beginTime = CACurrentMediaTime() - Double(index) * 0.37
        animation.isRemovedOnCompletion = false
        return animation
    }
}
