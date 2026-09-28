import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct StreakPresenterTests {

    @Test func freezeGuidanceExplainsEarningCapAndAutomaticUse() async throws {
        let presenter = try await makePresenter(streakData: makeStreakData(currentStreak: 0))

        #expect(presenter.freezeGuidance == StreakFreezePolicy.guidance)
    }

    @Test func heroStateIsStartWithoutAnyStreak() async throws {
        let presenter = try await makePresenter(streakData: makeStreakData(currentStreak: 0))

        #expect(presenter.heroState == .start)
        #expect(presenter.heroState.title == "Start your streak")
    }

    @Test func heroStateIsSecuredWhenTodayGoalIsMet() async throws {
        let presenter = try await makePresenter(
            streakData: makeStreakData(currentStreak: 3, todayEventCount: 1, dateLastEvent: Date())
        )

        #expect(presenter.heroState == .secured)
    }

    @Test func heroStateIsOpenWhenTodayIsNotLoggedYet() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let presenter = try await makePresenter(
            streakData: makeStreakData(currentStreak: 3, todayEventCount: 0, dateLastEvent: yesterday)
        )

        #expect(presenter.heroState == .open)
        #expect(presenter.heroState.title == "Today is still open")
    }

    @Test func heroStateIsRebuildWhenStreakIsBroken() async throws {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        let presenter = try await makePresenter(
            streakData: makeStreakData(currentStreak: 3, todayEventCount: 0, dateLastEvent: threeDaysAgo)
        )

        #expect(presenter.heroState == .rebuild)
    }

    @Test func freezeProgressShowsAvailableBalance() async throws {
        let presenter = try await makePresenter(
            streakData: makeStreakData(currentStreak: 7, freezesAvailableCount: 1)
        )

        #expect(presenter.freezeProgress.available == 1)
        #expect(presenter.freezeProgress.maximum == StreakFreezePolicy.maximumAvailableFreezes)
    }

    @Test func freezeProgressShowsFullBank() async throws {
        let presenter = try await makePresenter(
            streakData: makeStreakData(
                currentStreak: 14,
                freezesAvailableCount: StreakFreezePolicy.maximumAvailableFreezes
            )
        )

        #expect(presenter.freezeProgress.available == presenter.freezeProgress.maximum)
    }

    @Test func milestoneFiresOnEverySeventhDay() async throws {
        let sevenDays = try await makePresenter(streakData: makeStreakData(currentStreak: 7))
        let fourteenDays = try await makePresenter(streakData: makeStreakData(currentStreak: 14))
        let sixDays = try await makePresenter(streakData: makeStreakData(currentStreak: 6))
        let noStreak = try await makePresenter(streakData: makeStreakData(currentStreak: 0))

        #expect(sevenDays.isMilestone)
        #expect(fourteenDays.isMilestone)
        #expect(sixDays.isMilestone == false)
        #expect(noStreak.isMilestone == false)
    }

    @Test func longestRunUsesHistoricalBest() async throws {
        let presenter = try await makePresenter(
            streakData: makeStreakData(currentStreak: 5, longestStreak: 12)
        )

        #expect(presenter.longestStreak == 12)
    }

    @Test func recentDaysMarksFocusFreezeAndOpenToday() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))

        let presenter = try await makePresenter(
            streakData: makeStreakData(
                currentStreak: 1,
                recentEvents: [
                    StreakEvent.mock(dateCreated: yesterday),
                    StreakEvent.mock(dateCreated: twoDaysAgo, isFreeze: true)
                ]
            )
        )

        let days = presenter.recentDays
        #expect(days.count == 7)

        let todayDay = try #require(days.last)
        #expect(todayDay.isToday)
        #expect(todayDay.mark == .openToday)
        #expect(todayDay.accessibilityLabel == "Today, still open")

        #expect(days[days.count - 2].mark == .focus)
        #expect(days[days.count - 3].mark == .freeze)
        #expect(days.first?.mark == .empty)
    }
}

// MARK: - Helpers

@MainActor
private extension StreakPresenterTests {

    func makePresenter(streakData: CurrentStreakData) async throws -> StreakPresenter {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let streakManager = StreakManager(
            services: MockStreakServices(streak: streakData),
            configuration: Dependencies.streakConfiguration
        )
        dependencies.container.register(
            StreakManager.self,
            key: Dependencies.streakConfiguration.streakKey,
            service: streakManager
        )
        try await streakManager.logIn(userId: "streak-presenter-test-user")

        return StreakPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: StreakRouterTestDouble()
        )
    }

    func makeStreakData(
        currentStreak: Int,
        longestStreak: Int? = nil,
        freezesAvailableCount: Int = 0,
        todayEventCount: Int = 0,
        eventsRequiredPerDay: Int = 1,
        dateLastEvent: Date? = nil,
        recentEvents: [StreakEvent] = []
    ) -> CurrentStreakData {
        CurrentStreakData(
            streakKey: Dependencies.streakConfiguration.streakKey,
            userId: "streak-presenter-test-user",
            currentStreak: currentStreak,
            longestStreak: longestStreak ?? currentStreak,
            dateLastEvent: dateLastEvent,
            lastEventTimezone: TimeZone.current.identifier,
            totalEvents: recentEvents.count,
            freezesAvailableCount: freezesAvailableCount,
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount,
            recentEvents: recentEvents
        )
    }
}

@MainActor
private final class StreakRouterTestDouble: StreakRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this test double") }
}
