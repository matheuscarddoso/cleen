import CleenKit
import SwiftUI

/// The copies as a horizontally scrolling row of cards, pinned first.
struct ClipboardCards: View {
    @Environment(ClipboardModel.self) private var model
    /// ⌘ is held: the first nine cards show the number that pastes them.
    var showsNumbers = false
    let paste: (ClipboardEntry) -> Void

    var body: some View {
        let entries = model.visible
        if entries.isEmpty {
            VStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 18))
                    .foregroundStyle(NotchStyle.tertiary)
                Text(model.log.entries.isEmpty ? "O que você copiar aparece aqui" : "Nada encontrado")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            ClipboardCard(entry: entry, isSelected: entry.id == model.selected?.id) { paste(entry) }
                                .overlay(alignment: .bottomTrailing) {
                                    if showsNumbers, index < 9 {
                                        Text(verbatim: "⌘\(index + 1)")
                                            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                                            .foregroundStyle(NotchStyle.primary)
                                            .padding(.horizontal, 5)
                                            .frame(height: 17)
                                            .background(Color(white: 0.2), in: .rect(cornerRadius: 5, style: .continuous))
                                            .padding(7)
                                            .transition(.opacity)
                                    }
                                }
                                .animation(.easeOut(duration: 0.12), value: showsNumbers)
                                .id(entry.id)
                        }
                    }
                }
                .scrollIndicators(.never)
                // Cards run to the panel's edges, not the content inset: the first card
                // still starts aligned with the search field.
                .contentMargins(.horizontal, NotchOpenContent.inset, for: .scrollContent)
                .scrollEdgeFade(.horizontal, length: 36)
                .padding(.horizontal, -NotchOpenContent.inset)
                .onChange(of: model.selectedID) { _, id in
                    if let id { withAnimation(.smooth(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }
    }
}
