import CleenKit
import SwiftUI

/// One open reminder in the Lembretes tab: check, title, when it's due, its star, and on
/// hover a way into Reminders itself.
struct ReminderListRow: View {
    @Environment(AgendaModel.self) private var agenda
    let reminder: AgendaReminder
    @State private var completion = ReminderCompletion()
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            ReminderCheckbox(isDone: completion.isDone, title: reminder.title) {
                completion.toggle(reminder, in: agenda)
            }
            Text(reminder.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(completion.isDone ? NotchStyle.tertiary : NotchStyle.primary)
                .strikethrough(completion.isDone, color: NotchStyle.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .animation(.smooth(duration: 0.2), value: completion.isDone)
            Spacer(minLength: 8)
            if let due = reminder.due {
                Text(ReminderDue.text(for: due, hasTime: reminder.hasTime))
                    .font(NotchStyle.caption.monospacedDigit())
                    .foregroundStyle(ReminderDue.isPast(due, hasTime: reminder.hasTime) ? NotchStyle.critical : NotchStyle.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if isHovered {
                NotchIconButton(symbol: "arrow.up.forward.app", help: "Abrir no Lembretes", action: AgendaModel.openReminders)
                    .transition(.opacity)
            }
            ReminderStarButton(isStarred: reminder.isStarred) {
                withAnimation(.smooth(duration: 0.3)) { agenda.setStarred(reminder, !reminder.isStarred) }
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 2)
        .frame(height: 30)
        .background(isHovered ? NotchStyle.control.opacity(0.6) : .clear, in: .rect(cornerRadius: 9, style: .continuous))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .onDisappear { completion.finish(reminder, in: agenda) }
        .accessibilityElement(children: .contain)
    }
}

/// The star toggle: an outline that's barely there until it's on.
struct ReminderStarButton: View {
    let isStarred: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isStarred ? "star.fill" : "star")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isStarred ? ToolPalette.yellow : (isHovered ? NotchStyle.secondary : NotchStyle.tertiary))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 24)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isStarred ? "Tirar a estrela" : "Marcar com estrela")
        .accessibilityLabel("Estrela")
        .accessibilityValue(isStarred ? "marcado" : "desmarcado")
        .accessibilityAddTraits(.isToggle)
    }
}
