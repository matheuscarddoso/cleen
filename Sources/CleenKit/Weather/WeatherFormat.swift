import Foundation

/// How Tempo writes its numbers and days.
public enum WeatherFormat {
    /// `24°`, `-3°`. Rounded to whole degrees, and never `-0°`.
    public static func temperature(_ celsius: Double) -> String {
        let rounded = Int(celsius.rounded())
        return "\(rounded == 0 ? 0 : rounded)°"
    }

    private static let shortWeekdays = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    private static let weekdays = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]

    /// "Hoje" for today, otherwise "Seg", "Ter"… Both dates in the API's `yyyy-MM-dd`.
    public static func dayLabel(_ date: String, today: String) -> String {
        if date == today { return "Hoje" }
        return weekdayIndex(date).map { shortWeekdays[$0] } ?? "—"
    }

    /// "Hoje", "Amanhã", "Sábado": for tooltips and VoiceOver, where there's room.
    public static func longDayLabel(_ date: String, today: String) -> String {
        if date == today { return "Hoje" }
        if let day = dayNumber(date), let now = dayNumber(today), day == now + 1 { return "Amanhã" }
        return weekdayIndex(date).map { weekdays[$0] } ?? date
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
