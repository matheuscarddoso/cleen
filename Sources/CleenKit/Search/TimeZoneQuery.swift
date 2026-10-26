import Foundation

/// A time somewhere else, typed into the search:
/// - `15h em tóquio`, `3pm in london`: your 15h, over there;
/// - `15h de tóquio`: Tokyo's 15h, here;
/// - `agora em nova york`, `hora em lisboa`, `tóquio`… only with "agora"/"hora".
public struct TimeZoneQuery: Equatable, Sendable {
    public let place: String
    public let zone: TimeZone
    /// The moment asked about.
    public let date: Date
    /// True for `de`/`from`: the time was given in the other place.
    public let isFromThere: Bool

    public static func parse(_ text: String, now: Date = .now, here: TimeZone = .current) -> TimeZoneQuery? {
        let folded = FuzzyMatch.fold(text).trimmingCharacters(in: .whitespaces)
        let connectors = [" em ", " in ", " de ", " from ", " no ", " na "]
        guard let connector = connectors.compactMap({ c in folded.range(of: c).map { (c, $0) } }).min(by: { $0.1.lowerBound < $1.1.lowerBound }) else { return nil }
        let timeText = String(folded[..<connector.1.lowerBound]).trimmingCharacters(in: .whitespaces)
        let placeText = String(folded[connector.1.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let (place, zone) = Self.zone(named: placeText) else { return nil }
        let fromThere = connector.0 == " de " || connector.0 == " from "

        if ["agora", "now", "hora", "horas", "que horas sao", "time"].contains(timeText) {
            return TimeZoneQuery(place: place, zone: zone, date: now, isFromThere: false)
        }
        guard let (hour, minute) = clock(timeText) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = fromThere ? zone : here
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = hour
        parts.minute = minute
        guard let date = calendar.date(from: parts) else { return nil }
        return TimeZoneQuery(place: place, zone: zone, date: date, isFromThere: fromThere)
    }

    /// "15h", "15h30", "15:30", "3pm", "3:30 pm", "9am", "15".
    static func clock(_ text: String) -> (Int, Int)? {
        var text = text.replacingOccurrences(of: " ", with: "")
        var offset = 0
        if text.hasSuffix("pm") || text.hasSuffix("am") {
            offset = text.hasSuffix("pm") ? 12 : 0
            text.removeLast(2)
            guard let (hour, minute) = clock(text), (1...12).contains(hour) else { return nil }
            return (hour % 12 + offset, minute)
        }
        let parts = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "h" || $0 == ":" }).map(String.init)
        guard (1...2).contains(parts.count), let hour = Int(parts[0]), (0...23).contains(hour) else { return nil }
        // "15h" alone, or a bare "15" only when followed by nothing else.
        if parts.count == 1 && text.contains(where: { !$0.isNumber }) { return nil }
        let minute = parts.count == 2 ? (parts[1].isEmpty ? 0 : Int(parts[1])) : 0
        guard let minute, (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// A city, country or abbreviation to its zone, with the name to show.
    public static func zone(named raw: String) -> (String, TimeZone)? {
        let name = FuzzyMatch.fold(raw).trimmingCharacters(in: .whitespaces)
        guard name.count >= 2 else { return nil }
        if let (title, identifier) = places[name], let zone = TimeZone(identifier: identifier) { return (title, zone) }
        if name.count <= 5, let zone = TimeZone(abbreviation: name.uppercased()) { return (name.uppercased(), zone) }
        // Any city in the system's list: "denver", "new york", "kolkata".
        for identifier in TimeZone.knownTimeZoneIdentifiers {
            guard let city = identifier.split(separator: "/").last else { continue }
            let readable = city.replacingOccurrences(of: "_", with: " ")
            if FuzzyMatch.fold(readable) == name, let zone = TimeZone(identifier: identifier) { return (readable, zone) }
        }
        return nil
    }

    /// Names as people type them in Portuguese, plus the usual nicknames.
    static let places: [String: (String, String)] = {
        var table: [String: (String, String)] = [:]
        func add(_ title: String, _ identifier: String, _ names: [String]) {
            for name in names { table[FuzzyMatch.fold(name)] = (title, identifier) }
        }
        add("Tóquio", "Asia/Tokyo", ["tóquio", "toquio", "tokyo", "japão", "japao", "japan"])
        add("Nova York", "America/New_York", ["nova york", "nova iorque", "new york", "ny", "nyc", "boston", "miami", "washington"])
        add("Los Angeles", "America/Los_Angeles", ["los angeles", "la", "são francisco", "san francisco", "sf", "califórnia", "california", "seattle", "vale do silício"])
        add("Chicago", "America/Chicago", ["chicago", "texas", "austin", "dallas", "houston"])
        add("Denver", "America/Denver", ["denver"])
        add("Toronto", "America/Toronto", ["toronto", "montreal"])
        add("Vancouver", "America/Vancouver", ["vancouver"])
        add("Cidade do México", "America/Mexico_City", ["cidade do méxico", "mexico city", "méxico", "mexico"])
        add("São Paulo", "America/Sao_Paulo", ["são paulo", "sp", "rio", "rio de janeiro", "brasília", "brasilia", "brasil", "brazil", "belo horizonte", "curitiba", "porto alegre", "salvador", "recife", "fortaleza"])
        add("Manaus", "America/Manaus", ["manaus"])
        add("Buenos Aires", "America/Argentina/Buenos_Aires", ["buenos aires", "argentina"])
        add("Santiago", "America/Santiago", ["santiago", "chile"])
        add("Bogotá", "America/Bogota", ["bogotá", "bogota", "colômbia", "colombia"])
        add("Lima", "America/Lima", ["lima", "peru"])
        add("Lisboa", "Europe/Lisbon", ["lisboa", "lisbon", "portugal", "porto"])
        add("Londres", "Europe/London", ["londres", "london", "inglaterra", "reino unido", "uk"])
        add("Dublin", "Europe/Dublin", ["dublin", "irlanda"])
        add("Paris", "Europe/Paris", ["paris", "frança", "franca"])
        add("Madri", "Europe/Madrid", ["madri", "madrid", "barcelona", "espanha"])
        add("Berlim", "Europe/Berlin", ["berlim", "berlin", "alemanha", "munique", "frankfurt"])
        add("Amsterdã", "Europe/Amsterdam", ["amsterdã", "amsterda", "amsterdam", "holanda"])
        add("Roma", "Europe/Rome", ["roma", "rome", "itália", "italia", "milão", "milao"])
        add("Zurique", "Europe/Zurich", ["zurique", "zurich", "suíça", "suica", "genebra"])
        add("Estocolmo", "Europe/Stockholm", ["estocolmo", "stockholm", "suécia"])
        add("Atenas", "Europe/Athens", ["atenas", "athens", "grécia", "grecia"])
        add("Istambul", "Europe/Istanbul", ["istambul", "istanbul", "turquia"])
        add("Moscou", "Europe/Moscow", ["moscou", "moscow", "rússia", "russia"])
        add("Cairo", "Africa/Cairo", ["cairo", "egito"])
        add("Joanesburgo", "Africa/Johannesburg", ["joanesburgo", "johannesburg", "cidade do cabo", "áfrica do sul"])
        add("Lagos", "Africa/Lagos", ["lagos", "nigéria"])
        add("Luanda", "Africa/Luanda", ["luanda", "angola"])
        add("Dubai", "Asia/Dubai", ["dubai", "emirados", "abu dhabi"])
        add("Nova Délhi", "Asia/Kolkata", ["nova délhi", "nova delhi", "new delhi", "índia", "india", "mumbai", "bangalore"])
        add("Singapura", "Asia/Singapore", ["singapura", "singapore"])
        add("Hong Kong", "Asia/Hong_Kong", ["hong kong"])
        add("Xangai", "Asia/Shanghai", ["xangai", "shanghai", "pequim", "beijing", "china", "shenzhen"])
        add("Seul", "Asia/Seoul", ["seul", "seoul", "coreia", "coréia"])
        add("Bangkok", "Asia/Bangkok", ["bangkok", "tailândia"])
        add("Sydney", "Australia/Sydney", ["sydney", "sidney", "melbourne", "austrália", "australia"])
        add("Auckland", "Pacific/Auckland", ["auckland", "nova zelândia", "nova zelandia"])
        add("UTC", "UTC", ["utc", "gmt", "zulu"])
        return table
    }()
}

/// Date arithmetic typed into the search: `hoje + 45 dias`, `daqui a 3 semanas`,
/// `10 dias atrás`, `amanhã`, `25/12`, `dias até 25/12`.
public struct DateQuery: Equatable, Sendable {
    public enum Answer: Equatable, Sendable {
        /// A day: what weekday it falls on, and how far from today.
        case date(Date)
        /// Days from today to a date (negative when it's past).
        case days(Int, until: Date)
    }

    public let answer: Answer

    public static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> DateQuery? {
        var words = FuzzyMatch.fold(text).replacingOccurrences(of: "+", with: " + ").replacingOccurrences(of: " - ", with: " − ")
            .split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        let today = calendar.startOfDay(for: now)

        // "dias até 25/12", "quantos dias até o natal" is beyond us; "até 25/12".
        if let index = words.firstIndex(where: { $0 == "ate" || $0 == "until" }), index + 1 < words.count {
            let before = words[..<index]
            guard before.allSatisfy({ ["dias", "days", "quantos", "faltam", "how", "many"].contains($0) }) else { return nil }
            guard let target = day(String(words[(index + 1)...].joined(separator: " ")), today: today, calendar: calendar) else { return nil }
            let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
            return DateQuery(answer: .days(days, until: target))
        }

        // "daqui a 3 semanas", "em 10 dias", "in 2 weeks".
        if words.count == 4, words[0] == "daqui", words[1] == "a" || words[1] == "ha" {
            words = ["hoje", "+", words[2], words[3]]
        } else if words.count == 3, words[0] == "em" || words[0] == "in" {
            words = ["hoje", "+", words[1], words[2]]
        } else if words.count == 3, words[2] == "atras" || words[2] == "ago" {
            words = ["hoje", "−", words[0], words[1]]
        } else if words.count == 3, words[0] == "ha" {
            words = ["hoje", "−", words[1], words[2]]
        }

        guard let base = day(words[0], today: today, calendar: calendar) else { return nil }
        if words.count == 1 {
            // A lone "25/12" or "amanhã": which weekday. A plain number isn't a date.
            return DateQuery(answer: .date(base))
        }
        guard words.count == 4, words[1] == "+" || words[1] == "−" || words[1] == "-", let amount = Int(words[2]), let component = component(words[3]) else { return nil }
        let sign = words[1] == "+" ? 1 : -1
        guard let result = calendar.date(byAdding: component, value: sign * amount, to: base) else { return nil }
        return DateQuery(answer: .date(result))
    }

    /// "hoje", "amanhã", "ontem", "25/12", "25/12/2027", "2027-01-31".
    static func day(_ word: String, today: Date, calendar: Calendar) -> Date? {
        switch word {
        case "hoje", "today": return today
        case "amanha", "tomorrow": return calendar.date(byAdding: .day, value: 1, to: today)
        case "ontem", "yesterday": return calendar.date(byAdding: .day, value: -1, to: today)
        default: break
        }
        if word.contains("-") {
            let parts = word.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3, parts[0] > 999 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])).flatMap { valid($0, parts[2], calendar) }
        }
        let parts = word.split(separator: "/", omittingEmptySubsequences: false).map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
        let dayNumber = parts[0]!, month = parts[1]!
        guard (1...31).contains(dayNumber), (1...12).contains(month) else { return nil }
        var year = parts.count == 3 ? parts[2]! : calendar.component(.year, from: today)
        if year < 100 { year += 2000 }
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) else { return nil }
        return valid(date, dayNumber, calendar)
    }

    /// 31/02 must not quietly become 3 March.
    private static func valid(_ date: Date, _ dayNumber: Int, _ calendar: Calendar) -> Date? {
        calendar.component(.day, from: date) == dayNumber ? date : nil
    }

    static func component(_ word: String) -> Calendar.Component? {
        switch word {
        case "dia", "dias", "d", "day", "days": .day
        case "semana", "semanas", "sem", "week", "weeks": .weekOfYear
        case "mes", "meses", "month", "months": .month
        case "ano", "anos", "year", "years": .year
        default: nil
        }
    }
}
