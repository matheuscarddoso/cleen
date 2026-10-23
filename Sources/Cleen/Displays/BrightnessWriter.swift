import CoreGraphics
import Foundation

/// Sends brightness changes one at a time per display, keeping only the newest: a drag
/// produces dozens of values a second, a monitor takes ~20 ms per message and chokes
/// when flooded. The last value always lands.
nonisolated final class BrightnessWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.cleen.brightness", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: [CGDirectDisplayID: @Sendable () -> Void] = [:]
    private var draining: Set<CGDirectDisplayID> = []

    func submit(_ display: CGDirectDisplayID, _ work: @escaping @Sendable () -> Void) {
        let start = lock.withLock {
            pending[display] = work
            return draining.insert(display).inserted
        }
        if start { queue.async { self.drain(display) } }
    }

    private func drain(_ display: CGDirectDisplayID) {
        while true {
            let work: (@Sendable () -> Void)? = lock.withLock {
                guard let next = pending.removeValue(forKey: display) else {
                    draining.remove(display)
                    return nil
                }
                return next
            }
            guard let work else { return }
            work()
        }
    }
}
