import Foundation
import CleenKit
import UserNotifications

/// Notifies when free space drops under the threshold set in Ajustes, at most twice a day.
final class LowDiskAlert {
    static let enabledKey = "lowDiskAlertEnabled"
    static let thresholdKey = "lowDiskThresholdGB"
    private static let lastAlertKey = "lowDiskLastAlert"

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [Self.enabledKey: true, Self.thresholdKey: 10])
    }

    func evaluate(_ disk: DiskStats) {
        guard defaults.bool(forKey: Self.enabledKey) else { return }
        let threshold = Int64(defaults.integer(forKey: Self.thresholdKey)) * 1_000_000_000
        guard disk.available < threshold else { return }

        let last = defaults.object(forKey: Self.lastAlertKey) as? Date ?? .distantPast
        guard Date.now.timeIntervalSince(last) > 12 * 3600 else { return }
        defaults.set(Date.now, forKey: Self.lastAlertKey)

        let available = disk.available
        Task { await Self.post(available: available) }
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    private static func post(available: Int64) async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Pouco espaço no disco")
        content.body = String(localized: "Restam \(available.bytes). Abra o Cleen para ver o que dá para limpar.")
        let request = UNNotificationRequest(identifier: "low-disk", content: content, trigger: nil)
        try? await center.add(request)
    }
}
