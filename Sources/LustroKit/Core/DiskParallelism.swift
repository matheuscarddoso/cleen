import Foundation

enum DiskParallelism {
    /// How many trees to size at once. Sizing blocks a thread on file-system calls, and
    /// those threads come from Swift's shared cooperative pool (one per core): taking all
    /// of them would starve every other task in the app, UI updates included. A third of
    /// the cores keeps the SSD busy while leaving room for everything else.
    static var width: Int { max(2, ProcessInfo.processInfo.activeProcessorCount / 3) }
}
