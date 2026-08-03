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
        createMetric(named: "Reading", in: app)

        // The new metric appears as its folded cluster stub's title, which
        // renders uppercased — match case-insensitively so the assertion
        // follows the label, not its styling.
        let stub = app.staticTexts.matching(
            NSPredicate(format: "label ==[c] %@", "Reading")
        ).firstMatch
        XCTAssertTrue(stub.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAllMetricsFromAspirationsFiltersAndOpensDetail() {
        let app = launchUITestApp()
        createMetric(named: "Reading", in: app)

        let todayMetric = app.staticTexts.matching(
            NSPredicate(format: "label ==[c] %@", "Reading")
        ).firstMatch
        XCTAssertTrue(todayMetric.waitForExistence(timeout: 5))
        app.buttons["Aspirations"].tap()
        XCTAssertTrue(app.navigationBars["Aspirations"].waitForExistence(timeout: 5))
        app.navigationBars["Aspirations"].buttons["More"].tap()
        app.buttons["All Metrics"].tap()

        XCTAssertTrue(app.navigationBars["All Metrics"].waitForExistence(timeout: 5))
        let status = app.segmentedControls["Metric Status Filter"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let metric = app.staticTexts["Reading"]
        XCTAssertTrue(metric.waitForExistence(timeout: 5))

        status.buttons["Archived"].tap()
        XCTAssertTrue(app.staticTexts["Nothing Archived"].waitForExistence(timeout: 5))
        status.buttons["Active"].tap()

        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        metric.tap()
        XCTAssertTrue(app.navigationBars.buttons["All Metrics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons["More"].waitForExistence(timeout: 5))
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

    @MainActor
    private func createMetric(named name: String, in app: XCUIApplication) {
        let today = app.navigationBars["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 30))
        let addMetric = today.buttons["Add Metric"]
        XCTAssertTrue(addMetric.waitForExistence(timeout: 5))
        addMetric.tap()
        XCTAssertTrue(app.navigationBars["New Metric"].waitForExistence(timeout: 5))

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)

        app.navigationBars["New Metric"].buttons["Save"].tap()
    }
}
