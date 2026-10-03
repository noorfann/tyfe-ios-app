import XCTest

final class SignupUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignupFinishesAndImmediatelyUpdatesSettings() {
        let app = launchSignup()
        openSignup(in: app)
        enterEmailAndVerify(in: app)
        let password = app.secureTextFields["signup-password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("secret123")
        tapPrimary(in: app)
        XCTAssertTrue(app.staticTexts["Account ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["signup-submit"].label.contains("Done"))
        tapPrimary(in: app)
        XCTAssertTrue(app.staticTexts["Signed in"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings-create-account"].exists)
    }

    @MainActor
    func testInvalidCodeAndRestartResumeAtTheCorrectStep() {
        let app = launchSignup()
        openSignup(in: app)
        let email = app.textFields["signup-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("person@example.com")
        tapPrimary(in: app)
        let code = app.textFields["signup-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["signup-resend"].isEnabled)
        code.tap()
        code.typeText("111111")
        tapPrimary(in: app)
        XCTAssertTrue(app.staticTexts["signup-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["signup-code"].exists)

        app.terminate()
        app.launchArguments.removeAll { $0 == "RESET_SIGNUP" }
        app.launch()
        openSignup(in: app)
        XCTAssertTrue(app.textFields["signup-code"].waitForExistence(timeout: 5))
        app.textFields["signup-code"].tap()
        app.textFields["signup-code"].typeText("123456")
        tapPrimary(in: app)
        XCTAssertTrue(app.secureTextFields["signup-password"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openSignup(in: app)
        XCTAssertTrue(app.secureTextFields["signup-password"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["signup-code"].exists)
        app.secureTextFields["signup-password"].tap()
        app.secureTextFields["signup-password"].typeText("secret123")
        tapPrimary(in: app)
        XCTAssertTrue(app.staticTexts["Account ready"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargeTextSignupFieldsRemainAccessible() {
        let app = launchSignup(largeText: true)
        openSignup(in: app)
        XCTAssertTrue(app.textFields["signup-email"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["signup-email"].label, "Email")
        XCTAssertEqual(app.textFields["signup-name"].label, "Display name, optional")
        XCTAssertEqual(app.buttons["signup-close"].label, "Close")
    }

    @MainActor
    private func launchSignup(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNUP_FLOW", "RESET_SIGNUP"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @MainActor
    private func openSignup(in app: XCUIApplication) {
        let create = app.buttons["settings-create-account"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        if !create.isHittable { app.scrollViews.firstMatch.swipeUp() }
        create.tap()
    }

    @MainActor
    private func enterEmailAndVerify(in app: XCUIApplication) {
        let email = app.textFields["signup-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("person@example.com")
        tapPrimary(in: app)
        let code = app.textFields["signup-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        code.typeText("123456")
        tapPrimary(in: app)
    }

    @MainActor
    private func tapPrimary(in app: XCUIApplication) {
        let primary = app.buttons["signup-submit"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        for _ in 0..<3 where !primary.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(primary.isHittable)
        XCTAssertTrue(primary.isEnabled)
        primary.tap()
    }
}
