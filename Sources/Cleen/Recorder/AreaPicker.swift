import AppKit
import SwiftUI

/// Drag a rectangle on any screen to record just that part, as Screen Studio's Area
/// mode: the rest dims, Return or the button starts, Esc gives up.
final class AreaPicker {
    struct Pick {
        let screen: NSScreen
        /// In the screen's points, top-left origin.
        let rect: CGRect
    }

    private var windows: [OverlayWindow] = []
    private var continuation: CheckedContinuation<Pick?, Never>?
    private var monitor: Any?

    func pick() async -> Pick? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            for screen in NSScreen.screens {
                let window = OverlayWindow(frame: screen.frame, level: .screenSaver, ignoresMouse: false, content: AreaPickerView(
                    done: { [weak self] rect in self?.finish(rect.map { Pick(screen: screen, rect: $0) }) }
                ))
                window.orderFrontRegardless()
                windows.append(window)
            }
            NSApp.activate()
            windows.first { $0.screen == NSScreen.main }?.makeKey()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.finish(nil); return nil }
                return event
            }
        }
    }

    private func finish(_ pick: Pick?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
        let pending = continuation
        continuation = nil
        pending?.resume(returning: pick)
    }
}

private struct AreaPickerView: View {
    let done: (CGRect?) -> Void
    @State private var start: CGPoint?
    @State private var rect: CGRect?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // Everything but the picked rectangle, dimmed.
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    if let rect { path.addRect(rect) }
                }
                .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                if let rect {
                    Rectangle()
                        .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                    Text(verbatim: "\(Int(rect.width)) × \(Int(rect.height))")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(.black.opacity(0.7), in: .capsule)
                        .offset(x: rect.minX, y: max(4, rect.minY - 30))
                    if start == nil, rect.width > 40, rect.height > 40 {
                        HStack(spacing: 8) {
                            Button("Cancelar") { done(nil) }
                                .buttonStyle(OverlayButtonStyle(prominent: false))
                            Button("Gravar") { done(rect) }
                                .buttonStyle(OverlayButtonStyle(prominent: true))
                                .keyboardShortcut(.defaultAction)
                        }
                        .offset(x: rect.midX - 90, y: min(proxy.size.height - 50, rect.maxY + 12))
                    }
                } else {
                    Text("Arraste para escolher a área. Esc cancela.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(.black.opacity(0.6), in: .capsule)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                if start == nil { start = value.startLocation }
                rect = CGRect(x: min(value.startLocation.x, value.location.x), y: min(value.startLocation.y, value.location.y),
                              width: abs(value.location.x - value.startLocation.x), height: abs(value.location.y - value.startLocation.y))
            }.onEnded { _ in
                start = nil
            })
        }
        .onHover { _ in NSCursor.crosshair.set() }
    }
}

/// The light pill buttons the recorder shows over the screen.
struct OverlayButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? .white : .primary)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(prominent ? Color.red : Color.white.opacity(0.9), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .environment(\.colorScheme, .light)
    }
}
