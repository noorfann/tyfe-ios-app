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
}

@MainActor
private final class RecordingTodayRouter: TodayRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this recording test double") }
    private(set) var didShowStreak = false

    func showStarterActivityView(delegate: StarterActivityDelegate) { }
    func showDailyPlanView(delegate: DailyPlanDelegate) { }
    func showFocusView(delegate: FocusDelegate) { }

    func showStreakView(delegate: StreakDelegate) {
        didShowStreak = true
    }

    #if MOCK || DEV
    func showDevSettingsView() { }
    #endif
}
