import SwiftUI

/// The round check that completes a reminder, as in Reminders: an empty ring that fills
/// white with a tick, with a small pop so the tap reads as done.
struct ReminderCheckbox: View {
    let isDone: Bool
    let title: String
    var diameter = 15.0
    /// Extra room around the ring that still takes the click.
    var hitPadding = 4.0
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(isDone ? .clear : (isHovered ? NotchStyle.secondary : NotchStyle.tertiary), lineWidth: 1.25)
                    .background(isDone ? Color.white : .clear, in: .circle)
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.5, weight: .semibold))
                    .foregroundStyle(isDone ? Color.black : NotchStyle.secondary)
                    .opacity(isDone ? 1 : (isHovered ? 0.7 : 0))
                    .scaleEffect(isDone ? 1 : 0.8)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(isDone ? 1 : (isHovered ? 1.06 : 1))
            .padding(hitPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isDone)
        .animation(.smooth(duration: 0.15), value: isHovered)
        .help(isDone ? "Desfazer" : "Concluir")
        .accessibilityLabel("Concluir \(title)")
        .accessibilityValue(isDone ? "concluído" : "em aberto")
        .accessibilityAddTraits(.isToggle)
    }
}

/// A reminder's check with the beat between tap and removal: the ring fills, the title
/// strikes through, and only then does the row leave. A second tap in that beat undoes it.
@Observable
final class ReminderCompletion {
    private(set) var isDone = false
    @ObservationIgnored private var pending: Task<Void, Never>?

    func toggle(_ reminder: AgendaReminder, in agenda: AgendaModel) {
        if isDone {
            pending?.cancel()
            pending = nil
            isDone = false
            return
        }
        isDone = true
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled, let self else { return }
            self.pending = nil
            withAnimation(.smooth(duration: 0.28)) { agenda.complete(reminder) }
        }
    }

    /// A row that goes away mid-beat still completes what was ticked.
    func finish(_ reminder: AgendaReminder, in agenda: AgendaModel) {
        guard isDone, let pending else { return }
        pending.cancel()
        self.pending = nil
        agenda.complete(reminder)
    }
}
