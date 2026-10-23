import Foundation

/// What a reminder list needs to be put in order.
public protocol ReminderSortable {
    var title: String { get }
    var due: Date? { get }
    var isStarred: Bool { get }
}

extension Sequence where Element: ReminderSortable {
    /// Starred first, then due soonest, undated last; ties by title so the list never
    /// shuffles between refreshes.
    public func sortedForReminders() -> [Element] {
        sorted { lhs, rhs in
            if lhs.isStarred != rhs.isStarred { return lhs.isStarred }
            let left = lhs.due ?? .distantFuture
            let right = rhs.due ?? .distantFuture
            if left != right { return left < right }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

/// How a reminder's due date reads in a row: "14:00", "Amanhã", "23 de out.".
public enum ReminderDue {
    public static func text(for due: Date, hasTime: Bool, now: Date = .now, calendar: Calendar = .current, locale: Locale = .cleen) -> String {
        let time = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
        let day: String
        if calendar.isDate(due, inSameDayAs: now) {
            if hasTime { return due.formatted(time) }
            day = String(localized: "Hoje")
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(due, inSameDayAs: tomorrow) {
            day = String(localized: "Amanhã")
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(due, inSameDayAs: yesterday) {
            day = String(localized: "Ontem")
        } else {
            var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
            if calendar.component(.year, from: due) != calendar.component(.year, from: now) { style = style.year() }
            day = due.formatted(style)
        }
        return hasTime ? "\(day), \(due.formatted(time))" : day
    }

    /// Past due: a timed reminder once its time has gone by, a dated one from the next day.
    public static func isPast(_ due: Date, hasTime: Bool, now: Date = .now, calendar: Calendar = .current) -> Bool {
        hasTime ? due < now : due < calendar.startOfDay(for: now)
    }
}
