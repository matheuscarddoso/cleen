import CleenKit
import EventKit

/// An open reminder, copied out of EventKit.
nonisolated struct AgendaReminder: Identifiable, Equatable, Sendable, ReminderSortable {
    let id: String
    let title: String
    let due: Date?
    /// Due at a time of day, not just on a day.
    let hasTime: Bool
    /// Cleen's star is Reminders' high priority (the "!!!" flag).
    var isStarred: Bool

    init(_ reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? String(localized: "Sem título")
        due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        hasTime = reminder.dueDateComponents?.hour != nil
        isStarred = (1...4).contains(reminder.priority)
    }

    var isOverdue: Bool {
        guard let due else { return false }
        return due < Calendar.current.startOfDay(for: .now)
    }
}
