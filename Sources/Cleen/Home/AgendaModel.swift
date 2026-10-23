import AppKit
import EventKit
import Observation

/// Today's events and open reminders, straight from Calendar and Reminders.
@Observable
final class AgendaModel {
    enum Access: Equatable {
        case unknown
        case granted
        case denied
    }

    /// Events per day (keyed by start of day) for a window around today.
    private(set) var eventsByDay: [Date: [AgendaEvent]] = [:]
    private(set) var reminders: [AgendaReminder] = []
    private(set) var calendarAccess = Access.unknown
    private(set) var remindersAccess = Access.unknown

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?

    @ObservationIgnored private var refresher: Task<Void, Never>?

    /// Asks once for access, then keeps the lists current. Several views (and several
    /// screens' notches) call this; they all share one refresh loop.
    func watch() async {
        guard refresher == nil else { return }
        // Claim it before the first await, so a second caller can't slip in.
        refresher = Task { [weak self] in
            // Listen before the first read: right after launch the store is still
            // loading, the first read can come back empty, and the "changed" signal
            // that follows must not be missed.
            guard let self else { return }
            self.observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: self.store, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.reload() }
            }
            await self.requestAccess()
            await self.reload()
            // A second look once the store has settled, then every minute (the day
            // rolls over, "in 10 minutes" goes stale).
            try? await Task.sleep(for: .seconds(2))
            await self.reload()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await self.reload()
            }
        }
    }

    @ObservationIgnored private var loadedMonths = Set<Date>()

    /// Makes sure every day of the month grid around `date` has its events.
    func loadMonth(containing date: Date) {
        guard calendarAccess == .granted else { return }
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: date) else { return }
        loadedMonths.insert(month.start)
        // The grid shows a few days of the neighbouring months too.
        let start = calendar.date(byAdding: .day, value: -7, to: month.start) ?? month.start
        let end = calendar.date(byAdding: .day, value: 14, to: month.end) ?? month.end
        loadEvents(from: start, to: end)
    }

    private func loadEvents(from start: Date, to end: Date) {
        let calendar = Calendar.current
        let found = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .map(AgendaEvent.init)
        var byDay: [Date: [AgendaEvent]] = [:]
        for event in found {
            // Multi-day events show on every day they cover.
            var day = max(calendar.startOfDay(for: event.start), calendar.startOfDay(for: start))
            let last = min(calendar.startOfDay(for: event.end.addingTimeInterval(-1)), end)
            while day <= last {
                byDay[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        for (day, events) in byDay {
            eventsByDay[day] = events.sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
        }
    }

    /// What's on a day; for today, only what hasn't ended yet.
    func events(on day: Date) -> [AgendaEvent] {
        let events = eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
        guard Calendar.current.isDateInToday(day) else { return events }
        return events.filter { $0.isAllDay || $0.end > .now }
    }

    func hasEvents(on day: Date) -> Bool {
        !(eventsByDay[Calendar.current.startOfDay(for: day)] ?? []).isEmpty
    }

    func complete(_ reminder: AgendaReminder) {
        guard let item = store.calendarItem(withIdentifier: reminder.id) as? EKReminder else { return }
        item.isCompleted = true
        try? store.save(item, commit: true)
        reminders.removeAll { $0.id == reminder.id }
    }

    static func openCalendar() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    static func openReminders() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Loading

    private func requestAccess() async {
        await requestCalendarAccess()
        await requestRemindersAccess()
    }

    /// Shows the system prompt the first time; afterwards only Ajustes can change it.
    func requestCalendarAccess() async {
        calendarAccess = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: (try? await store.requestFullAccessToEvents()) == true ? .granted : .denied
        default: .denied
        }
    }

    func requestRemindersAccess() async {
        remindersAccess = switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .granted
        case .notDetermined: (try? await store.requestFullAccessToReminders()) == true ? .granted : .denied
        default: .denied
        }
    }

    private func reload() async {
        let calendar = Calendar.current
        let now = Date.now
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        if calendarAccess == .granted {
            // A window around today for the day strip, plus any month browsed since.
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -14, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 32, to: today) ?? endOfDay
            eventsByDay = [:]
            loadEvents(from: start, to: end)
            for month in loadedMonths { loadMonth(containing: month) }
        }

        if remindersAccess == .granted {
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            let fetched = await withCheckedContinuation { (continuation: CheckedContinuation<[AgendaReminder], Never>) in
                // EventKit calls back on its own queue; this closure must not assume the
                // main actor (the app target's default) or the runtime traps.
                store.fetchReminders(matching: predicate) { @Sendable reminders in
                    let mapped = (reminders ?? []).map(AgendaReminder.init)
                    continuation.resume(returning: mapped)
                }
            }
            // Due soonest first; undated ones after, as Reminders' own Today view does.
            reminders = fetched.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
        }
    }
}
