import XCTest

final class WelcomeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuestSetupAndRememberedChoiceKeepCirclesLocked() {
        let app = launchWelcome()
        tap("welcome-continue-guest", in: app)
        tap("onboarding-skip", in: app)
        let activity = app.textFields["starter-activity-name"]
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        activity.tap()
        activity.typeText("Welcome activity")
        tap("starter-activity-continue", in: app)
        tap("daily-plan-accept", in: app)
        XCTAssertTrue(app.tabBars.buttons["Circles"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Circles"].tap()
        XCTAssertTrue(app.buttons["circles-create-account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["circles-sign-in"].exists)

        app.terminate()
        app.launchArguments = ["UI_TESTING", "WELCOME_FLOW"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["welcome-continue-guest"].exists)
    }

    @MainActor
    func testSignInCancellationAndOnboardingBackReturnToWelcome() {
        let app = launchWelcome()
        tap("welcome-sign-in", in: app)
        tap("signin-back", in: app)
        XCTAssertTrue(app.buttons["welcome-continue-guest"].waitForExistence(timeout: 5))
        tap("welcome-continue-guest", in: app)
        tap("onboarding-back", in: app)
        XCTAssertTrue(app.buttons["welcome-create-account"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExistingAccountSignInSkipsOnboardingAndSurvivesRestart() {
        let app = launchWelcome()
        tap("welcome-sign-in", in: app)
        signIn(in: app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding-continue"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Signed in"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["UI_TESTING", "WELCOME_FLOW"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Signed in"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignupReadyWaitsForDoneThenStartsOnboarding() {
        let app = launchWelcome()
        tap("welcome-create-account", in: app)
        let email = app.textFields["signup-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("person@example.com")
        tap("signup-submit", in: app)
        let code = app.textFields["signup-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        code.typeText("123456")
        tap("signup-submit", in: app)
        let password = app.secureTextFields["signup-password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("secret123")
        tap("signup-submit", in: app)
        XCTAssertTrue(app.staticTexts["Account ready"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding-continue"].exists)
        tap("signup-submit", in: app)
        XCTAssertTrue(app.buttons["onboarding-continue"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignInReachedThroughSignupOpensToday() {
        let app = launchWelcome()
        tap("welcome-create-account", in: app)
        let existingAccount = app.staticTexts["Already have an account? Sign in"]
        XCTAssertTrue(existingAccount.waitForExistence(timeout: 5))
        if !existingAccount.isHittable { app.scrollViews.firstMatch.swipeUp() }
        existingAccount.tap()
        signIn(in: app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding-continue"].exists)
    }

    @MainActor
    func testInterruptedSignupResumesFromWelcomeAfterRestart() {
        let app = launchWelcome()
        tap("welcome-create-account", in: app)
        let email = app.textFields["signup-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("person@example.com")
        tap("signup-submit", in: app)
        XCTAssertTrue(app.textFields["signup-code"].waitForExistence(timeout: 5))
        tap("signup-close", in: app)
        app.terminate()
        app.launchArguments = ["UI_TESTING", "WELCOME_FLOW"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome-create-account"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["welcome-create-account"].label, "Finish creating account")
        tap("welcome-create-account", in: app)
        XCTAssertTrue(app.textFields["signup-code"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSignOutReturnsToWelcomeAndRemembersReset() {
        let app = launchWelcome()
        tap("welcome-sign-in", in: app)
        signIn(in: app)
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        tap("Sign out", in: app)
        XCTAssertTrue(app.buttons["welcome-continue-guest"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["UI_TESTING", "WELCOME_FLOW"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome-continue-guest"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargeTextKeepsAllChoicesAccessible() {
        let app = launchWelcome(largeText: true)
        XCTAssertTrue(app.buttons["welcome-create-account"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["welcome-create-account"].label, "Create account")
        XCTAssertEqual(app.buttons["welcome-sign-in"].label, "Sign in")
        XCTAssertEqual(app.buttons["welcome-continue-guest"].label, "Continue as guest")
        tap("welcome-continue-guest", in: app)
        XCTAssertTrue(app.buttons["onboarding-back"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchWelcome(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "WELCOME_FLOW", "RESET_WELCOME"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @MainActor
    private func signIn(in app: XCUIApplication) {
        let email = app.textFields["signin-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("person@example.com")
        let password = app.secureTextFields["signin-password"]
        password.tap()
        password.typeText("secret123")
        tap("signin-submit", in: app)
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        for _ in 0..<4 where !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(button.isHittable)
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }
}
