import SwiftUI

/// One day in the month grid: today in a red disc, the picked day ringed, a dot when
/// something is on.
struct MonthDayCell: View {
    let day: Date
    let isInMonth: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let select: () -> Void
    @State private var isHovered = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 1) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 12, weight: isToday ? .semibold : .medium).monospacedDigit())
                    .foregroundStyle(isToday ? .white : (isInMonth ? NotchStyle.primary : NotchStyle.tertiary))
                    .frame(width: 22, height: 22)
                    .background {
                        if isToday {
                            Circle().fill(Color(red: 0.93, green: 0.3, blue: 0.29))
                        } else if isSelected {
                            Circle().strokeBorder(NotchStyle.primary.opacity(0.5), lineWidth: 1)
                        } else if isHovered {
                            Circle().fill(NotchStyle.control)
                        }
                    }
                Circle()
                    .fill(Color(red: 0.93, green: 0.3, blue: 0.29))
                    .frame(width: 3, height: 3)
                    .opacity(hasEvents && !isToday ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.cleen)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
