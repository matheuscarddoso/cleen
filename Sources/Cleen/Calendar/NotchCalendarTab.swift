import SwiftUI

/// The month at a glance, as in OmniNotch: a grid with event dots on the left, the
/// picked day's events on the right.
struct NotchCalendarTab: View {
    @Environment(AgendaModel.self) private var agenda
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selected = Calendar.current.startOfDay(for: .now)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MonthGrid(month: $month, selected: $selected)
                .frame(width: 330)
            Rectangle()
                .fill(NotchStyle.track)
                .frame(width: 1)
            DayEventList(day: selected)
        }
        .padding(.bottom, 2)
        .task { await agenda.watch() }
        .onChange(of: month) { _, newMonth in agenda.loadMonth(containing: newMonth) }
    }
}
