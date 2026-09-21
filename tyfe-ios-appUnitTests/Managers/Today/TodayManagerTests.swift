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

    @Test func updatingActivityPreservesIdentityAndAllowsDuplicateNames() throws {
        let manager = TodayManager(repository: MockLocalAppRepository())
        let original = try #require(manager.activities.first)
        let duplicate = try #require(manager.createActivity(
            name: "Shared name",
            category: .study,
            colorToken: "saffron"
        ))

        let updated = try #require(manager.updateActivity(
            activityId: original.activityId,
            name: "  Shared name  ",
            category: .home
        ))

        #expect(updated.activityId == original.activityId)
        #expect(updated.name == duplicate.name)
        #expect(updated.category == .home)
        #expect(updated.iconToken == "house.fill")
        #expect(updated.colorToken == original.colorToken)
        #expect(updated.isArchived == original.isArchived)
        #expect(updated.createdAt == original.createdAt)
        #expect(manager.activities.filter { $0.name == "Shared name" }.count == 2)
    }

    @Test func updatingActivityRejectsBlankNameWithoutChangingActivity() {
        let manager = TodayManager(repository: MockLocalAppRepository())
        let original = manager.activities[0]

        let updated = manager.updateActivity(
            activityId: original.activityId,
            name: "   ",
            category: .work
        )

        #expect(updated == nil)
        #expect(manager.activities[0] == original)
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

    @Test func activityWithCompletedSessionCannotBeRemovedFromToday() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)
        let activityId = ActivityModel.mock.activityId
        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 1)
        let session = try #require(focus.startFocusSession(activityId: activityId))
        _ = try focus.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try focus.refreshFocusSession(focusSessionId: session.focusSessionId)

        _ = today.removeActivityFromDailyPlan(activityId: activityId)

        #expect(today.dailyPlan?.planItems.contains { $0.activityId == activityId } == true)
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
        #expect(today.earliestRecordedLocalDay == firstDay)
    }

    @Test func historyReadsPlansAndCompletionsForRequestedDays() throws {
        let calendar = utcCalendar()
        let currentDay = LocalDay(year: 2026, month: 9, day: 15, timeZoneIdentifier: calendar.timeZone.identifier)
        let planDay = currentDay.adding(days: -2)
        let sessionOnlyDay = currentDay.adding(days: -4)
        let activity = ActivityModel.mock
        let plan = historyPlan(on: planDay, activityId: activity.activityId)
        let plannedSession = completedSession(
            focusSessionId: "focus-session-history-planned",
            localDay: planDay,
            activityId: activity.activityId,
            dailyPlanId: plan.dailyPlanId
        )
        let sessionWithoutPlan = completedSession(
            focusSessionId: "focus-session-history-only",
            localDay: sessionOnlyDay,
            activityId: activity.activityId,
            isBonusSession: true
        )
        let repository = MockLocalAppRepository(snapshot: LocalAppSnapshot(
            activities: [activity],
            dailyPlans: [plan],
            focusSessions: [plannedSession, sessionWithoutPlan],
            nextActivityNumber: 2,
            nextSessionNumber: 3
        ))
        let clock = TestFocusClock(now: currentDay.startDate.addingTimeInterval(43_200))
        let manager = TodayManager(repository: repository, clock: clock, calendar: calendar)

        #expect(manager.currentLocalDay == currentDay)
        #expect(manager.earliestRecordedLocalDay == sessionOnlyDay)
        #expect(manager.dailyPlan(for: planDay) == plan)
        #expect(manager.completedSessionCount(on: planDay) == 1)
        #expect(manager.completedSessionCount(for: activity.activityId, on: planDay) == 1)
        #expect(manager.dailyPlan(for: currentDay.adding(days: -1)) == nil)
        #expect(manager.completedSessionCount(on: sessionOnlyDay) == 1)
    }

    private func historyPlan(on localDay: LocalDay, activityId: String) -> DailyPlanModel {
        DailyPlanModel(
            dailyPlanId: "daily-plan-history",
            localDate: localDay.startDate,
            localDay: localDay,
            intendedSessionCount: 2,
            originalIntendedSessionCount: 2,
            activityIds: [activityId],
            planItems: [
                DailyPlanItemModel(
                    planItemId: "plan-item-history",
                    activityId: activityId,
                    plannedSessionCount: 2
                )
            ]
        )
    }

    private func completedSession(
        focusSessionId: String,
        localDay: LocalDay,
        activityId: String,
        dailyPlanId: String? = nil,
        isBonusSession: Bool = false
    ) -> FocusSessionModel {
        FocusSessionModel(
            focusSessionId: focusSessionId,
            activityId: activityId,
            state: .completed,
            startedAt: localDay.startDate.addingTimeInterval(3_600),
            localDay: localDay,
            dailyPlanIdAtStart: dailyPlanId,
            completedAt: localDay.startDate.addingTimeInterval(5_100),
            isBonusSession: isBonusSession
        )
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
