import AppKit
import CleenKit
import EventKit

/// A calendar event, copied out of EventKit so views hold plain values.
nonisolated struct AgendaEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
    /// The video call in the invite (Meet, Zoom, Teams…), wherever it was put.
    let meetingURL: URL?

    init(_ event: EKEvent) {
        id = event.eventIdentifier ?? UUID().uuidString
        title = event.title ?? String(localized: "Sem título")
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        color = event.calendar.map { NSColor(cgColor: $0.cgColor) ?? .systemBlue } ?? .systemBlue
        meetingURL = MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])
    }

    var timeText: String {
        if isAllDay { return String(localized: "Dia todo") }
        let style = Date.FormatStyle.dateTime.hour().minute().locale(.cleen)
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}
