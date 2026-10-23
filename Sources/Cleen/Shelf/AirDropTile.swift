import AppKit
import SwiftUI

/// Click to AirDrop everything on the shelf; drop files here to AirDrop them directly.
struct AirDropTile: View {
    @Environment(ShelfModel.self) private var shelf
    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        Button(action: send) {
            VStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isTargeted ? Color(red: 0.2, green: 0.55, blue: 1) : NotchStyle.primary)
                    .symbolEffect(.variableColor.iterative, isActive: isTargeted)
                VStack(spacing: 2) {
                    Text("AirDrop")
                        .font(.system(size: 12.5, weight: .medium))
                    Text(shelf.items.isEmpty ? String(localized: "Envie para aparelhos por perto") : sendTitle)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isTargeted || isHovered ? NotchStyle.control.opacity(0.6) : .clear, in: .rect(cornerRadius: 14, style: .continuous))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            shelf.airDrop(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.smooth(duration: 0.15), value: isTargeted)
        .help("Solte arquivos aqui para enviar por AirDrop")
    }

    private var sendTitle: String {
        let count = shelf.items.count
        return count.counted(String(localized: "Enviar \(count) arquivo"), String(localized: "Enviar \(count) arquivos"))
    }

    /// Sends what's on the shelf, or lets you pick files when it's empty.
    private func send() {
        guard shelf.items.isEmpty else {
            shelf.airDrop()
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Enviar por AirDrop")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        shelf.airDrop(panel.urls)
    }
}
