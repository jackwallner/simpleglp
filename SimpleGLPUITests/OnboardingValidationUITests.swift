import XCTest

/// A custom medication needs a name before onboarding moves on, so the last step
/// (which has no Back) can never be reached with a plan that won't save.
@MainActor
final class OnboardingValidationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testUnnamedCustomMedicationCannotLeaveTheMedicationStep() {
        let app = XCUIApplication()
        app.launch()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 20))
        continueButton.tap()

        let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ozempic'")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        let other = app.buttons["Other"]
        XCTAssertTrue(other.waitForExistence(timeout: 10))
        other.tap()

        let name = app.textFields["Medication name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)

        name.tap()
        name.typeText("Trulicity")
        XCTAssertTrue(continueButton.isEnabled)
    }
}
