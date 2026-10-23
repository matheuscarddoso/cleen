import SwiftUI

/// The small agenda: today's date the way Calendar's own widget shows it, and what's
/// next. A tap opens the Calendário tab.
struct AgendaGlance: View {
    @Environment(AgendaModel.self) private var agenda
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .calendar } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).locale(.cleen)).replacing(".", with: "").uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(NotchStyle.critical)
                Text(Date.now.formatted(.dateTime.day()))
                    .font(.system(size: 30, weight: .medium).monospacedDigit())
                    .padding(.top, -3)
                Spacer(minLength: 2)
                if let next {
                    Text(next.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                    Text(next.isAllDay ? String(localized: "Dia todo") : next.start.formatted(.dateTime.hour().minute().locale(.cleen)))
                        .font(.system(size: 9.5))
                        .foregroundStyle(NotchStyle.secondary)
                } else {
                    Text("Nada hoje")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(width: 88, height: 88, alignment: .topLeading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Abrir o Calendário")
    }

    /// The next event still to come today (or the one under way).
    private var next: AgendaEvent? {
        agenda.events(on: Calendar.current.startOfDay(for: .now)).first { $0.isAllDay || $0.end > .now }
    }
}
