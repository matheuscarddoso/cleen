import CleenKit
import SwiftUI

/// Redraws its content once a second while the timer runs, on the very instants the
/// digits change, and not at all while it's paused or idle.
struct TimerTicks<Content: View>: View {
    @Environment(TimerModel.self) private var model
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(CountdownSchedule(endDate: model.endDate)) { context in
            content(context.date)
        }
    }
}

/// Entries on whole seconds before `endDate`, so each one lands exactly where the
/// rounded-up clock text flips. Without an end date, a single entry.
nonisolated struct CountdownSchedule: TimelineSchedule {
    let endDate: Date?

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        guard let endDate else { return Entries(upcoming: startDate, last: startDate) }
        let left = endDate.timeIntervalSince(startDate)
        let first = left > 0 ? endDate.addingTimeInterval(-left.rounded(.up)) : startDate
        return Entries(upcoming: first, last: max(endDate, startDate))
    }

    struct Entries: Sequence, IteratorProtocol {
        var upcoming: Date?
        let last: Date

        mutating func next() -> Date? {
            guard let current = upcoming else { return nil }
            let following = current.addingTimeInterval(1)
            upcoming = following <= last ? following : nil
            return current
        }
    }
}

extension TimerPhase {
    /// Breaks read green so a glance tells rest from work.
    var tint: Color { isBreak ? NotchStyle.good : NotchStyle.barFill }

    var symbol: String {
        switch self {
        case .countdown: "timer"
        case .focus: "brain.head.profile"
        case .shortBreak, .longBreak: "cup.and.saucer"
        }
    }
}
