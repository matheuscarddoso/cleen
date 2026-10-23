import Foundation
import IOKit.ps

/// Tells when the power source changes (plugged in, unplugged, charge level steps),
/// straight from IOKit's notification rather than by polling.
public final class PowerSourceWatcher: @unchecked Sendable {
    private var source: CFRunLoopSource?
    private let onChange: () -> Void

    /// `onChange` runs on the main run loop.
    public init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<PowerSourceWatcher>.fromOpaque(context).takeUnretainedValue().onChange()
        }, context)?.takeRetainedValue() else { return }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
    }
}
