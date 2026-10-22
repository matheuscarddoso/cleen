import SwiftUI

struct AgendaEventRow: View {
    let event: AgendaEvent

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(nsColor: event.color))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(event.timeText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
