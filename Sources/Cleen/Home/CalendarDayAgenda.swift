import SwiftUI

/// The picked day's events (and, for today, open reminders), or a quiet empty state.
struct CalendarDayAgenda: View {
    @Environment(AgendaModel.self) private var agenda
    let day: Date

    var body: some View {
        let events = agenda.events(on: day)
        let reminders = Calendar.current.isDateInToday(day) ? Array(agenda.reminders.prefix(2)) : []
        Group {
            if agenda.calendarAccess == .denied {
                AgendaAccessLink(text: "Permitir acesso ao Calendário")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if events.isEmpty && reminders.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 13))
                        .foregroundStyle(NotchStyle.tertiary)
                    Text(Calendar.current.isDateInToday(day) ? "Nada para hoje" : "Nada neste dia")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events.prefix(reminders.isEmpty ? 2 : 1)) { event in
                        AgendaEventRow(event: event)
                    }
                    ForEach(reminders.prefix(events.isEmpty ? 2 : 1)) { reminder in
                        AgendaReminderRow(reminder: reminder)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: 70)
    }
}
