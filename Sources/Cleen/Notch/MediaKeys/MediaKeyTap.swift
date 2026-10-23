import AppKit
import CleenKit

/// A session event tap that sees the volume and brightness keys before macOS does, so
/// it can keep them (and the system's on-screen display) for Cleen. It runs on its own
/// thread with its own run loop: a busy main thread would make every key press wait,
/// and macOS turns off taps that answer slowly.
nonisolated final class MediaKeyTap: @unchecked Sendable {
    /// Gets every media key press on the tap's thread; true keeps the event from macOS.
    typealias Handler = @Sendable (MediaKey.Press, _ fine: Bool) -> Bool

    let handler: Handler
    private let lock = NSLock()
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var isStopped = false

    private init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Creates the tap and starts listening, or nil without Accessibility.
    static func start(handler: @escaping Handler) -> MediaKeyTap? {
        let tap = MediaKeyTap(handler: handler)
        let mask = CGEventMask(1) << CGEventMask(MediaKey.systemDefinedEventType)
        // Unretained: the thread below holds the tap for as long as the callback can run.
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(tap).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { return nil }
        tap.port = port
        tap.source = source

        let thread = Thread {
            guard let port = tap.port, let source = tap.source else { return }
            let loop = CFRunLoopGetCurrent()
            let proceed = tap.lock.withLock {
                guard !tap.isStopped else { return false }
                tap.runLoop = loop
                return true
            }
            guard proceed else { return }
            CFRunLoopAddSource(loop, source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            CFRunLoopRun()
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        thread.name = "app.cleen.media-keys"
        thread.qualityOfService = .userInteractive
        thread.start()
        return tap
    }

    /// Gives the keys back to macOS. Safe to call more than once.
    func stop() {
        let loop: CFRunLoop? = lock.withLock {
            guard !isStopped else { return nil }
            isStopped = true
            return runLoop
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let loop { CFRunLoopStop(loop) }
    }

    /// macOS switches a tap off when it stalls or on some secure-input changes; turn it
    /// straight back on so the keys don't fall back to the system halfway through.
    fileprivate func reenable() {
        guard let port, !lock.withLock({ isStopped }) else { return }
        CGEvent.tapEnable(tap: port, enable: true)
    }
}

/// The tap's C callback, on the tap's thread. Anything that isn't a volume or
/// brightness key goes through untouched.
private nonisolated func mediaKeyTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, info: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let passed = Unmanaged.passUnretained(event)
    guard let info else { return passed }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(info).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        tap.reenable()
        return passed
    }
    guard type.rawValue == MediaKey.systemDefinedEventType,
          let system = NSEvent(cgEvent: event),
          let press = MediaKey.decode(subtype: Int(system.subtype.rawValue), data1: system.data1)
    else { return passed }
    let flags = event.flags
    let fine = flags.contains(.maskAlternate) && flags.contains(.maskShift)
    return tap.handler(press, fine) ? nil : passed
}
