import EventKit

/// An open reminder, copied out of EventKit.
nonisolated struct AgendaReminder: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let due: Date?

    init(_ reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? "Sem título"
        due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
    }

    var isOverdue: Bool {
        guard let due else { return false }
        return due < Calendar.current.startOfDay(for: .now)
    }
}
