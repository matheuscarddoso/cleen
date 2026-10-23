import Foundation

/// How Tempo writes its numbers and days.
public enum WeatherFormat {
    /// `24°`, `-3°`. Rounded to whole degrees, and never `-0°`.
    public static func temperature(_ celsius: Double) -> String {
        let rounded = Int(celsius.rounded())
        return "\(rounded == 0 ? 0 : rounded)°"
    }

    /// "Hoje" for today, otherwise the weekday's short name in the Mac's language ("Seg",
    /// "Mon"). Both dates in the API's `yyyy-MM-dd`.
    public static func dayLabel(_ date: String, today: String, locale: Locale = .cleen) -> String {
        if date == today { return String(localized: "Hoje") }
        guard let index = weekdayIndex(date) else { return "—" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        // "seg." → "Seg": the abbreviation's dot and lowercase start read as clutter on a column label.
        let symbol = calendar.shortStandaloneWeekdaySymbols[index].replacing(".", with: "")
        return symbol.prefix(1).uppercased(with: locale) + symbol.dropFirst()
    }

    /// "Hoje", "Amanhã", "Sábado": for tooltips and VoiceOver, where there's room. The
    /// weekdays are localized words rather than the calendar's names, which in Portuguese
    /// carry a "-feira" that's too long here.
    public static func longDayLabel(_ date: String, today: String) -> String {
        if date == today { return String(localized: "Hoje") }
        if let day = dayNumber(date), let now = dayNumber(today), day == now + 1 { return String(localized: "Amanhã") }
        switch weekdayIndex(date) {
        case 0: return String(localized: "Domingo")
        case 1: return String(localized: "Segunda", comment: "Monday")
        case 2: return String(localized: "Terça", comment: "Tuesday")
        case 3: return String(localized: "Quarta", comment: "Wednesday")
        case 4: return String(localized: "Quinta", comment: "Thursday")
        case 5: return String(localized: "Sexta", comment: "Friday")
        case 6: return String(localized: "Sábado")
        default: return date
        }
    }

    /// 0 = Sunday. Worked out on a fixed Gregorian calendar in UTC, so the system's
    /// calendar and time zone can't shift a date onto the wrong weekday.
    static func weekdayIndex(_ date: String) -> Int? {
        dayNumber(date).map { (($0 + 4) % 7 + 7) % 7 } // 1970-01-01 was a Thursday.
    }

    /// Days since 1970-01-01.
    static func dayNumber(_ date: String) -> Int? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard (1...12).contains(parts[1]), (1...31).contains(parts[2]),
              let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return nil }
        return Int((day.timeIntervalSince1970 / 86_400).rounded(.down))
    }
}
