import CleenKit
import SwiftUI

/// The copies as a horizontally scrolling row of cards, pinned first.
struct ClipboardCards: View {
    @Environment(ClipboardModel.self) private var model
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
                        ForEach(entries) { entry in
                            ClipboardCard(entry: entry, isSelected: entry.id == model.selected?.id) { paste(entry) }
                                .id(entry.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
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
