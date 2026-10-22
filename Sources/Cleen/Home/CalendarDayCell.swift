import SwiftUI

struct CalendarDayCell: View {
    let day: Date
    let isSelected: Bool
    let hasEvents: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 1) {
                Text(weekday)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(isSelected ? NotchStyle.primary.opacity(0.75) : labelColor)
                Text(day.formatted(.dateTime.day(.twoDigits)))
                    .font(.system(size: isSelected ? 19 : 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color(red: 0.2, green: 0.55, blue: 1) : numberColor)
                Circle()
                    .fill(isSelected ? Color(red: 0.2, green: 0.55, blue: 1) : NotchStyle.secondary)
                    .frame(width: 3.5, height: 3.5)
                    .opacity(hasEvents ? 1 : 0)
            }
            .frame(width: isSelected ? 40 : 30, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.cleen)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "S", "T", "Q"… and the short name for the picked day ("QUI").
    private var weekday: String {
        let style: Date.FormatStyle.Symbol.Weekday = isSelected ? .abbreviated : .narrow
        return day.formatted(.dateTime.weekday(style).locale(.cleen)).replacing(".", with: "").uppercased()
    }

    private var isWeekend: Bool { Calendar.current.isDateInWeekend(day) }

    private var labelColor: Color {
        isWeekend ? Color(red: 1, green: 0.45, blue: 0.45).opacity(0.55) : NotchStyle.tertiary
    }

    private var numberColor: Color {
        isWeekend ? Color(red: 1, green: 0.45, blue: 0.45).opacity(0.7) : NotchStyle.secondary
    }
}
