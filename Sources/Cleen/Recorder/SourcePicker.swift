import AppKit
import CleenKit
import SwiftUI

/// Choosing what to record, as in Screen Studio: the recording bar floats at the bottom of
/// the screen, and the source picked in it lays its layer over the screens: Display tints
/// the screen under the pointer and offers Start recording on it; Window does the same for
/// the window under the pointer; Area lets you drag a rectangle. None of it is recorded
/// (Cleen's windows are left out of every capture).
final class SourcePicker {
    private unowned let recorder: RecorderModel
    private let pointer = PickerPointer()
    private var pointerMonitors: [Any] = []
    private var bar: OverlayWindow?
    private var layers: [OverlayWindow] = []
    private var area: AreaPicker?
    private var keyMonitor: Any?

    /// Above the area picker, so the bar stays usable while dragging an area.
    static let barLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

    init(recorder: RecorderModel) {
        self.recorder = recorder
    }

    func show(_ mode: RecorderModel.SelectionMode) {
        showBar()
        clearLayers()
        switch mode {
        case .display:
            for screen in NSScreen.screens {
                addLayer(on: screen, content: DisplayPickLayer(screen: screen))
            }
        case .window:
            for screen in NSScreen.screens {
                addLayer(on: screen, content: WindowPickLayer(screen: screen))
            }
        case .area:
            let picker = AreaPicker()
            area = picker
            Task { [weak self] in
                let pick = await picker.pick()
                guard let self, self.area === picker else { return }
                self.area = nil
                if let pick { await self.recorder.recordArea(pick) } else if self.recorder.selecting == .area { self.recorder.cancelSelection() }
            }
        }
        trackPointer()
        NSApp.activate()
        bar?.orderFrontRegardless()
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                self?.recorder.cancelSelection()
                return nil
            }
        }
    }

    func close() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors = []
        clearLayers()
        bar?.orderOut(nil)
        bar = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func clearLayers() {
        layers.forEach { $0.orderOut(nil) }
        layers = []
        let picker = area
        area = nil
        picker?.cancel()
    }

    /// The pointer, wherever it is: the layers follow it without needing a hover event
    /// (none comes until the mouse moves, and windows of an inactive app get none).
    private func trackPointer() {
        pointer.location = NSEvent.mouseLocation
        guard pointerMonitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.pointer.location = NSEvent.mouseLocation }
        }) { pointerMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.pointer.location = NSEvent.mouseLocation
            return event
        }) { pointerMonitors.append(local) }
    }

    private func addLayer(on screen: NSScreen, content: some View) {
        let window = OverlayWindow(frame: screen.frame, level: .floating, ignoresMouse: false, content: content.environment(recorder).environment(pointer))
        window.orderFrontRegardless()
        layers.append(window)
    }

    /// The bar, centered at the bottom of the screen with the pointer, clear of the Dock.
    private func showBar() {
        guard bar == nil else { return }
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main ?? NSScreen.screens[0]
        let size = CGSize(width: 860, height: 76)
        let frame = CGRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 20, width: size.width, height: size.height)
        let window = OverlayWindow(frame: frame, level: Self.barLevel, ignoresMouse: false, content: FloatingRecorderBar().environment(recorder).injecting(recorder.app))
        window.hasShadow = false
        bar = window
    }
}

/// Where the pointer is (AppKit's global points), for the pick layers.
@Observable
final class PickerPointer {
    var location = CGPoint.zero
}

/// The recording bar on its own, floating: a close button, then the same controls as the
/// notch's.
struct FloatingRecorderBar: View {
    @Environment(RecorderModel.self) private var recorder

    var body: some View {
        HStack(spacing: 0) {
            Button { recorder.cancelSelection() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
                    .frame(width: 44, height: 52)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Fechar (Esc)")
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 36).padding(.horizontal, 4)
            RecorderToolbar(isFloating: true)
        }
        .padding(.horizontal, 8)
        .frame(height: 68)
        .background(Color(hex: 0x0E1117).opacity(0.94), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: 0x45454A), lineWidth: 1.5) }
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .padding(4)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
    }
}

/// The tint over a picked thing (a whole screen, a window) with its name, its size and
/// Start recording in the middle.
private struct PickCard: View {
    let title: String
    let detail: String
    let start: () -> Void
    @Environment(RecorderModel.self) private var recorder

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: title)
                .font(.system(size: 40, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(verbatim: detail)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 0) {
                Button(action: start) {
                    Label("Iniciar gravação", systemImage: "record.circle")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.leading, 18)
                        .padding(.trailing, 12)
                        .frame(height: 46)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1, height: 22)
                Menu {
                    Picker("Contagem regressiva", selection: Binding(get: { recorder.countdown }, set: { recorder.countdown = $0 })) {
                        Text("Sem contagem").tag(0)
                        Text("3 segundos").tag(3)
                        Text("5 segundos").tag(5)
                        Text("10 segundos").tag(10)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 40, height: 46)
                        .contentShape(.rect)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .foregroundStyle(.white)
            .background(Color(hex: 0x604EF8), in: .rect(cornerRadius: 11, style: .continuous))
            .shadow(color: Color(hex: 0x604EF8).opacity(0.45), radius: 14, y: 4)
            .padding(.top, 14)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 10)
        .environment(\.colorScheme, .dark)
    }
}

/// Screen Studio's tint over a picked area.
private let pickTint = Color(red: 0.24, green: 0.33, blue: 0.86).opacity(0.42)

/// Display mode on one screen: tinted with its card while the pointer is on it.
struct DisplayPickLayer: View {
    let screen: NSScreen
    @Environment(RecorderModel.self) private var recorder
    @Environment(PickerPointer.self) private var pointer

    var body: some View {
        let isActive = screen.frame.contains(pointer.location)
        ZStack {
            // Nearly clear but there, so clicks land on the layer and not on the apps.
            Color.black.opacity(0.001)
            if isActive {
                pickTint
                PickCard(title: screen.localizedName, detail: detail) {
                    Task { await recorder.recordDisplay(screen) }
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.18), value: isActive)
    }

    private var detail: String {
        let size = screen.frame.size
        return "\(Int(size.width))×\(Int(size.height)) · \(recorder.framesPerSecond) FPS"
    }
}

/// Window mode on one screen: the window under the pointer tinted, with its card.
struct WindowPickLayer: View {
    let screen: NSScreen
    @Environment(RecorderModel.self) private var recorder
    @Environment(PickerPointer.self) private var pointer
    @State private var target: WindowFinder.Window?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
            if let target {
                let rect = local(target.frame)
                pickTint
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5) }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                PickCard(title: target.app, detail: "\(Int(target.frame.width))×\(Int(target.frame.height)) · \(recorder.framesPerSecond) FPS") {
                    Task { await recorder.recordWindow(target.id) }
                }
                .frame(width: max(rect.width, 360), height: rect.height)
                .offset(x: rect.minX - max(0, (360 - rect.width) / 2), y: rect.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.15), value: target)
        .onChange(of: pointer.location, initial: true) { _, location in
            guard screen.frame.contains(location) else {
                target = nil
                return
            }
            let point = WindowFinder.globalTopLeft(location)
            if let target, target.frame.contains(point) { return }
            target = WindowFinder.window(at: point)
        }
    }

    /// A global top-left rect in this screen's view.
    private func local(_ rect: CGRect) -> CGRect {
        let top = WindowFinder.globalTopLeft(CGPoint(x: screen.frame.minX, y: screen.frame.maxY))
        return CGRect(x: rect.minX - top.x, y: rect.minY - top.y, width: rect.width, height: rect.height)
    }
}

/// Finds the window under a point, front to back, as the window server lists them.
nonisolated enum WindowFinder {
    struct Window: Equatable, Sendable {
        let id: CGWindowID
        let app: String
        /// Global points, top-left origin.
        let frame: CGRect
    }

    static func window(at point: CGPoint) -> Window? {
        let own = ProcessInfo.processInfo.processIdentifier
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? pid_t) != own,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let id = info[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard frame.width > 80, frame.height > 60, frame.contains(point) else { continue }
            return Window(id: id, app: info[kCGWindowOwnerName as String] as? String ?? "", frame: frame)
        }
        return nil
    }

    /// AppKit's bottom-left global point as the window server's top-left one.
    @MainActor
    static func globalTopLeft(_ point: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
