import XCTest

final class LeadTrackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndShowsMetricsScreen() {
        let app = launchUITestApp()
        XCTAssertTrue(
            app.navigationBars["Metrics"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testCreateNewMetric() {
        let app = launchUITestApp()

        app.navigationBars["Metrics"].buttons["Add Metric"].tap()
        XCTAssertTrue(
            app.navigationBars["New Metric"].waitForExistence(timeout: 5)
        )

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Reading")

        app.navigationBars["New Metric"].buttons["Save"].tap()

        XCTAssertTrue(
            app.staticTexts["Reading"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    private func launchUITestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        return app
    }
}
