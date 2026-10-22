import SwiftUI

/// An open reminder with a circle that checks it off, like in Reminders.
struct AgendaReminderRow: View {
    @Environment(AgendaModel.self) private var agenda
    let reminder: AgendaReminder
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: complete) {
                Image(systemName: isHovered ? "checkmark.circle" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? NotchStyle.primary : NotchStyle.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .accessibilityLabel("Concluir \(reminder.title)")
            Text(reminder.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(reminder.isOverdue ? NotchStyle.critical : NotchStyle.primary)
                .lineLimit(1)
        }
    }

    private func complete() {
        withAnimation(.smooth(duration: 0.25)) { agenda.complete(reminder) }
    }
}
