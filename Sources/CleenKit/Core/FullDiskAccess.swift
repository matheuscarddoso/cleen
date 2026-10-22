import Darwin
import Foundation

public enum FullDiskAccess {
    /// The TCC database is readable only by processes with Full Disk Access. Opening it
    /// is the one check that never triggers a permission prompt of its own.
    public static var isGranted: Bool {
        let fd = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        guard fd >= 0 else { return false }
        close(fd)
        return true
    }

    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
    )!
}
