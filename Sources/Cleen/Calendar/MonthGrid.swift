import SwiftUI

struct MonthGrid: View {
    @Binding var month: Date
    @Binding var selected: Date
    @Environment(AgendaModel.self) private var agenda

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                MonthArrow(symbol: "chevron.left", label: "Mês anterior") { shift(-1) }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NotchStyle.secondary)
                    .contentTransition(.numericText())
                    .onTapGesture(perform: goToToday)
                    .help("Voltar para hoje")
                Spacer()
                MonthArrow(symbol: "chevron.right", label: "Próximo mês") { shift(1) }
            }
            .frame(height: 20)
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(NotchStyle.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(weeks, id: \.self) { week in
                    GridRow {
                        ForEach(week, id: \.self) { day in
                            MonthDayCell(
                                day: day,
                                isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                                isSelected: day == selected,
                                hasEvents: agenda.hasEvents(on: day)
                            ) { selected = day }
                        }
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.2), value: month)
    }

    /// "Outubro de 2026": only the month capitalized, as Portuguese writes it.
    private var monthTitle: String {
        let text = month.formatted(.dateTime.month(.wide).year().locale(.cleen))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Six weeks starting on the week that holds the 1st, so the grid never jumps.
    private var weeks: [[Date]] {
        let first = calendar.dateInterval(of: .weekOfMonth, for: month)?.start ?? month
        let days = (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        return stride(from: 0, to: 42, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    /// "D S T Q Q S S", in the calendar's first-weekday order.
    private var weekdaySymbols: [String] {
        var localized = Calendar(identifier: .gregorian)
        localized.locale = .cleen
        let symbols = localized.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift]).map { $0.uppercased() }
    }

    private func shift(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) { month = next }
    }

    private func goToToday() {
        month = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        selected = calendar.startOfDay(for: .now)
    }
}
