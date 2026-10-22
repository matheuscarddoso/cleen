import SwiftUI

struct DayEventCard: View {
    let event: AgendaEvent

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(Color(nsColor: event.color))
                .frame(width: 3.5)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(event.timeText)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(height: 46)
        .background(NotchStyle.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(NotchStyle.cardStroke)
        }
        .accessibilityElement(children: .combine)
    }
}
