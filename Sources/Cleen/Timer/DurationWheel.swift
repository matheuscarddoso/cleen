import AppKit
import SwiftUI

/// A compact horizontal wheel of minutes: drag it, scroll over it (trackpad or mouse
/// wheel), or click a neighbouring number. The picked number sits in the middle pill,
/// white when it's the length in use and not one of the presets.
struct DurationWheel: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    var isHighlighted = false
    @Environment(\.isEnabled) private var isEnabled
    @State private var offset = 0.0
    @State private var dragStart: Int?
    @State private var scroll = WheelScroll()
    @State private var isHovered = false

    private let spacing = 24.0
    private let width = 124.0

    var body: some View {
        ZStack {
            Capsule()
                .fill(isHighlighted ? Color.white : NotchStyle.selection)
                .frame(width: 30, height: 20)
            ForEach(visible, id: \.self) { value in
                let distance = Double(value - minutes) + offset / spacing
                Text("\(value)")
                    .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(value == minutes && isHighlighted ? Color.black : NotchStyle.primary)
                    .opacity(value == minutes ? 1 : max(0, 0.75 - abs(distance) * 0.17))
                    .scaleEffect(1 - min(abs(distance), 3) * 0.06)
                    .frame(width: spacing, height: 24)
                    .contentShape(.rect)
                    .onTapGesture { pick(value) }
                    .offset(x: distance * spacing)
            }
        }
        .frame(width: width, height: 26)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        }
        .background(isHovered && isEnabled ? NotchStyle.controlHover : NotchStyle.control, in: .capsule)
        .contentShape(.capsule)
        .opacity(isEnabled ? 1 : 0.4)
        .gesture(drag, isEnabled: isEnabled)
        .onHover { hovering in
            isHovered = hovering
            if hovering, isEnabled {
                let binding = $minutes
                let range = range
                scroll.start { steps in
                    let next = min(range.upperBound, max(range.lowerBound, binding.wrappedValue + steps))
                    if next != binding.wrappedValue { binding.wrappedValue = next }
                }
            } else {
                scroll.stop()
            }
        }
        .onDisappear { scroll.stop() }
        .animation(.snappy(duration: 0.22), value: minutes)
        .animation(.smooth(duration: 0.15), value: isHovered)
        .accessibilityElement()
        .accessibilityLabel("Duração")
        .accessibilityValue("\(minutes) minutos")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: pick(minutes + 1)
            case .decrement: pick(minutes - 1)
            @unknown default: break
            }
        }
        .help("Arraste ou role para escolher os minutos")
    }

    /// The picked number and four on each side; the mask fades the outer ones.
    private var visible: [Int] {
        Array(max(range.lowerBound, minutes - 4)...min(range.upperBound, minutes + 4))
    }

    private func pick(_ value: Int) {
        minutes = min(range.upperBound, max(range.lowerBound, value))
    }

    /// Dragging right brings the smaller numbers in, like turning a dial. The value
    /// follows the finger; the leftover fraction of a step stays as an offset, with
    /// resistance at the ends.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let start = dragStart ?? minutes
                dragStart = start
                let steps = Int((value.translation.width / spacing).rounded())
                let next = min(range.upperBound, max(range.lowerBound, start - steps))
                let residual = value.translation.width - Double(start - next) * spacing
                // Follows the finger 1:1; the wheel's own spring is for clicks and scrolls.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if next != minutes { minutes = next }
                    offset = resisted(residual)
                }
            }
            .onEnded { _ in
                dragStart = nil
                withAnimation(.snappy(duration: 0.25)) { offset = 0 }
            }
    }

    /// Within half a step the offset follows the finger; past it (only at the ends of
    /// the range) it gives way to a fifth, like a rubber band.
    private func resisted(_ residual: Double) -> Double {
        let free = spacing / 2
        guard abs(residual) > free else { return residual }
        let beyond = (abs(residual) - free) * 0.2
        return residual < 0 ? -(free + beyond) : free + beyond
    }
}

/// Turns scroll events over the wheel into whole steps. A local monitor because
/// SwiftUI has no scroll-wheel hook for a view that isn't a scroll view; it only
/// exists while the pointer is over the wheel, and swallows those events so the
/// panel behind doesn't scroll too.
final class WheelScroll {
    private var monitor: Any?
    private var accumulated = 0.0

    func start(onStep: @escaping (Int) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            // Momentum after a flick would overshoot; the wheel follows the fingers only.
            guard event.momentumPhase.isEmpty else { return nil }
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : -event.scrollingDeltaY
            if event.hasPreciseScrollingDeltas {
                accumulated += delta
                let steps = Int(accumulated / 14)
                guard steps != 0 else { return nil }
                accumulated -= Double(steps) * 14
                onStep(-steps)
            } else if delta != 0 {
                onStep(delta > 0 ? -1 : 1)
            }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        accumulated = 0
    }
}
