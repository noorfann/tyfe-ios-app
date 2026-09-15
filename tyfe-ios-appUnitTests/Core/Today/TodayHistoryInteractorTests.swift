import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayHistoryInteractorTests {

    @Test func interactorProjectsTheRequestedHistoricalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let currentDay = LocalDay(year: 2026, month: 9, day: 15, timeZoneIdentifier: calendar.timeZone.identifier)
        let historicalDay = currentDay.adding(days: -2)
        let activity = ActivityModel.mock
        let plan = DailyPlanModel(
            dailyPlanId: "daily-plan-interactor-history",
            localDate: historicalDay.startDate,
            localDay: historicalDay,
            intendedSessionCount: 2,
            originalIntendedSessionCount: 2,
            activityIds: [activity.activityId],
            planItems: [
                DailyPlanItemModel(
                    planItemId: "plan-item-interactor-history",
                    activityId: activity.activityId,
                    plannedSessionCount: 2
                )
            ]
        )
        let session = FocusSessionModel(
            focusSessionId: "focus-session-interactor-history",
            activityId: activity.activityId,
            state: .completed,
            startedAt: historicalDay.startDate.addingTimeInterval(3_600),
            localDay: historicalDay,
            dailyPlanIdAtStart: plan.dailyPlanId,
            completedAt: historicalDay.startDate.addingTimeInterval(5_100)
        )
        let repository = MockLocalAppRepository(snapshot: LocalAppSnapshot(
            activities: [activity],
            dailyPlans: [plan],
            focusSessions: [session],
            nextActivityNumber: 2,
            nextSessionNumber: 2
        ))
        let clock = TestFocusClock(now: currentDay.startDate.addingTimeInterval(43_200))
        let todayManager = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        dependencies.container.register(TodayManager.self, service: todayManager)
        let interactor = CoreInteractor(container: dependencies.container)

        #expect(interactor.phase1CurrentLocalDay == currentDay)
        #expect(interactor.phase1EarliestRecordedLocalDay == historicalDay)
        #expect(interactor.phase1DailyPlan(for: historicalDay) == plan)
        #expect(interactor.phase1CompletedSessionCount(on: historicalDay) == 1)
        #expect(interactor.phase1CompletedSessionCounts(on: historicalDay)[activity.activityId] == 1)
        #expect(interactor.phase1DailyPlan(for: currentDay.adding(days: -1)) == nil)
    }
}
