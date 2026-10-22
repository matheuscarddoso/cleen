import CleenKit
import SwiftUI

struct ToolCleanupRow: View {
    @Environment(JunkModel.self) private var model
    let tool: ToolCleanup

    var body: some View {
        HStack(spacing: 14) {
            Checkbox(state: model.selectedTools.contains(tool.kind) ? .on : .off, label: tool.title, action: toggle)
            SymbolBadge(symbol: tool.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(Theme.bodyMedium)
                Text(tool.summary)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                Text(tool.detail)
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 16)
            Text(tool.reclaimable.bytes)
                .font(Theme.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func toggle() {
        model.toggle(tool)
    }
}
