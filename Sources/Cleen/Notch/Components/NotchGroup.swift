import SwiftUI

/// One quiet grouped container, rows separated by hairlines — the notch's only "box".
struct NotchGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(NotchStyle.separator)
                            .frame(height: 1)
                            .padding(.leading, 36)
                    }
                }
            }
        }
        .background(NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke)
        }
    }
}
