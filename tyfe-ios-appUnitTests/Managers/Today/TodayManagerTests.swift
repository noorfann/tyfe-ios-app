import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayManagerTests {

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func todayManagerStartsWithStarterActivityAndNoPlan() {
        let manager = TodayManager(repository: MockLocalAppRepository())

        #expect(manager.dailyPlan == nil)
        #expect(manager.activities.first?.name == "Study Swift")
        #expect(manager.rewardCredits == 0)
    }

    @Test func creatingActivityTrimsNameAndKeepsStableIdentity() throws {
        let manager = TodayManager(repository: MockLocalAppRepository())

        let activity = try #require(manager.createActivity(
            name: "  Read a chapter  ",
            category: .study,
            colorToken: "teal"
        ))

        #expect(activity.name == "Read a chapter")
        #expect(manager.activities.contains(where: { $0.id == activity.id }))
        #expect(manager.createActivity(name: "Read a chapter", category: .study, colorToken: "teal")?.id == activity.id)
    }

    @Test func planEditingPreservesCompletedSessionMinimum() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)
        let activityId = ActivityModel.mock.activityId

        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 3)
        let session = try #require(focus.startFocusSession(activityId: activityId))
        _ = try focus.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try focus.refreshFocusSession(focusSessionId: session.focusSessionId)

        _ = today.updateDailyPlanItemCount(activityId: activityId, sessionCount: 0)

        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 1)
        #expect(today.dailyPlan?.originalIntendedSessionCount == 3)
        #expect(today.completedSessionCount(for: activityId) == 1)
    }

    @Test func todayProjectionReadsFocusCompletionFromTheSharedRepository() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)
        _ = today.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        let session = try #require(focus.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try focus.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try focus.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(today.completedSessionCount == 1)
        #expect(today.completedSessionCount(for: ActivityModel.mock.activityId) == 1)
        #expect(today.rewardCredits == 1)
    }

    @Test func plansRemainAvailableAcrossLocalDayRollover() throws {
        let clock = TestFocusClock(now: Date(timeIntervalSince1970: 1_756_941_600))
        let calendar = utcCalendar()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let focus = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let activityId = ActivityModel.mock.activityId
        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 1)
        let firstDay = today.currentLocalDay
        clock.advance(by: 86_400)

        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 2)

        #expect(today.dailyPlan(for: firstDay)?.intendedSessionCount == 1)
        #expect(today.dailyPlan?.intendedSessionCount == 2)
        #expect(repository.snapshot.dailyPlans.count == 2)
        #expect(focus.dailyPlan(for: firstDay)?.intendedSessionCount == 1)
    }

    @Test func acceptingTimedPlanSchedulesItsLocalReminders() {
        let clock = TestFocusClock()
        let scheduler = RecordingLocalTimerNotificationScheduler()
        let manager = TodayManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            notificationScheduler: scheduler
        )
        let timeBlock = PlanTimeBlockModel(
            timeBlockId: "time-block-reminder",
            activityId: ActivityModel.mock.activityId,
            plannedStart: clock.now.addingTimeInterval(600)
        )

        let plan = manager.acceptDailyPlan(
            intendedSessionCount: 1,
            activityIds: [ActivityModel.mock.activityId],
            timeBlocks: [timeBlock]
        )

        #expect(scheduler.scheduledPlans == [plan])
    }

    @Test func successfulDayExcludesBonusCompletions() throws {
        let clock = TestFocusClock()
        let calendar = utcCalendar()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let focus = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let activityId = ActivityModel.mock.activityId
        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 1)

        let planned = try #require(focus.startFocusSession(activityId: activityId))
        _ = try focus.beginFocusSession(focusSessionId: planned.focusSessionId)
        clock.advance(by: TimeInterval(planned.durationSeconds))
        _ = try focus.refreshFocusSession(focusSessionId: planned.focusSessionId)

        let bonus = try #require(focus.startFocusSession(activityId: activityId))
        _ = try focus.beginFocusSession(focusSessionId: bonus.focusSessionId)
        clock.advance(by: TimeInterval(bonus.durationSeconds))
        _ = try focus.refreshFocusSession(focusSessionId: bonus.focusSessionId)

        let progress = try #require(today.progress(for: today.currentLocalDay))
        #expect(progress.plannedCompletionCount == 1)
        #expect(progress.bonusCompletionCount == 1)
        #expect(progress.isSuccessful)
    }

    @Test func deckSwipeCoachmarkFlagPersistsThroughUserDefaults() throws {
        let suiteName = "TodayManagerTests.deckCoachmark.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let manager = TodayManager(repository: MockLocalAppRepository(), userDefaults: userDefaults)
        #expect(manager.hasSeenDeckSwipeCoachmark == false)

        manager.markDeckSwipeCoachmarkSeen()

        #expect(manager.hasSeenDeckSwipeCoachmark == true)
        #expect(userDefaults.bool(forKey: "tyfe.today-deck-coachmark-seen") == true)

        let reloaded = TodayManager(repository: MockLocalAppRepository(), userDefaults: userDefaults)
        #expect(reloaded.hasSeenDeckSwipeCoachmark == true)
    }
}
