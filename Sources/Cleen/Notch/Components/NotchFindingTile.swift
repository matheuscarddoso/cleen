import SwiftUI

struct NotchFindingTile: View {
    let symbol: String
    let color: Color
    let title: String
    /// nil until the area has been scanned.
    let value: String?
    var isScanning = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ToolIcon(symbol: symbol, color: color, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.secondary)
                        .lineLimit(1)
                    Group {
                        if isScanning {
                            ProgressView().controlSize(.mini).tint(.white)
                        } else {
                            Text(value ?? "—")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .frame(height: 16, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? AnyShapeStyle(NotchStyle.controlHover) : AnyShapeStyle(NotchStyle.card), in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "não analisado")
    }
}
