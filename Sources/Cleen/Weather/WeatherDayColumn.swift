import CleenKit
import SwiftUI

/// One day of the week strip: the day, its sky, the chance of rain when it matters,
/// the high over the low.
struct WeatherDayColumn: View {
    let day: Forecast.Day
    let today: String
    @State private var isHovered = false

    private var isToday: Bool { day.date == today }

    /// Below this a rain chance is noise next to a sunny symbol.
    private static let chanceWorthShowing = 20

    var body: some View {
        VStack(spacing: 4) {
            Text(WeatherFormat.dayLabel(day.date, today: today))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isToday ? NotchStyle.primary : NotchStyle.secondary)
            WeatherSymbol(code: day.code, size: 19)
                .padding(.top, 2)
            // Always takes its line, so the temperatures sit level across the week.
            Text(chance.map { "\($0)%" } ?? " ")
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .foregroundStyle(NotchStyle.secondary)
            VStack(spacing: 1) {
                Text(WeatherFormat.temperature(day.high))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                Text(WeatherFormat.temperature(day.low))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(NotchStyle.secondary)
            }
            .contentTransition(.numericText())
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(background, in: .rect(cornerRadius: 10, style: .continuous))
        .contentShape(.rect)
        .onHover { hovering in withAnimation(.smooth(duration: 0.15)) { isHovered = hovering } }
        .help(summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var chance: Int? {
        day.precipitationChance.flatMap { $0 >= Self.chanceWorthShowing ? $0 : nil }
    }

    private var background: Color {
        if isHovered { return NotchStyle.control.opacity(0.6) }
        return isToday ? NotchStyle.card : .clear
    }

    /// "Amanhã: Chuva fraca, máxima 22°, mínima 16°, 85% de chance de chuva".
    private var summary: String {
        var text = "\(WeatherFormat.longDayLabel(day.date, today: today)): \(day.weather.description), máxima \(WeatherFormat.temperature(day.high)), mínima \(WeatherFormat.temperature(day.low))"
        if let chance = day.precipitationChance, chance > 0 { text += ", \(chance)% de chance de chuva" }
        return text
    }
}
