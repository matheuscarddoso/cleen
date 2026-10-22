import LustroKit
import SwiftUI

struct LeftoverList: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(
                text: "Espalhado pelo Mac",
                trailing: model.leftovers.isEmpty ? nil : model.leftovers.reduce(0) { $0 + $1.size }.bytes
            )
            if model.isLoadingLeftovers {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if model.leftovers.isEmpty {
                Text("Nada além do próprio app.")
                    .font(Theme.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .surface(padding: 0)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.leftovers) { leftover in
                        LeftoverRow(
                            leftover: leftover,
                            isSelected: model.leftoverSelection.contains(leftover.url),
                            toggle: { model.toggle(leftover) }
                        )
                    }
                }
                .surface(padding: 4)
            }
        }
    }
}
