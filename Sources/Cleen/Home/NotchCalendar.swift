import SwiftUI

/// Calendar as in NotchNook: the month, a strip of days you can slide and pick, and
/// what's on the picked day underneath.
struct NotchCalendar: View {
    @Environment(AgendaModel.self) private var agenda
    @State private var selected = Calendar.current.startOfDay(for: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(selected.formatted(.dateTime.month(.abbreviated).locale(.cleen)).replacing(".", with: "").capitalized)
                    .font(.system(size: 16, weight: .semibold))
                    .contentTransition(.numericText())
                    .onTapGesture(perform: AgendaModel.openCalendar)
                    .help("Abrir o Calendário")
                CalendarDayStrip(selected: $selected)
            }
            CalendarDayAgenda(day: selected)
        }
        .animation(.smooth(duration: 0.25), value: selected)
    }
}
