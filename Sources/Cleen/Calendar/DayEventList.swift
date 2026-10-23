import SwiftUI

/// The picked day's events as cards with their calendar's color.
struct DayEventList: View {
    @Environment(AgendaModel.self) private var agenda
    let day: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
            let events = agenda.eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
            if agenda.calendarAccess == .denied {
                AgendaAccessLink(text: String(localized: "Permitir acesso ao Calendário"))
            } else if events.isEmpty {
                Text("Nada marcado")
                    .font(NotchStyle.body)
                    .foregroundStyle(NotchStyle.tertiary)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(events) { event in
                            DayEventCard(event: event)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollEdgeFade()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Hoje") }
        if calendar.isDateInTomorrow(day) { return String(localized: "Amanhã") }
        if calendar.isDateInYesterday(day) { return String(localized: "Ontem") }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.cleen)).capitalized
    }
}
