import SwiftUI

struct MenuBarLabel: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow
    @AppStorage(MenuBarDisplay.storageKey) private var display = MenuBarDisplay.freeSpace

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
            if let text {
                Text(text)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("Cleen")
        .accessibilityValue(text ?? "")
        // The notch panel lives outside SwiftUI's scenes; it asks for the window here,
        // where `openWindow` is available for the app's whole life.
        .onReceive(NotificationCenter.default.publisher(for: .cleenOpenMainWindow)) { _ in
            openWindow(id: MainWindow.id)
            NSApp.activate()
        }
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
