import SwiftUI

/// Icon, label, a wide middle (usually a thin bar), and the value on the right.
struct NotchMeterRow<Middle: View>: View {
    let symbol: String
    let label: String
    let value: String
    var valueColor: Color = NotchStyle.primary
    var detail: String?
    /// Fixed so bars line up across rows; nil lets the label take the room (rows with
    /// nothing in the middle).
    var labelWidth: CGFloat? = 92
    var action: (() -> Void)?
    @ViewBuilder let middle: Middle
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.primary.opacity(0.85))
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
                .fixedSize(horizontal: labelWidth == nil, vertical: false)
            middle
                .frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(NotchStyle.tertiary)
                }
            }
            .lineLimit(1)
            .frame(minWidth: 70, alignment: .trailing)
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(NotchStyle.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(isHovered && action != nil ? NotchStyle.control.opacity(0.5) : .clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .onTapGesture { action?() }
        .accessibilityElement(children: .combine)
    }
}
