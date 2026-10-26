import AppKit
import CleenKit

/// Samples the pointer 60 times a second while a recording runs, and notes every click,
/// relative to the recorded area. Mouse events need no permission to watch.
final class CursorRecorder {
    /// The recorded area in global screen coordinates (points, top-left origin); asked
    /// again now and then, since a recorded window can move.
    private let area: () -> CGRect
    private var timer: Timer?
    private var monitors: [Any] = []
    private var start = Date.now
    private var currentArea = CGRect.zero
    private var lastAreaCheck = Date.distantPast
    private(set) var track = CursorTrack()

    init(area: @escaping () -> CGRect) {
        self.area = area
    }

    func begin() {
        start = .now
        track = CursorTrack()
        currentArea = area()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in self?.click() }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.click()
            return event
        }) { monitors.append(local) }
        sample()
    }

    func end() -> CursorTrack {
        timer?.invalidate()
        timer = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        return track
    }

    private var now: Double { Date.now.timeIntervalSince(start) }

    private func sample() {
        if Date.now.timeIntervalSince(lastAreaCheck) > 0.5 {
            currentArea = area()
            lastAreaCheck = .now
        }
        guard let point = normalized() else { return }
        track.samples.append(.init(t: now, x: point.x, y: point.y))
    }

    private func click() {
        guard let point = normalized() else { return }
        track.clicks.append(.init(t: now, x: point.x, y: point.y))
    }

    /// The pointer in 0…1 of the area (it may be outside, below 0 or above 1).
    private func normalized() -> CGPoint? {
        guard currentArea.width > 0, currentArea.height > 0 else { return nil }
        let location = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let global = CGPoint(x: location.x, y: primaryHeight - location.y)
        return CGPoint(x: (global.x - currentArea.minX) / currentArea.width, y: (global.y - currentArea.minY) / currentArea.height)
    }
}
