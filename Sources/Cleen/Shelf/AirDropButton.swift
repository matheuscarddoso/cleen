import AppKit
import SwiftUI

/// AirDrop's own color in the shelf: a deep blue that reads as "send" on true black,
/// lifting when something hovers or is dragged over it.
enum AirDropStyle {
    static let fill = Color(red: 0.05, green: 0.15, blue: 0.3)
    static let hover = Color(red: 0.08, green: 0.23, blue: 0.45)
    static let accent = Color(red: 0.42, green: 0.7, blue: 1)
    static let symbol = "dot.radiowaves.left.and.right"
}

/// The header's AirDrop button: sends the selection, or everything when nothing is
/// picked, or lets you choose files when the shelf is empty. Files dropped on it go
/// straight to AirDrop.
struct AirDropButton: View {
    @Environment(ShelfModel.self) private var shelf
    @Environment(NotchState.self) private var notch
    @State private var isHovered = false
    @State private var isTargeted = false

    var body: some View {
        Button(action: send) {
            HStack(spacing: 6) {
                Image(systemName: AirDropStyle.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isTargeted || isHovered ? AirDropStyle.accent : NotchStyle.primary.opacity(0.85))
                    .symbolEffect(.variableColor.iterative, isActive: isTargeted)
                Text("AirDrop")
                    .font(NotchStyle.bodyMedium)
                if !shelf.selection.isEmpty {
                    Text(shelf.selection.count, format: .number.locale(.cleen))
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(NotchStyle.primary.opacity(0.14), in: .capsule)
                        .contentTransition(.numericText())
                        .transition(.scale(0.6).combined(with: .opacity))
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, shelf.selection.isEmpty ? 11 : 5)
            .frame(height: 24)
            .background(isTargeted || isHovered ? AirDropStyle.hover : AirDropStyle.fill, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            shelf.airDrop(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .animation(.smooth(duration: 0.15), value: isTargeted)
        .animation(.smooth(duration: 0.2), value: shelf.selection.count)
        .help(help)
        .accessibilityLabel(help)
    }

    private var help: String {
        if shelf.items.isEmpty { return String(localized: "Escolher arquivos para enviar por AirDrop") }
        let count = shelf.targetURLs.count
        return count.counted(String(localized: "Enviar \(count) arquivo por AirDrop"), String(localized: "Enviar \(count) arquivos por AirDrop"))
    }

    private func send() {
        guard shelf.items.isEmpty else {
            shelf.airDrop(shelf.targetURLs)
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Enviar por AirDrop")
        let heldBefore = notch.holdsOpen
        notch.holdsOpen = true
        NSApp.activate()
        defer { notch.holdsOpen = heldBefore }
        guard panel.runModal() == .OK else { return }
        shelf.airDrop(panel.urls)
    }
}
