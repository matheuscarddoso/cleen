import SwiftUI

struct MenuBarLabel: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage(MenuBarDisplay.storageKey) private var display = MenuBarDisplay.freeSpace

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
            if let text {
                Text(text)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("Lustro")
        .accessibilityValue(text ?? "")
    }

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
