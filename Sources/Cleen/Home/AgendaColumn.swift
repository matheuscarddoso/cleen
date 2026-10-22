import SwiftUI

/// "Hoje ›" and "Lembretes ›": the day's next events and the open reminders.
struct AgendaColumn: View {
    @Environment(AgendaModel.self) private var agenda

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                NotchSectionLink(symbol: "calendar", title: "Hoje", action: AgendaModel.openCalendar)
                switch agenda.calendarAccess {
                case .denied:
                    AgendaAccessLink(text: "Permitir acesso ao Calendário")
                case .unknown:
                    EmptyView()
                case .granted where agenda.events.isEmpty:
                    Text("Nada na agenda hoje")
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.tertiary)
                case .granted:
                    ForEach(agenda.events.prefix(2)) { event in
                        AgendaEventRow(event: event)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                NotchSectionLink(symbol: "list.bullet", title: "Lembretes", action: AgendaModel.openReminders)
                switch agenda.remindersAccess {
                case .denied:
                    AgendaAccessLink(text: "Permitir acesso aos Lembretes")
                case .unknown:
                    EmptyView()
                case .granted where agenda.reminders.isEmpty:
                    Text("Tudo feito")
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.tertiary)
                case .granted:
                    ForEach(agenda.reminders.prefix(2)) { reminder in
                        AgendaReminderRow(reminder: reminder)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
