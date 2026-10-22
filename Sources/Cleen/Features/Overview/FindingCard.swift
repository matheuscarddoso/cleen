import SwiftUI

struct FindingCard: View {
    let route: Route
    /// nil while the area is still being scanned.
    let value: String?
    let detail: String
    var detailIsWarning = false
    let open: (Route) -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ToolIcon(symbol: route.filledSymbol, color: ToolPalette.color(for: route), size: 28)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .offset(x: isHovered ? 2 : 0)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                    Group {
                        if let value {
                            Text(value)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .font(Theme.display(26))
                    .monospacedDigit()
                    .frame(height: 32, alignment: .leading)
                    Text(detail)
                        .font(Theme.caption)
                        .foregroundStyle(detailIsWarning ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.tertiary))
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(isHovered ? Theme.surfaceHover : Theme.surface, in: .rect(cornerRadius: Theme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large).strokeBorder(Theme.hairline)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.large))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Theme.quick, value: isHovered)
        .accessibilityLabel(route.title)
        .accessibilityValue([value, detail].compactMap { $0 }.joined(separator: ", "))
    }

    private func select() {
        open(route)
    }
}
