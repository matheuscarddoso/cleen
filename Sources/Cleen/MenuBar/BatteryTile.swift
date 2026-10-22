import CleenKit
import SwiftUI

struct BatteryTile: View {
    let battery: BatteryStats

    var body: some View {
        MetricTile(
            title: "Bateria",
            value: battery.level.percent,
            detail: state,
            detailColor: battery.isCharging ? Theme.good : nil,
            footnote: health
        )
    }

    private var state: String {
        if battery.isCharging { return "Carregando" }
        if battery.isPluggedIn { return "Na tomada" }
        if let minutes = battery.minutesRemaining {
            return Duration.seconds(minutes * 60)
                .formatted(.units(allowed: [.hours, .minutes], width: .narrow).locale(.cleen)) + " restantes"
        }
        return "Na bateria"
    }

    private var health: String? {
        var parts: [String] = []
        if let health = battery.health { parts.append("Saúde \(health.percent)") }
        if let cycles = battery.cycleCount { parts.append("\(cycles) ciclos") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
