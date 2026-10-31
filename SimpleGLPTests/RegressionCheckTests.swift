import Foundation
import SwiftUI
import XCTest
@preconcurrency import RevenueCat
@testable import SimpleGLP

/// Guards for the 2026-10-30 regression check against live 1.2.3.
@MainActor
final class RegressionCheckTests: XCTestCase {
    static let languages = ["pt-BR", "tr", "es", "pl", "zh-Hant", "ru", "hu", "it", "de", "fr"]

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func bundle(_ language: String) -> Bundle? {
        for host in [Bundle.main] + Bundle.allBundles {
            if let path = host.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    /// Weekly on Sundays at 9:00, starting Sunday Oct 4.
    private func weeklySundayPlan() -> MedicationPlan {
        MedicationPlan(medication: .mounjaro, doseMg: 2.5, scheduleStartDate: date(4, 0), preferredHour: 9, preferredMinute: 0, intervalDays: 7)
    }

    private func event(at timestamp: Date, plan: MedicationPlan, existing: [ShotEvent] = []) -> ShotEvent {
        let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: existing)
        return ShotEvent(timestamp: timestamp, scheduledDate: match.scheduledDate, scheduleStatus: match.status, minutesFromSchedule: match.minutesFromSchedule)
    }

    // MARK: - Weekly matching

    func testDoseCloserToTheSkippedSlotStillFillsIt() {
        let plan = weeklySundayPlan()
        let first = event(at: date(4, 9), plan: plan)
        let late = ScheduleEngine.match(timestamp: date(14, 20), plan: plan, existingEvents: [first])
        XCTAssertEqual(late.scheduledDate, date(11, 9))
        XCTAssertEqual(late.status, .late)
        let halfway = ScheduleEngine.match(timestamp: date(14, 21), plan: plan, existingEvents: [first])
        XCTAssertEqual(halfway.scheduledDate, date(11, 9))
    }

    // MARK: - Price labels

    func testOneUnitPeriodsReadPerUnit() {
        XCTAssertEqual(GLPProPriceText.label(price: "$29.99", unit: .year, value: 1), "$29.99 / year")
        XCTAssertEqual(GLPProPriceText.label(price: "$4.99", unit: .month, value: 1), "$4.99 / month")
        XCTAssertEqual(GLPProPriceText.label(price: "$1.99", unit: .week, value: 1), "$1.99 / week")
        XCTAssertEqual(GLPProPriceText.label(price: "$9.99", unit: .month, value: 3), "$9.99 / 3 months")
    }

    func testTrialLeadsTheDisclosureCapitalized() {
        XCTAssertEqual(GLPProPriceText.sentenceLead("7-day free trial", language: "en"), "7-Day Free Trial")
        XCTAssertEqual(GLPProPriceText.sentenceLead("Essai gratuit de 7 jours", language: "fr"), "Essai gratuit de 7 jours")
    }

    // MARK: - Protein

    func testProteinStaysInWholeGrams() {
        XCTAssertEqual(EditEventSheet.proteinText(120, locale: Locale(identifier: "en_US")), "120 g")
        XCTAssertEqual(EditEventSheet.proteinText(87.6, locale: Locale(identifier: "en_US")), "88 g")
    }

    // MARK: - Pill reminder

    func testPillReminderNamesTheMedicationWithoutShotDayCopy() {
        let pill = MedicationPlan(medication: .rybelsus, doseMg: 7, intervalDays: 1, waitMinutes: 30)
        let text = ReminderService.doseReminderText(for: pill)
        XCTAssertEqual(text.title, "Pill time")
        XCTAssertTrue(text.body.contains(pill.displayMedicationName))
        XCTAssertFalse(text.body.contains("planned for today"))
        let shot = ReminderService.doseReminderText(for: weeklySundayPlan())
        XCTAssertEqual(shot.title, "Shot day")
    }

    // MARK: - Catalog keys

    func testNewCopyIsTranslatedInEveryLanguage() throws {
        let keys = [
            "Notifications are off, so there’s no ping when it’s over.",
            "On-device private: no accounts, everything stays local",
            "Time for your %@. Log it after you take it.",
            "%@ / year", "%@ / week", "%@ / day",
        ]
        for language in Self.languages {
            let lproj = try XCTUnwrap(bundle(language), language)
            for key in keys {
                let value = lproj.localizedString(forKey: key, value: "\u{0}missing", table: "Localizable")
                XCTAssertNotEqual(value, "\u{0}missing", "\(language): \(key)")
                XCTAssertNotEqual(value, key, "\(language): \(key)")
            }
        }
    }

    func testNotificationsOffFooterHighlightsTheActionInEveryLanguage() throws {
        for language in ["en"] + Self.languages {
            let lproj = try XCTUnwrap(bundle(language), language)
            let locale = Locale(identifier: language)
            let copy = PillRoutineView.notificationPermissionCopy(bundle: lproj, locale: locale)
            let highlighted = copy.runs
                .filter { $0.foregroundColor == AppTheme.brand }
                .map { String(copy[$0.range].characters) }
                .joined()
            XCTAssertEqual(highlighted, String(localized: "Turn on notifications", bundle: lproj, locale: locale), language)
            XCTAssertFalse(highlighted.isEmpty, language)
        }
    }
}
