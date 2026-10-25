import SwiftUI

struct MenuBarLabel: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage(MenuBarDisplay.storageKey) private var display = MenuBarDisplay.freeSpace

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: Self.icon)
            if let text {
                Text(text)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("Cleen")
        .accessibilityValue(text ?? "")
    }

    /// The app icon at menu bar size, cropped to its body: the icon grid keeps it at 824 of
    /// 1024 points, and the margin around it (where the shadow falls) would only shrink it.
    private static let icon: NSImage = {
        let source = NSApp.applicationIconImage ?? NSImage()
        let inset = source.size.width * 100 / 1024
        return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            source.draw(in: rect, from: NSRect(origin: .zero, size: source.size).insetBy(dx: inset, dy: inset), operation: .sourceOver, fraction: 1)
            return true
        }
    }()

    private var text: String? {
        switch display {
        case .iconOnly:
            nil
        case .freeSpace:
            monitor.disk.map { $0.available.bytes }
        case .cpu:
            monitor.cpu.map { $0.total.percent }
        case .memory:
            monitor.memory.map { $0.usedFraction.percent }
        }
    }
}
