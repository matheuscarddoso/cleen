import AppKit
import EventKit

/// A calendar event, copied out of EventKit so views hold plain values.
nonisolated struct AgendaEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor

    init(_ event: EKEvent) {
        id = event.eventIdentifier ?? UUID().uuidString
        title = event.title ?? String(localized: "Sem título")
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        color = event.calendar.map { NSColor(cgColor: $0.cgColor) ?? .systemBlue } ?? .systemBlue
    }

    var timeText: String {
        if isAllDay { return String(localized: "Dia todo") }
        let style = Date.FormatStyle.dateTime.hour().minute().locale(.cleen)
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}
