import AppKit
import SwiftUI

/// Click to AirDrop everything on the shelf; drop files here to AirDrop them directly.
struct AirDropTile: View {
    @Environment(ShelfModel.self) private var shelf
    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        Button(action: send) {
            VStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isTargeted ? Color(red: 0.2, green: 0.55, blue: 1) : NotchStyle.primary)
                    .symbolEffect(.variableColor.iterative, isActive: isTargeted)
                VStack(spacing: 2) {
                    Text("AirDrop")
                        .font(.system(size: 13, weight: .semibold))
                    Text(shelf.items.isEmpty ? "Envie para aparelhos por perto" : "Enviar \(shelf.items.count.counted("arquivo", "arquivos"))")
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isTargeted || isHovered ? AnyShapeStyle(NotchStyle.controlHover) : AnyShapeStyle(NotchStyle.card), in: .rect(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isTargeted ? Color(red: 0.2, green: 0.55, blue: 1) : NotchStyle.cardStroke, lineWidth: isTargeted ? 1.5 : 1)
            }
            .contentShape(.rect(cornerRadius: 16))
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

    /// Sends what's on the shelf, or lets you pick files when it's empty.
    private func send() {
        guard shelf.items.isEmpty else {
            shelf.airDrop()
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = "Enviar por AirDrop"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        shelf.airDrop(panel.urls)
    }
}
