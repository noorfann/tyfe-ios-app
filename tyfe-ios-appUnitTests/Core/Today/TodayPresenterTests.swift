import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayPresenterTests {

    @Test func streakCountUsesCurrentValueOrZero() {
        #expect(TodayPresenter.streakCount(from: makeStreakData(currentStreak: 7)) == 7)
        #expect(TodayPresenter.streakCount(from: makeStreakData(currentStreak: 0)) == 0)
        #expect(TodayPresenter.streakCount(from: makeStreakData(currentStreak: nil)) == 0)
    }

    private func makeStreakData(currentStreak: Int?) -> CurrentStreakData {
        CurrentStreakData(
            streakKey: "focus",
            userId: "test-user",
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            totalEvents: currentStreak ?? 0,
            freezesAvailableCount: 0,
            eventsRequiredPerDay: 1,
            todayEventCount: 0
        )
    }

    @Test func pressingStreakRequestsDetailRoute() {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(interactor: interactor, router: router)

        presenter.onStreakPressed()

        #expect(router.didShowStreak)
        #expect(TodayPresenter.Event.openStreak.eventName == "Today_Streak_Open")
    }

    @Test func streakCountReadsLiveManagerState() async throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let streakManager = try #require(
            dependencies.container.resolve(
                StreakManager.self,
                key: Dependencies.streakConfiguration.streakKey
            )
        )
        try await streakManager.logIn(userId: "today-streak-test-user")
        let interactor = CoreInteractor(container: dependencies.container)
        let presenter = TodayPresenter(interactor: interactor, router: RecordingTodayRouter())

        #expect(presenter.currentStreakCount == 0)
        try await interactor.recordFocusCompletionForStreak(.completedMock)
        #expect(presenter.currentStreakCount == 1)
    }

    @Test func editingActivityUpdatesGlobalDetailsAndPlannedDuration() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 2
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let item = try #require(presenter.planItems.first)

        presenter.onEditActivityPressed(item)
        #expect(presenter.isActivityDetailSheetPresented)
        #expect(presenter.editingActivity?.activityId == item.activityId)

        presenter.saveActivityEdits(
            name: "  Renamed activity  ",
            category: .work,
            sessionCount: 4
        )

        #expect(manager.activities.first { $0.activityId == item.activityId }?.name == "Renamed activity")
        #expect(manager.activities.first { $0.activityId == item.activityId }?.category == .work)
        #expect(manager.dailyPlan?.planItems.first?.plannedSessionCount == 4)
        #expect(!presenter.isActivityDetailSheetPresented)
        #expect(presenter.editingActivity == nil)
        #expect(presenter.editingPlanItem == nil)
    }

    @Test func dismissingActivityEditorDiscardsDraftState() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 2
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let item = try #require(presenter.planItems.first)
        let originalActivity = try #require(presenter.activity(for: item))

        presenter.onEditActivityPressed(item)
        presenter.isActivityDetailSheetPresented = false
        presenter.onActivityDetailSheetDismissed()

        #expect(manager.activities.first { $0.activityId == item.activityId } == originalActivity)
        #expect(manager.dailyPlan?.planItems.first?.plannedSessionCount == 2)
        #expect(presenter.editingActivity == nil)
        #expect(presenter.editingPlanItem == nil)
    }

    @Test func removingUnstartedActivityFromEditorClearsPlan() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let item = try #require(presenter.planItems.first)

        presenter.onEditActivityPressed(item)
        presenter.removeEditingActivityFromToday()

        #expect(manager.dailyPlan == nil)
        #expect(!presenter.isActivityDetailSheetPresented)
        #expect(presenter.planItems.isEmpty)
    }

    @Test func creatingActivitySelectsItsCardForImmediateVisibility() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let existingItem = try #require(presenter.planItems.first)
        #expect(presenter.selectedPlanItemId == existingItem.id)

        presenter.saveActivity(name: "Write report", category: .work, sessionCount: 1)

        let newActivity = try #require(manager.activities.first { $0.name == "Write report" })
        let newItem = try #require(
            presenter.planItems.first { $0.activityId == newActivity.activityId }
        )
        #expect(presenter.planItems.count == 2)
        #expect(presenter.selectedPlanItemId == newItem.id)
    }

    @Test func startingFocusUsesTheLatestSelectedActivity() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let secondActivity = try #require(
            manager.createActivity(name: "Write report", category: .work, colorToken: "slateBlue")
        )
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        _ = manager.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: router
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectNextPlanItem()

        presenter.onStartFocusPressed()

        let delegate = try #require(router.presentedFocusDelegate)
        #expect(delegate.activity.activityId == secondActivity.activityId)
        #expect(delegate.session.activityId == secondActivity.activityId)
    }

    @Test func selectedActivityReplacesAnUnstartedReadySession() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
        let secondActivity = try #require(
            manager.createActivity(name: "Write report", category: .work, colorToken: "slateBlue")
        )
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        _ = manager.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(interactor: interactor, router: router)
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.onStartFocusPressed()
        let firstSession = try #require(focusManager.focusSessions.first)

        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectNextPlanItem()
        presenter.onStartFocusPressed()

        let delegate = try #require(router.presentedFocusDelegate)
        #expect(delegate.activity.activityId == secondActivity.activityId)
        #expect(delegate.session.activityId == secondActivity.activityId)
        #expect(focusManager.focusSessions.count == 2)
        #expect(
            focusManager.focusSessions.first { $0.focusSessionId == firstSession.focusSessionId }?.state == .abandoned
        )
        #expect(focusManager.activeFocusSession?.activityId == secondActivity.activityId)
    }

    @Test func runningFocusSessionRemainsAuthoritativeForAnotherSelection() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
        let secondActivity = try #require(
            manager.createActivity(name: "Write report", category: .work, colorToken: "slateBlue")
        )
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        _ = manager.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(interactor: interactor, router: router)
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.onStartFocusPressed()
        let firstSession = try #require(focusManager.focusSessions.first)
        _ = try focusManager.beginFocusSession(focusSessionId: firstSession.focusSessionId)

        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectNextPlanItem()
        presenter.onStartFocusPressed()

        let delegate = try #require(router.presentedFocusDelegate)
        #expect(delegate.activity.activityId == ActivityModel.mock.activityId)
        #expect(delegate.session.focusSessionId == firstSession.focusSessionId)
        #expect(focusManager.focusSessions.count == 1)
    }
}

@MainActor
private final class RecordingTodayRouter: TodayRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this recording test double") }
    private(set) var didShowStreak = false
    private(set) var presentedFocusDelegate: FocusDelegate?

    func showStarterActivityView(delegate: StarterActivityDelegate) { }
    func showDailyPlanView(delegate: DailyPlanDelegate) { }
    func showFocusView(delegate: FocusDelegate) {
        presentedFocusDelegate = delegate
    }

    func showStreakView(delegate: StreakDelegate) {
        didShowStreak = true
    }

    func showDevSettingsView() { }
}
