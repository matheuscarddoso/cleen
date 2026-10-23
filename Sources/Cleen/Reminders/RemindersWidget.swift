import CleenKit
import SwiftUI

/// Open reminders on Início, starred first, each with a check that works right there.
/// A tap anywhere else opens Lembretes.
struct RemindersWidget: View {
    let size: HomeWidgetSize
    @Environment(AgendaModel.self) private var agenda
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                HomeWidgetLabel(title: "Lembretes", symbol: "checklist")
                Spacer(minLength: 0)
                if agenda.reminders.count > shown.count {
                    Text(agenda.reminders.count.counted)
                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(NotchStyle.tertiary)
                        .contentTransition(.numericText())
                        .accessibilityLabel(agenda.reminders.count.counted("lembrete em aberto", "lembretes em aberto"))
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 88, alignment: .topLeading)
        .contentShape(.rect)
        // The checks are buttons and take their own clicks; everything else opens the tab.
        .onTapGesture { state.tab = .reminders }
        .accessibilityAction(named: "Abrir Lembretes") { state.tab = .reminders }
        .help("Abrir Lembretes")
        .animation(.smooth(duration: 0.28), value: shown.map(\.id))
        .task { await agenda.watch() }
    }

    @ViewBuilder
    private var content: some View {
        if agenda.remindersAccess == .denied {
            AgendaAccessLink(text: "Permitir acesso aos Lembretes", action: AgendaModel.openRemindersPrivacySettings)
        } else if shown.isEmpty {
            if agenda.remindersAccess == .granted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                    Text("Nada em aberto")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(NotchStyle.tertiary)
                .transition(.opacity)
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(shown) { reminder in
                    WidgetReminderRow(reminder: reminder)
                        .transition(.opacity)
                }
            }
        }
    }

    private var shown: [AgendaReminder] {
        Array(agenda.reminders.prefix(size == .large ? 4 : 3))
    }
}

/// A compact reminder line for the widget: check, title, and when it's due.
private struct WidgetReminderRow: View {
    @Environment(AgendaModel.self) private var agenda
    let reminder: AgendaReminder
    @State private var completion = ReminderCompletion()

    var body: some View {
        HStack(spacing: 5) {
            ReminderCheckbox(isDone: completion.isDone, title: reminder.title, diameter: 12, hitPadding: 2.25) {
                completion.toggle(reminder, in: agenda)
            }
            if reminder.isStarred {
                Image(systemName: "star.fill")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(ToolPalette.yellow)
                    .accessibilityLabel("Com estrela")
            }
            Text(reminder.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(completion.isDone ? NotchStyle.tertiary : NotchStyle.primary)
                .strikethrough(completion.isDone, color: NotchStyle.tertiary)
                .lineLimit(1)
                .layoutPriority(1)
                .animation(.smooth(duration: 0.2), value: completion.isDone)
            Spacer(minLength: 4)
            if let due = reminder.due {
                // The title comes first in a row this narrow: only today's reminders keep
                // their time, the rest just say the day.
                Text(ReminderDue.text(for: due, hasTime: reminder.hasTime && Calendar.current.isDateInToday(due)))
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(ReminderDue.isPast(due, hasTime: reminder.hasTime) ? NotchStyle.critical : NotchStyle.secondary)
                    .lineLimit(1)
            }
        }
        .frame(height: 16.5)
        .onDisappear { completion.finish(reminder, in: agenda) }
    }
}
