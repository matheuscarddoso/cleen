import SwiftUI

struct Breadcrumbs: View {
    @Environment(SpaceLensModel.self) private var model

    var body: some View {
        let crumbs = model.breadcrumbs
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                if crumbs.count > 1 {
                    Button("Voltar", systemImage: "chevron.left", action: model.goUp)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .keyboardShortcut("[", modifiers: .command)
                }
                ForEach(crumbs.indices, id: \.self) { index in
                    if index > 0 {
                        Image(systemName: "chevron.compact.right")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    Button(index == 0 ? model.target.title : crumbs[index].name) {
                        model.goBack(to: index)
                    }
                    .buttonStyle(.plain)
                    .font(index == crumbs.count - 1 ? Theme.bodyMedium : Theme.body)
                    .foregroundStyle(index == crumbs.count - 1 ? .primary : .secondary)
                    .disabled(index == crumbs.count - 1)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
