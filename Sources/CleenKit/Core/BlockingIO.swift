import Dispatch

/// Where blocking file-system work runs.
///
/// Walking a disk blocks a thread in `read`/`stat` for seconds. Swift's cooperative pool
/// has one thread per core and every `await` in the app shares it, so running that work
/// there starves everything else (UI updates, EventKit callbacks) until it finishes.
/// This hands the work to a GCD queue instead — the one deliberate use of GCD in the
/// project — and suspends the caller without holding a pool thread.
public enum BlockingIO {
    private static let queue = DispatchQueue(label: "app.cleen.blocking-io", qos: .utility, attributes: .concurrent)

    public static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }
}
