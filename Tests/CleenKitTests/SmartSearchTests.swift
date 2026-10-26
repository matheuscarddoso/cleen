import Foundation
import Testing
@testable import CleenKit

struct UnitQueryTests {
    @Test(arguments: [
        ("5 km em mi", "km", "mi"), ("5km to mi", "km", "mi"), ("72 f em c", "f", "c"), ("72°F em °C", "f", "c"),
        ("1,5 gb em mb", "GB", "MB"), ("3 horas em minutos", "h", "min"), ("10 pés em metros", "ft", "m"),
        ("2 xícaras para ml", "cup", "ml"), ("100 kg lb", "kg", "lb"),
    ])
    func units(text: String, from: String, to: String) throws {
        let query = try #require(UnitQuery.parse(text))
        #expect(query.from.id == from && query.to.id == to && !query.isCurrency)
    }

    @Test func convertsTheNumber() throws {
        let miles = try #require(UnitQuery.parse("5 km em mi")?.result(rates: nil))
        #expect(abs(miles - 3.10686) < 0.0001)
        let celsius = try #require(UnitQuery.parse("72 f em c")?.result(rates: nil))
        #expect(abs(celsius - 22.2222) < 0.001)
    }

    @Test func currencies() throws {
        let rates = CurrencyRates(base: "USD", date: "2026-10-23", rates: ["BRL": 5, "EUR": 0.9], fetchedAt: .now)
        let byCode = try #require(UnitQuery.parse("100 usd em brl"))
        #expect(byCode.isCurrency && byCode.result(rates: rates) == 500)
        let bySign = try #require(UnitQuery.parse("R$ 50 para euro"))
        #expect(bySign.from.id == "BRL" && bySign.to.id == "EUR")
        let glued = try #require(UnitQuery.parse("$20 em reais"))
        #expect(glued.from.id == "USD" && glued.to.id == "BRL" && glued.value == 20)
    }

    @Test func aCurrencyAloneGoesToTheLocalOne() throws {
        #expect(UnitQuery.parse("100 usd", localCurrency: "BRL")?.to.id == "BRL")
        #expect(UnitQuery.parse("100 reais", localCurrency: "BRL")?.to.id == "USD")
    }

    @Test(arguments: ["5 km", "5 km em kg", "km em mi", "100 usd em km", "olá mundo", "2+2", "5 abc em mi"])
    func notAConversion(text: String) {
        #expect(UnitQuery.parse(text) == nil)
    }
}

struct TimeZoneQueryTests {
    private let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
    // 2026-10-26 12:00 in São Paulo.
    private let noon = Date(timeIntervalSince1970: 1_793_026_800)

    private func clock(_ date: Date, in zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }

    @Test func myTimeOverThere() throws {
        let query = try #require(TimeZoneQuery.parse("15h em Tóquio", now: noon, here: saoPaulo))
        #expect(query.place == "Tóquio" && !query.isFromThere)
        #expect(clock(query.date, in: saoPaulo) == "15:00")
        #expect(clock(query.date, in: query.zone) == "03:00")
    }

    @Test func theirTimeHere() throws {
        let query = try #require(TimeZoneQuery.parse("9am from london", now: noon, here: saoPaulo))
        #expect(query.isFromThere && clock(query.date, in: query.zone) == "09:00")
        #expect(clock(query.date, in: saoPaulo) == "06:00") // London is back on GMT by 26 October.
    }

    @Test func nowSomewhere() throws {
        let query = try #require(TimeZoneQuery.parse("agora em nova york", now: noon, here: saoPaulo))
        #expect(query.date == noon && query.zone.identifier == "America/New_York")
        #expect(TimeZoneQuery.parse("hora em denver", now: noon)?.zone.identifier == "America/Denver")
    }

    @Test(arguments: ["15h30", "15:30", "3:30pm", "3:30 pm"])
    func clockFormats(text: String) {
        #expect(TimeZoneQuery.clock(FuzzyMatch.fold(text)).map { "\($0.0):\($0.1)" } == "15:30")
    }

    @Test(arguments: ["15h em lugar nenhum", "bolo em tóquio", "5 km em mi", "25h em tóquio"])
    func notATime(text: String) {
        #expect(TimeZoneQuery.parse(text, now: noon) == nil)
    }
}

struct DateQueryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 15))! }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test(arguments: [
        ("hoje + 45 dias", 2026, 12, 10), ("hoje+45 dias", 2026, 12, 10), ("daqui a 3 semanas", 2026, 11, 16),
        ("em 2 meses", 2026, 12, 26), ("10 dias atrás", 2026, 10, 16), ("há 1 ano", 2025, 10, 26),
        ("amanhã", 2026, 10, 27), ("25/12", 2026, 12, 25), ("25/12 + 1 semana", 2027, 1, 1), ("2027-01-31", 2027, 1, 31),
    ])
    func dates(text: String, year: Int, month: Int, dayNumber: Int) {
        #expect(DateQuery.parse(text, now: now, calendar: calendar)?.answer == .date(day(year, month, dayNumber)))
    }

    @Test func daysUntil() {
        #expect(DateQuery.parse("dias até 25/12", now: now, calendar: calendar)?.answer == .days(60, until: day(2026, 12, 25)))
    }

    @Test(arguments: ["31/02", "42", "hoje mais tarde", "5 km em mi", "hoje + muitos dias"])
    func notADate(text: String) {
        #expect(DateQuery.parse(text, now: now, calendar: calendar) == nil)
    }
}

struct QuicklinkTests {
    @Test func keywordAndQuery() throws {
        let match = try #require(Quicklink.match("gh cleen app", in: Quicklink.defaults))
        #expect(match.link.name == "GitHub" && match.query == "cleen app")
        #expect(match.link.url(for: match.query)?.absoluteString == "https://github.com/search?q=cleen%20app")
    }

    @Test func encodesWhatWouldBreakTheAddress() {
        let google = Quicklink(name: "G", keyword: "g", url: "https://www.google.com/search?q={query}")
        #expect(google.url(for: "a&b=c?#")?.absoluteString == "https://www.google.com/search?q=a%26b%3Dc%3F%23")
        #expect(google.url(for: "  ") == nil)
    }

    @Test func onlySafeSchemes() {
        #expect(Quicklink(name: "x", keyword: "x", url: "file:///etc/passwd").url(for: "") == nil)
        #expect(Quicklink(name: "x", keyword: "x", url: "javascript:alert({query})").url(for: "1") == nil)
        #expect(Quicklink(name: "Repo", keyword: "", url: "https://github.com/matheuscarddoso/cleen").url(for: "")?.host() == "github.com")
    }

    @Test(arguments: [("github.com/foo", "https://github.com/foo"), ("https://x.com", "https://x.com"), ("cleen.ocardoso.com", "https://cleen.ocardoso.com"), ("localhost:3000", "http://localhost:3000")])
    func addresses(text: String, expected: String) {
        #expect(WebAddress.url(from: text)?.absoluteString == expected)
    }

    @Test(arguments: ["notas.txt", "1.5", "olá mundo", "a.b", "foto.png"])
    func notAddresses(text: String) {
        #expect(WebAddress.url(from: text) == nil)
    }
}

struct SnippetTests {
    @Test func placeholdersAndCursor() {
        let snippet = Snippet(name: "x", text: "Oi {clipboard}, {cursor}abraço")
        let result = snippet.expanded(clipboard: "Ana")
        #expect(result.text == "Oi Ana, abraço" && result.cursorFromEnd == 6)
    }

    @Test func theLongestKeywordWins() {
        let short = Snippet(name: "a", keyword: ";e", text: "1")
        let long = Snippet(name: "b", keyword: ";email", text: "2")
        #expect(Snippet.justTyped("meu ;email", in: [short, long]) == long)
        #expect(Snippet.justTyped("meu ;e", in: [short, long]) == short)
        #expect(Snippet.justTyped("meu ;em", in: [short, long]) == nil)
    }

    @Test func bufferKeepsOnlyTheTail() {
        var buffer = TypedBuffer()
        buffer.append(String(repeating: "a", count: 60))
        buffer.append(";x")
        #expect(buffer.text.count == TypedBuffer.limit && buffer.text.hasSuffix(";x"))
        buffer.backspace()
        #expect(buffer.text.hasSuffix(";"))
    }
}

struct MeetingLinkTests {
    @Test func findsTheCallWherever() {
        #expect(MeetingLink.find(in: [nil, "Sala 3", "Entre: https://meet.google.com/abc-defg-hij obrigado"])?.host() == "meet.google.com")
        #expect(MeetingLink.find(in: ["https://us02web.zoom.us/j/123456?pwd=x"])?.path() == "/j/123456")
        #expect(MeetingLink.find(in: ["https://teams.microsoft.com/l/meetup-join/19%3a"]) != nil)
    }

    @Test func ignoresOtherLinks() {
        #expect(MeetingLink.find(in: ["https://docs.google.com/doc", "https://zoom.us/pricing", "https://meet.google.com/"]) == nil)
    }
}

struct KeyComboTests {
    @Test func displayInMenuOrder() {
        let combo = KeyCombo(keyCode: 0x0E, modifiers: KeyCombo.command | KeyCombo.control | KeyCombo.option)
        #expect(combo.display == "⌃⌥⌘E")
        #expect(combo.keycaps == ["⌃", "⌥", "⌘", "E"])
        #expect(KeyCombo(keyCode: 0x60, modifiers: 0).keycaps == ["F5"])
    }

    @Test func needsARealModifier() {
        #expect(!KeyCombo(keyCode: 0x0E, modifiers: KeyCombo.shift).isValid)
        #expect(KeyCombo(keyCode: 0x60, modifiers: 0).isValid)
        #expect(KeyCombo(keyCode: 0x0E, modifiers: KeyCombo.option).isValid)
    }
}
