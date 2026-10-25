import SwiftUI

/// A sliding row of days, today centered and blue, faded at both ends.
struct CalendarDayStrip: View {
    @Binding var selected: Date
    @Environment(AgendaModel.self) private var agenda
    @State private var position: Date?

    private let days: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-14...31).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }()

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    CalendarDayCell(day: day, isSelected: day == selected, hasEvents: agenda.hasEvents(on: day)) {
                        selected = day
                    }
                    .id(day)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $position, anchor: .center)
        .onAppear { position = selected }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.18),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .frame(height: 34)
    }
}
