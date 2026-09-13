import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct TabBarPresenterTests {

    @Test func focusProgressShowsRunningAndPausedCountdowns() throws {
        let context = makeContext()
        let session = try #require(
            context.interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )

        context.presenter.syncProgressTicker()
        #expect(context.presenter.progressStatus == nil)

        _ = try context.interactor.focusManager.beginFocusSession(focusSessionId: session.focusSessionId)
        context.presenter.syncProgressTicker()

        #expect(context.presenter.progressStatusKind == .focusRunning)
        #expect(context.presenter.progressRemainingSeconds > 1_490)

        _ = try context.interactor.focusManager.pauseFocusSession(focusSessionId: session.focusSessionId)
        context.presenter.syncProgressTicker()

        #expect(context.presenter.progressStatusKind == .focusPaused)
        #expect(context.presenter.progressRemainingSeconds <= FocusSessionModel.pauseAllowanceSeconds)
        #expect(context.presenter.progressRemainingSeconds > FocusSessionModel.pauseAllowanceSeconds - 5)
        context.presenter.onViewDisappear(delegate: context.delegate)
    }

    @Test func focusProgressHidesOnFocusScreenAndAfterSessionEnds() throws {
        let context = makeContext()
        let session = try #require(
            context.interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try context.interactor.focusManager.beginFocusSession(focusSessionId: session.focusSessionId)

        context.presenter.syncProgressTicker()
        #expect(context.presenter.progressStatusKind == .focusRunning)

        context.interactor.setFocusScreenVisible(true)
        context.presenter.syncProgressTicker()
        #expect(context.presenter.progressStatus == nil)

        context.interactor.setFocusScreenVisible(false)
        _ = try context.interactor.focusManager.abandonFocusSession(focusSessionId: session.focusSessionId)
        context.presenter.syncProgressTicker()
        #expect(context.presenter.progressStatus == nil)
    }

    @Test func pressingFocusProgressSelectsTodayAndReopensTheSameSession() throws {
        let context = makeContext(startingTabId: "Rewards")
        let session = try #require(
            context.interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try context.interactor.focusManager.beginFocusSession(focusSessionId: session.focusSessionId)
        context.presenter.syncProgressTicker()

        context.presenter.onProgressStatusPressed(delegate: context.delegate)

        #expect(context.presenter.selectedTab == "Today")
        #expect(context.router.presentedDelegate?.session.focusSessionId == session.focusSessionId)
        #expect(context.router.presentedDelegate?.activity.activityId == session.activityId)
        context.presenter.onViewDisappear(delegate: context.delegate)
    }

    private func makeContext(startingTabId: String = "Today") -> TestContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTabBarRouter()
        let tabs = [
            TabBarTab(title: "Today", systemImage: "sun.max.fill") { _ in EmptyView() },
            TabBarTab(title: "Rewards", systemImage: "gift.fill") { _ in EmptyView() },
            TabBarTab(title: "Circles", systemImage: "person.3.fill") { _ in EmptyView() },
            TabBarTab(title: "Settings", systemImage: "gearshape.fill") { _ in EmptyView() }
        ]
        let delegate = TabBarDelegate(tabs: tabs, startingTabId: startingTabId)
        let presenter = TabBarPresenter(
            interactor: interactor,
            router: router,
            delegate: delegate
        )
        return TestContext(
            interactor: interactor,
            router: router,
            presenter: presenter,
            delegate: delegate
        )
    }
}

@MainActor
private struct TestContext {
    let interactor: CoreInteractor
    let router: RecordingTabBarRouter
    let presenter: TabBarPresenter
    let delegate: TabBarDelegate
}

@MainActor
private final class RecordingTabBarRouter: TabBarRouter {
    private(set) var presentedDelegate: FocusDelegate?

    func showFocusOverlay(delegate: FocusDelegate) {
        presentedDelegate = delegate
    }
}
