import Foundation
import Testing
@testable import CleenKit

struct ConverterNumberTests {
    @Test(arguments: [
        ("1", 1.0), ("0,5", 0.5), (",5", 0.5), ("1.234,56", 1234.56), ("1234,56", 1234.56),
        ("1.000", 1000), ("2.500.000", 2_500_000), ("1.5", 1.5), ("0.25", 0.25), ("1,234.5", 1234.5),
        ("-3", -3), ("−2,5", -2.5), (" 42 ", 42), ("1,", 1), ("10.", 10),
    ])
    func parsesBrazilianAndHabitualInput(text: String, expected: Double) throws {
        let value = try #require(ConverterNumber.parse(text))
        #expect(abs(value - expected) < 1e-9)
    }

    @Test(arguments: ["", "  ", "abc", "1,2,3", "1.2.3,4,5", "-", ".", "12a"])
    func rejectsNonNumbers(text: String) {
        #expect(ConverterNumber.parse(text) == nil)
    }

    @Test(arguments: [
        (1.609344, "1,6093"), (1000.0, "1.000"), (12345.678, "12.345,7"), (0.000621371, "0,0006214"),
        (2.0, "2"), (0.001, "0,001"), (1_234_567.891, "1.234.568"), (0.0, "0"), (-40.0, "-40"),
    ])
    func formatsWithoutTrailingZeros(value: Double, expected: String) {
        #expect(ConverterNumber.format(value, locale: Locale(identifier: "pt_BR")) == expected)
    }

    @Test func formatsMoneyWithCents() {
        #expect(ConverterNumber.format(5, isCurrency: true, locale: Locale(identifier: "pt_BR")) == "5,00")
        #expect(ConverterNumber.format(1234.5, isCurrency: true, locale: Locale(identifier: "pt_BR")) == "1.234,50")
        #expect(ConverterNumber.format(0.004, isCurrency: true, locale: Locale(identifier: "pt_BR")) == "0,004")
    }

    @Test func extremesGoScientific() {
        #expect(ConverterNumber.format(1e-12).contains("E") || ConverterNumber.format(1e-12).contains("e"))
        #expect(ConverterNumber.format(.infinity) == "—")
    }
}

struct UnitConversionTests {
    private func unit(_ category: ConverterCategory, _ id: String) throws -> ConverterUnit {
        try #require(category.units.first { $0.id == id })
    }

    @Test func lengths() throws {
        let miles = try #require(UnitConversion.convert(1, from: unit(.length, "mi"), to: unit(.length, "km")))
        #expect(abs(miles - 1.609344) < 1e-9)
    }

    @Test func temperaturesAreAffine() throws {
        let f = try #require(UnitConversion.convert(100, from: unit(.temperature, "c"), to: unit(.temperature, "f")))
        #expect(abs(f - 212) < 1e-9)
        let same = try #require(UnitConversion.convert(-40, from: unit(.temperature, "c"), to: unit(.temperature, "f")))
        #expect(abs(same + 40) < 1e-9)
    }

    @Test func daysAndYears() throws {
        let hours = try #require(UnitConversion.convert(2, from: unit(.time, "d"), to: unit(.time, "h")))
        #expect(abs(hours - 48) < 1e-9)
        let days = try #require(UnitConversion.convert(1, from: unit(.time, "yr"), to: unit(.time, "d")))
        #expect(abs(days - 365.2425) < 1e-9)
    }

    @Test func dataUsesDecimalAndBinaryPrefixes() throws {
        let mb = try #require(UnitConversion.convert(1, from: unit(.data, "GB"), to: unit(.data, "MB")))
        #expect(abs(mb - 1000) < 1e-9)
        let mib = try #require(UnitConversion.convert(1, from: unit(.data, "GiB"), to: unit(.data, "MiB")))
        #expect(abs(mib - 1024) < 1e-9)
    }

    @Test func everyUnitHasAFoundationDimension() {
        for category in ConverterCategory.allCases where category != .currency {
            for unit in category.units {
                #expect(unit.dimension != nil, "\(unit.id)")
            }
            let ids = category.units.map(\.id)
            #expect(ids.contains(category.defaultPair.from) && ids.contains(category.defaultPair.to))
        }
    }

    @Test func refusesMixedDimensions() throws {
        #expect(try UnitConversion.convert(1, from: unit(.length, "m"), to: unit(.mass, "kg")) == nil)
    }
}

struct CurrencyRatesTests {
    private let sample = Data(#"{"amount":1.0,"base":"USD","date":"2026-10-22","rates":{"BRL":5.4,"EUR":0.9,"JPY":150.0,"ZAR":18.0}}"#.utf8)

    @Test func decodesFrankfurter() throws {
        let rates = try CurrencyRates.decode(sample, fetchedAt: Date(timeIntervalSince1970: 0))
        #expect(rates.base == "USD")
        #expect(rates.date == "2026-10-22")
        #expect(rates.rates["USD"] == 1)
        #expect(rates.rates["BRL"] == 5.4)
    }

    @Test func crossRatesGoThroughTheBase() throws {
        let rates = try CurrencyRates.decode(sample)
        let usd = try #require(rates.convert(10.8, from: "BRL", to: "USD"))
        #expect(abs(usd - 2) < 1e-9)
        let eur = try #require(rates.convert(5.4, from: "BRL", to: "EUR"))
        #expect(abs(eur - 0.9) < 1e-9)
        #expect(rates.convert(1, from: "BRL", to: "XYZ") == nil)
    }

    @Test func refreshesAfterTwelveHours() {
        let fetched = Date(timeIntervalSince1970: 1_000_000)
        let rates = CurrencyRates(base: "USD", date: "2026-10-22", rates: [:], fetchedAt: fetched)
        #expect(!rates.isStale(at: fetched.addingTimeInterval(11 * 3600)))
        #expect(rates.isStale(at: fetched.addingTimeInterval(12 * 3600)))
        // A clock set back must not freeze the rates forever.
        #expect(rates.isStale(at: fetched.addingTimeInterval(-60)))
    }

    @Test func commonCurrenciesFirst() throws {
        let rates = try CurrencyRates.decode(sample)
        let ids = rates.units.map(\.id)
        #expect(Array(ids.prefix(4)) == ["BRL", "USD", "EUR", "JPY"])
        #expect(ids.contains("ZAR"))
        #expect(rates.units.first?.name == Locale.cleen.localizedString(forCurrencyCode: "BRL"))
    }

    @Test func roundTripsThroughCodable() throws {
        let rates = try CurrencyRates.decode(sample)
        let copy = try JSONDecoder().decode(CurrencyRates.self, from: JSONEncoder().encode(rates))
        #expect(copy == rates)
    }

    @Test func publicationDay() throws {
        let rates = try CurrencyRates.decode(sample)
        let day = try #require(rates.publishedOn)
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: day)
        #expect(parts.year == 2026 && parts.month == 10 && parts.day == 22)
    }
}
