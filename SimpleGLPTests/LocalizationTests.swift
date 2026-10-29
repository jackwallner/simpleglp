import Foundation
import Testing
@testable import SimpleGLP

@Suite("Localization")
struct LocalizationTests {
    static let languages = ["pt-BR", "tr", "es", "pl", "zh-Hant", "ru", "hu", "it", "de", "fr"]

    private func bundle(_ language: String) -> Bundle? {
        for host in [Bundle.main] + Bundle.allBundles {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    @Test func everyLanguageShips() {
        for language in Self.languages {
            #expect(bundle(language) != nil, "\(language).lproj is missing")
        }
    }

    @Test func russianPluralFormsResolve() throws {
        let ru = try #require(bundle("ru"))
        let locale = Locale(identifier: "ru")
        #expect(String(localized: "\(1) days", bundle: ru, locale: locale) == "1 день")
        #expect(String(localized: "\(3) days", bundle: ru, locale: locale) == "3 дня")
        #expect(String(localized: "\(5) days", bundle: ru, locale: locale) == "5 дней")
        #expect(String(localized: "\(21) days", bundle: ru, locale: locale) == "21 день")
    }

    @Test func polishPluralFormsResolve() throws {
        let pl = try #require(bundle("pl"))
        let locale = Locale(identifier: "pl")
        #expect(String(localized: "\(1) days", bundle: pl, locale: locale) == "1 dzień")
        #expect(String(localized: "\(3) days", bundle: pl, locale: locale) == "3 dni")
        #expect(String(localized: "\(5) days", bundle: pl, locale: locale) == "5 dni")
    }

    @Test func germanCopyIsTranslated() throws {
        let de = try #require(bundle("de"))
        let locale = Locale(identifier: "de")
        #expect(String(localized: "Today", bundle: de, locale: locale) == "Heute")
        #expect(String(localized: "Shot", bundle: de, locale: locale) == "Spritze")
    }

    @Test func scheduleCadenceUsesLocalizedPluralForms() throws {
        let ru = try #require(bundle("ru"))
        let pl = try #require(bundle("pl"))
        let de = try #require(bundle("de"))
        #expect(String(localized: "Every \(21) days", bundle: ru, locale: Locale(identifier: "ru")) == "Каждый 21 день")
        #expect(String(localized: "Every \(5) days", bundle: ru, locale: Locale(identifier: "ru")) == "Каждые 5 дней")
        #expect(String(localized: "Every \(5) weeks", bundle: pl, locale: Locale(identifier: "pl")) == "Co 5 tygodni")
        #expect(String(localized: "Every \(2) days", bundle: de, locale: Locale(identifier: "de")) == "Alle 2 Tage")
    }
}
