import CleenKit
import SwiftUI

/// One color per tool and per junk category, shared by the notch and the window so a
/// thing looks the same wherever it appears.
enum ToolPalette {
    static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let pink = Color(red: 1.0, green: 0.22, blue: 0.37)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let yellow = Color(red: 0.96, green: 0.72, blue: 0.0)
    static let green = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let teal = Color(red: 0.19, green: 0.69, blue: 0.78)
    static let gray = Color(red: 0.56, green: 0.56, blue: 0.58)
    static let graphite = Color(red: 0.36, green: 0.36, blue: 0.38)

    static func color(for category: JunkCategory) -> Color {
        switch category.id {
        case "app-caches": blue
        case "logs": graphite
        case "trash": gray
        case "installers": orange
        case "mail-downloads": blue
        case "device-updates": green
        case "device-backups": teal
        case "xcode": blue
        case "xcode-archives": indigo
        case "package-managers": purple
        case "test-browsers": teal
        case "browser-caches": indigo
        default: gray
        }
    }

    static func color(for task: MaintenanceTask) -> Color {
        switch task {
        case .freeMemory: green
        case .thinSnapshots: teal
        case .flushDNS: blue
        case .reindexSpotlight: indigo
        case .rebuildLaunchServices: purple
        case .resetFontCache: orange
        case .verifyDisk: graphite
        }
    }
}
