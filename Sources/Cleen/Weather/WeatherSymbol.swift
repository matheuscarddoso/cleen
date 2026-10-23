import CleenKit
import SwiftUI

/// The sky for a WMO code, in the symbol's own colors (yellow sun, blue drops): the one
/// place the notch uses color for something other than a warning, because that's how
/// weather is read.
struct WeatherSymbol: View {
    let code: Int
    var isDay = true
    let size: Double

    var body: some View {
        Image(systemName: WeatherCode(code).symbol(isDay: isDay))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .frame(width: size * 1.3, height: size * 1.1)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

extension Forecast {
    /// "Atualizado às 14:20", or with the day when it isn't today's. Shown only when the
    /// forecast may be behind, so it's quiet the rest of the time.
    var updatedNote: String {
        let time = fetchedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.cleen))
        if Calendar.current.isDateInToday(fetchedAt) { return "Atualizado às \(time)" }
        let day = fetchedAt.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.cleen))
        return "Atualizado em \(day) às \(time)"
    }
}
