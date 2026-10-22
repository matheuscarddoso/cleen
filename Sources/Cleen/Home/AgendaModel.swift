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

    private(set) var events: [AgendaEvent] = []
    private(set) var reminders: [AgendaReminder] = []
    private(set) var calendarAccess = Access.unknown
    private(set) var remindersAccess = Access.unknown

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// Asks once for access, then keeps the lists current while the caller is alive.
    func watch() async {
        await requestAccess()
        await reload()
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.reload() }
            }
        }
        // The day rolls over and "in 10 minutes" goes stale; refresh now and then.
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await reload()
        }
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
        calendarAccess = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: (try? await store.requestFullAccessToEvents()) == true ? .granted : .denied
        default: .denied
        }
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
            let predicate = store.predicateForEvents(withStart: calendar.startOfDay(for: now), end: endOfDay, calendars: nil)
            events = store.events(matching: predicate)
                .filter { $0.isAllDay || $0.endDate > now }
                .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
                .map(AgendaEvent.init)
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
