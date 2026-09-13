//
//  tyfe-ios-appUITests.swift
//  tyfe-ios-appUITests
//
//  
//

import XCTest

final class TyfeappUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testDesignSystemGalleryLaunchesInUITestHarness() throws {
        let app = XCUIApplication()
        app.launchArguments.append("DESIGN_SYSTEM_GALLERY")
        app.launch()

        XCTAssertTrue(app.staticTexts["Tyfe building blocks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Focus Chamber"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPhase1PlanningFlowReachesFocusReady() throws {
        let app = XCUIApplication()
        app.launchArguments.append("PHASE1_FLOW")
        app.launch()

        XCTAssertTrue(app.buttons["Create today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Create today’s plan"].tap()

        XCTAssertTrue(app.staticTexts["STARTER ACTIVITY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue to today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Continue to today’s plan"].tap()

        XCTAssertTrue(app.staticTexts["DAILY PLAN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Set today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Set today’s plan"].tap()

        XCTAssertTrue(app.buttons["Start Focus"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Start Focus"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["FOCUS CHAMBER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Begin Focus"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBeginningFocusRequiresConfirmationBeforeStarting() throws {
        let app = XCUIApplication()
        app.launchArguments.append("PHASE1_FLOW")
        app.launch()

        XCTAssertTrue(app.buttons["Create today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Create today’s plan"].tap()

        XCTAssertTrue(app.buttons["Continue to today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Continue to today’s plan"].tap()

        XCTAssertTrue(app.buttons["Set today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Set today’s plan"].tap()

        XCTAssertTrue(app.buttons["Start Focus"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Start Focus"].firstMatch.tap()

        XCTAssertTrue(app.buttons["Begin Focus"].waitForExistence(timeout: 5))
        app.buttons["Begin Focus"].tap()

        let alert = app.alerts["Start Focus Session?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(
            alert.staticTexts[
                "Once you begin, you can't browse the app until you finish or abandon this session."
            ].waitForExistence(timeout: 5)
        )

        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Begin Focus"].waitForExistence(timeout: 5))

        app.buttons["Begin Focus"].tap()
        XCTAssertTrue(alert.buttons["Start Focus"].waitForExistence(timeout: 5))
        alert.buttons["Start Focus"].tap()
        XCTAssertTrue(app.buttons["Pause once"].waitForExistence(timeout: 5))
    }

#if MOCK
    @MainActor
    func testStartingLaterRewardShowsTopStatusBarWhenStarted() throws {
        let app = XCUIApplication()
        app.launchArguments.append("REWARD_FLOW")
        app.launch()

        XCTAssertTrue(app.buttons["Rewards"].waitForExistence(timeout: 5))
        app.buttons["Rewards"].tap()

        XCTAssertTrue(app.buttons["Take this Reward"].waitForExistence(timeout: 5))
        app.buttons["Take this Reward"].tap()

        let claimAlert = app.alerts["Claim Scroll social media?"]
        XCTAssertTrue(claimAlert.waitForExistence(timeout: 5))
        claimAlert.buttons["Start later"].tap()

        XCTAssertTrue(app.buttons["Start now"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reward-in-progress-status"].exists)

        app.buttons["Start now"].tap()

        XCTAssertTrue(app.buttons["reward-in-progress-status"].waitForExistence(timeout: 5))
        app.buttons["Today"].tap()
        app.buttons["reward-in-progress-status"].tap()
        XCTAssertTrue(app.buttons["Rewards"].isSelected)
    }

    @MainActor
    func testHomeFlowDisplaysLivePlanAndReachesFocusReady() throws {
        let app = XCUIApplication()
        app.launchArguments.append("HOME_FLOW")
        app.launch()

        XCTAssertTrue(app.staticTexts["Study Swift"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DAILY PLAN, 0/2, sessions complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CREDITS, 0, Reward Credits"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Focus for Study Swift"].waitForExistence(timeout: 5))

        app.buttons["Start Focus for Study Swift"].tap()

        XCTAssertTrue(app.staticTexts["FOCUS CHAMBER"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Begin Focus"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeFlowCompletionUpdatesProgressAndCredits() throws {
        let app = XCUIApplication()
        app.launchArguments.append("HOME_FLOW")
        app.launch()

        XCTAssertTrue(app.buttons["Start Focus for Study Swift"].waitForExistence(timeout: 5))
        app.buttons["Start Focus for Study Swift"].tap()

        XCTAssertTrue(app.buttons["Mark complete"].waitForExistence(timeout: 5))
        app.buttons["Mark complete"].tap()

        XCTAssertTrue(app.staticTexts["Session complete"].waitForExistence(timeout: 5))
        app.buttons["Back to Today"].tap()

        XCTAssertTrue(app.staticTexts["DAILY PLAN, 1/2, sessions complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CREDITS, 1, Reward Credits"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyHomeFlowDisablesFocusAndExplainsHowToStart() throws {
        let app = XCUIApplication()
        app.launchArguments.append("HOME_EMPTY_FLOW")
        app.launch()

        XCTAssertTrue(app.staticTexts["Create a plan in Today to unlock Focus."].waitForExistence(timeout: 5))
        let focusButton = app.buttons["Focus unavailable"]
        XCTAssertTrue(focusButton.waitForExistence(timeout: 5))
        XCTAssertFalse(focusButton.isEnabled)
    }

    @MainActor
    func testMockCanMarkFocusCompleteWithoutWaitingForTheTimer() throws {
        let app = XCUIApplication()
        app.launchArguments.append("PHASE1_FLOW")
        app.launch()

        XCTAssertTrue(app.buttons["Create today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Create today’s plan"].tap()

        XCTAssertTrue(app.buttons["Continue to today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Continue to today’s plan"].tap()

        XCTAssertTrue(app.buttons["Set today’s plan"].waitForExistence(timeout: 5))
        app.buttons["Set today’s plan"].tap()

        XCTAssertTrue(app.buttons["Start Focus"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Start Focus"].firstMatch.tap()

        XCTAssertTrue(app.buttons["Mark complete"].waitForExistence(timeout: 5))
        app.buttons["Mark complete"].tap()

        XCTAssertTrue(app.staticTexts["Session complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You earned +1 Reward Credit."].waitForExistence(timeout: 5))
    }
#endif
}
