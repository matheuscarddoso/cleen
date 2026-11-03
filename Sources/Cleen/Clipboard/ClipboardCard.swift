import AppKit
import CleenKit
import SwiftUI

/// One copy: the source app and how long ago on top, the content below. Pin and remove
/// appear on hover; a click pastes it.
struct ClipboardCard: View {
    @Environment(ClipboardModel.self) private var model
    let entry: ClipboardEntry
    let isSelected: Bool
    let paste: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                if let app = sourceApp {
                    FileIcon(url: app, size: 14)
                }
                Text(age)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                Spacer(minLength: 0)
                if isHovered || entry.pinned {
                    CardButton(symbol: entry.pinned ? "pin.fill" : "pin", help: entry.pinned ? String(localized: "Desafixar") : String(localized: "Fixar")) { model.togglePin(entry) }
                }
                if isHovered {
                    CardButton(symbol: "xmark", help: String(localized: "Apagar do histórico"), action: delete)
                }
            }
            .frame(height: 16)
            ClipboardCardContent(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(Metrics.padding)
        .frame(width: Metrics.width, height: Metrics.height)
        .background(NotchStyle.card, in: .rect(cornerRadius: Metrics.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .strokeBorder(isSelected ? NotchStyle.primary.opacity(0.35) : NotchStyle.cardStroke)
        }
        .contentShape(.rect(cornerRadius: Metrics.radius))
        .onHover { isHovered = $0 }
        .onTapGesture(perform: paste)
        .contextMenu {
            Button("Colar", action: paste)
            Button("Copiar") { model.copy(entry) }
            Button(entry.pinned ? String(localized: "Desafixar") : String(localized: "Fixar")) { model.togglePin(entry) }
            Divider()
            Button("Apagar do histórico", role: .destructive, action: delete)
        }
        .help(entry.kind == .image ? entry.title : (entry.text ?? entry.title))
    }

    /// One click takes it out of the history.
    private func delete() {
        withAnimation(.smooth(duration: 0.25)) { model.delete(entry) }
    }

    private var sourceApp: URL? {
        entry.sourceBundleID.flatMap(AppLocator.url(for:))
    }

    /// "1h", "2min", "3d", like OmniNotch.
    private var age: String {
        let seconds = Date.now.timeIntervalSince(entry.lastCopied)
        switch seconds {
        case ..<60: return String(localized: "agora")
        case ..<3600: return String(localized: "\(Int(seconds / 60))min")
        case ..<86_400: return String(localized: "\(Int(seconds / 3600))h")
        default: return String(localized: "\(Int(seconds / 86_400))d")
        }
    }
}
