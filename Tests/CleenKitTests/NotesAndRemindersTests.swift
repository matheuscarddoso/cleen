import Foundation
import Testing
@testable import CleenKit

struct QuickNoteTests {
    @Test func titleIsTheFirstLineWithWords() {
        #expect(QuickNote(text: "\n   \n  Lista do mercado  \nleite\n").title == "Lista do mercado")
        #expect(QuickNote(text: " \n\t").title == nil)
        #expect(QuickNote(text: "").title == nil)
    }

    @Test func previewDropsBlankLines() {
        #expect(QuickNote(text: "Um\n\n\n  dois \n").preview == "Um\ndois")
    }

    @Test func blankMeansOnlyWhitespace() {
        #expect(QuickNote(text: " \n\t ").isBlank)
        #expect(!QuickNote(text: " a ").isBlank)
    }
}

struct QuickNotebookTests {
    @Test func alwaysHasANote() {
        var book = QuickNotebook()
        #expect(book.notes.count == 1)
        book.remove(book.selectedID)
        #expect(book.notes.count == 1)
        #expect(book.selected.isBlank)
    }

    @Test func addReusesTheBlankNote() {
        var book = QuickNotebook()
        let first = book.selectedID
        let added = book.add()
        #expect(added)
        #expect(book.notes.count == 1)
        #expect(book.selectedID == first)
    }

    @Test func addStopsAtTheLimit() {
        var book = QuickNotebook()
        for index in 0..<QuickNotebook.limit {
            book.update(book.selectedID, text: "Nota \(index)")
            if index < QuickNotebook.limit - 1 {
                let added = book.add()
                #expect(added)
            }
        }
        #expect(book.notes.count == QuickNotebook.limit)
        #expect(!book.canAdd)
        let added = book.add()
        #expect(!added)
    }

    @Test func leavingABlankNoteRemovesIt() {
        var book = QuickNotebook()
        book.update(book.selectedID, text: "Primeira")
        let first = book.selectedID
        book.add()
        #expect(book.notes.count == 2)
        book.select(first)
        #expect(book.notes.count == 1)
        #expect(book.selected.text == "Primeira")
    }

    @Test func removeOpensTheNeighbour() {
        var book = QuickNotebook()
        book.update(book.selectedID, text: "A")
        book.add(); book.update(book.selectedID, text: "B")
        book.add(); book.update(book.selectedID, text: "C")
        let b = book.notes[1].id
        book.select(b)
        book.remove(b)
        #expect(book.notes.map(\.text) == ["A", "C"])
        #expect(book.selected.text == "C")
        book.remove(book.selectedID)
        #expect(book.selected.text == "A")
    }

    @Test func updateStampsOnlyRealChanges() {
        var book = QuickNotebook()
        let id = book.selectedID
        let date = Date(timeIntervalSince1970: 1_000)
        book.update(id, text: "Oi", at: date)
        book.update(id, text: "Oi", at: date.addingTimeInterval(60))
        #expect(book.selected.updatedAt == date)
    }

    @Test func roundTripsAndRepairsBadFiles() throws {
        var book = QuickNotebook()
        book.update(book.selectedID, text: "Salva")
        let data = try JSONEncoder().encode(book)
        #expect(try JSONDecoder().decode(QuickNotebook.self, from: data) == book)

        let broken = Data(#"{"notes":[],"selectedID":"6F1C0C0A-1B2C-4D5E-8F90-123456789ABC"}"#.utf8)
        let repaired = try JSONDecoder().decode(QuickNotebook.self, from: broken)
        #expect(repaired.notes.count == 1)
        #expect(repaired.selectedID == repaired.notes[0].id)
    }

    @Test func absorbKeepsWhatWasTypedBeforeTheLoad() {
        var saved = QuickNotebook()
        saved.update(saved.selectedID, text: "Do disco")
        var typed = QuickNotebook()
        typed.update(typed.selectedID, text: "Digitada agora")
        saved.absorb(typed)
        #expect(saved.notes.map(\.text) == ["Do disco", "Digitada agora"])
        #expect(saved.selected.text == "Digitada agora")

        var untouched = saved
        untouched.absorb(QuickNotebook())
        #expect(untouched == saved)
    }
}

struct ReminderOrderTests {
    struct Item: ReminderSortable, Equatable {
        let title: String
        let due: Date?
        let isStarred: Bool
    }

    @Test func starredFirstThenDueThenUndated() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let items = [
            Item(title: "Sem data", due: nil, isStarred: false),
            Item(title: "Depois", due: now.addingTimeInterval(3_600), isStarred: false),
            Item(title: "Estrela sem data", due: nil, isStarred: true),
            Item(title: "Antes", due: now, isStarred: false),
            Item(title: "Estrela", due: now.addingTimeInterval(7_200), isStarred: true),
        ]
        #expect(items.sortedForReminders().map(\.title) == ["Estrela", "Estrela sem data", "Antes", "Depois", "Sem data"])
    }

    @Test func tiesGoByTitle() {
        let items = [Item(title: "b", due: nil, isStarred: false), Item(title: "A", due: nil, isStarred: false)]
        #expect(items.sortedForReminders().map(\.title) == ["A", "b"])
    }
}

struct ReminderDueTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func readsLikeReminders() {
        let now = date(2026, 10, 23, 9)
        #expect(ReminderDue.text(for: date(2026, 10, 23, 14), hasTime: true, now: now, calendar: calendar, locale: Locale(identifier: "pt_BR")) == "14:00")
        #expect(ReminderDue.text(for: date(2026, 10, 23), hasTime: false, now: now, calendar: calendar, locale: Locale(identifier: "pt_BR")) == "Hoje")
        #expect(ReminderDue.text(for: date(2026, 10, 24, 8, 30), hasTime: true, now: now, calendar: calendar, locale: Locale(identifier: "pt_BR")) == "Amanhã, 08:30")
        #expect(ReminderDue.text(for: date(2026, 10, 22), hasTime: false, now: now, calendar: calendar, locale: Locale(identifier: "pt_BR")) == "Ontem")
        #expect(ReminderDue.text(for: date(2026, 10, 30), hasTime: false, now: now, calendar: calendar, locale: Locale(identifier: "pt_BR")) == "30 de out.")
        #expect(ReminderDue.text(for: date(2027, 1, 5), hasTime: false, now: now, calendar: calendar, locale: Locale(identifier: "pt_BR")).contains("2027"))
    }

    @Test func pastDue() {
        let now = date(2026, 10, 23, 9)
        #expect(ReminderDue.isPast(date(2026, 10, 23, 8), hasTime: true, now: now, calendar: calendar))
        #expect(!ReminderDue.isPast(date(2026, 10, 23), hasTime: false, now: now, calendar: calendar))
        #expect(ReminderDue.isPast(date(2026, 10, 22), hasTime: false, now: now, calendar: calendar))
    }
}
