import SwiftUI

/// One line of a page's list: an icon in a soft tile, a label with an optional note,
/// and whatever control the line needs on the right.
struct OnboardingRow<Trailing: View>: View {
    let symbol: String
    let title: String
    var note: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(NotchStyle.primary.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(NotchStyle.card, in: .rect(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(NotchStyle.cardStroke)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let note {
                    Text(note)
                        .font(.system(size: 11.5))
                        .foregroundStyle(NotchStyle.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 10)
            trailing
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

extension OnboardingRow where Trailing == EmptyView {
    init(symbol: String, title: String, note: String? = nil) {
        self.init(symbol: symbol, title: title, note: note) { EmptyView() }
    }
}
