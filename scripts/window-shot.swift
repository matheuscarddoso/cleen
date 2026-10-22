// Prints the CGWindowID of the frontmost on-screen window owned by a process.
// Usage: swift scripts/window-shot.swift <owner> [title-substring]
import CoreGraphics
import Foundation

let owner = CommandLine.arguments[1]
let title = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerName as String] as? String) == owner {
    let name = window[kCGWindowName as String] as? String ?? ""
    if let title, !name.contains(title) { continue }
    if let layer = window[kCGWindowLayer as String] as? Int, layer != 0 { continue }
    print(window[kCGWindowNumber as String] as? Int ?? 0)
    exit(0)
}
exit(1)
