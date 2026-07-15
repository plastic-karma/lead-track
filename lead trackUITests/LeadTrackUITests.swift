import XCTest

final class LeadTrackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndShowsTodayDashboard() {
        let app = launchUITestApp()
        // A freshly cloned simulator's first cold launch in CI can take well
        // over 5s, so allow a generous timeout to avoid flaky failures.
        XCTAssertTrue(
            app.navigationBars["Today"].waitForExistence(timeout: 30)
        )
    }

    @MainActor
    func testCreateNewMetric() {
        let app = launchUITestApp()

        app.navigationBars["Today"].buttons["Add Metric"].tap()
        XCTAssertTrue(
            app.navigationBars["New Metric"].waitForExistence(timeout: 5)
        )

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Reading")

        app.navigationBars["New Metric"].buttons["Save"].tap()

        // The new metric appears as its folded cluster stub's title, which
        // renders uppercased — match case-insensitively so the assertion
        // follows the label, not its styling.
        let stub = app.staticTexts.matching(
            NSPredicate(format: "label ==[c] %@", "Reading")
        ).firstMatch
        XCTAssertTrue(stub.waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchUITestApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Mirrors LaunchArguments.uiTest — the UI-test bundle cannot import
        // the app module, so this literal must stay in sync by hand.
        app.launchArguments = ["-uitest"]
        app.launch()
        return app
    }
}
