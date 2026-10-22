import CleenKit
import SwiftUI

struct JunkCategoryRow: View {
    @Environment(JunkModel.self) private var model
    let result: JunkCategoryResult
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Checkbox(state: model.state(of: result), label: result.category.title, action: toggleCategory)
                SymbolBadge(symbol: result.category.symbol)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.title)
                        .font(Theme.bodyMedium)
                    Text(result.category.summary)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 16)
                Text(result.totalSize.bytes)
                    .font(Theme.body)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
            .onTapGesture(perform: toggleExpansion)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: isExpanded ? "Recolher" : "Expandir", toggleExpansion)

            if isExpanded {
                LazyVStack(spacing: 0) {
                    ForEach(result.items) { item in
                        JunkItemRow(item: item, maxSize: result.items.first?.size ?? 1)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private func toggleCategory() {
        model.toggle(result)
    }
}
