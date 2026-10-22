import SwiftUI

struct AgendaEventRow: View {
    let event: AgendaEvent

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(nsColor: event.color))
                .frame(width: 3.5, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(NotchStyle.bodyMedium)
                    .lineLimit(1)
                Text(event.timeText)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
