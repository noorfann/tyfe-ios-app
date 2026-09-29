import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayRecurrenceTests {

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func mondayDate() -> Date {
        var calendar = utcCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12)) ?? Date()
    }

    private func makeManager(
        snapshot: LocalAppSnapshot = .mock,
        clock: TestFocusClock
    ) -> TodayManager {
        TodayManager(
            repository: MockLocalAppRepository(snapshot: snapshot),
            clock: clock,
            calendar: utcCalendar()
        )
    }

    @Test func dailyRecurringActivitySeedsTodaysPlanWithRememberedCount() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily, defaultSessionCount: 2)
        )

        #expect(manager.materializeCurrentDay())

        let plan = try #require(manager.dailyPlan)
        #expect(plan.localDay == manager.currentLocalDay)
        #expect(plan.intendedSessionCount == 2)
        #expect(plan.originalIntendedSessionCount == 2)
        let item = try #require(plan.planItems.first { $0.activityId == activity.activityId })
        #expect(item.plannedSessionCount == 2)
        #expect(manager.repository.snapshot.lastMaterializedLocalDay == manager.currentLocalDay)
    }

    @Test func materializationHappensOncePerDaySoRemovalSkipsTodayOnly() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily, defaultSessionCount: 1)
        )
        #expect(manager.materializeCurrentDay())

        _ = manager.removeActivityFromDailyPlan(activityId: activity.activityId)
        #expect(manager.dailyPlan == nil)
        #expect(!manager.materializeCurrentDay())
        #expect(manager.dailyPlan == nil)

        clock.advance(by: 86_400)

        #expect(manager.materializeCurrentDay())
        #expect(
            manager.dailyPlan?.planItems.contains { $0.activityId == activity.activityId } == true
        )
    }

    @Test func weeklyRecurrenceSkipsNonMatchingDays() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Midweek review", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .weekly, weekdays: [3])
        )

        #expect(manager.materializeCurrentDay())
        #expect(manager.dailyPlan == nil)

        clock.advance(by: 2 * 86_400)

        #expect(manager.materializeCurrentDay())
        #expect(manager.dailyPlan?.planItems.first?.activityId == activity.activityId)
    }

    @Test func archivedActivitiesAreNotSeeded() {
        let clock = TestFocusClock(now: mondayDate())
        let snapshot = LocalAppSnapshot(
            activities: [
                ActivityModel(
                    activityId: "activity-active",
                    name: "Active",
                    recurrence: ActivityRecurrenceModel(kind: .daily),
                    createdAt: Date()
                ),
                ActivityModel(
                    activityId: "activity-archived",
                    name: "Archived",
                    recurrence: ActivityRecurrenceModel(kind: .daily),
                    isArchived: true,
                    createdAt: Date()
                )
            ],
            focusSessions: [],
            nextActivityNumber: 3,
            nextSessionNumber: 1
        )
        let manager = makeManager(snapshot: snapshot, clock: clock)

        #expect(manager.materializeCurrentDay())

        #expect(manager.dailyPlan?.planItems.map(\.activityId) == ["activity-active"])
    }

    @Test func materializationMergesMissingRecurringActivityIntoExistingPlan() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let manualActivity = try #require(
            manager.createActivity(name: "Manual task", category: nil, colorToken: nil)
        )
        _ = manager.addActivityToDailyPlan(activityId: manualActivity.activityId, sessionCount: 2)
        let recurringActivity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: recurringActivity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily, defaultSessionCount: 1)
        )

        #expect(manager.materializeCurrentDay())

        #expect(manager.dailyPlan?.planItems.map(\.activityId).sorted() == [
            manualActivity.activityId,
            recurringActivity.activityId
        ].sorted())
        #expect(manager.dailyPlan?.planItems.first {
            $0.activityId == manualActivity.activityId
        }?.plannedSessionCount == 2)
        #expect(manager.dailyPlan?.intendedSessionCount == 3)
    }

    @Test func materializationDoesNotDuplicateAlreadyPlannedActivity() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily, defaultSessionCount: 3)
        )
        _ = manager.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)

        #expect(manager.materializeCurrentDay())

        #expect(manager.dailyPlan?.planItems.count == 1)
        #expect(manager.dailyPlan?.planItems.first?.plannedSessionCount == 1)
    }

    @Test func recurringChecklistSeedsItemTemplateCount() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Reset kitchen", category: nil, colorToken: nil, type: .checklist)
        )
        _ = manager.addChecklistItem(activityId: activity.activityId, title: "Dishes", creditValue: .oneCredit)
        _ = manager.addChecklistItem(activityId: activity.activityId, title: "Counters", creditValue: .oneCredit)
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily, defaultSessionCount: 5)
        )

        #expect(manager.materializeCurrentDay())

        let item = try #require(manager.dailyPlan?.planItems.first)
        #expect(item.unitKind == .checklist)
        #expect(item.plannedSessionCount == 2)
    }

    @Test func recurringChecklistWithoutItemsIsNotSeeded() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Empty list", category: nil, colorToken: nil, type: .checklist)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily)
        )

        #expect(manager.materializeCurrentDay())
        #expect(manager.dailyPlan == nil)
    }

    @Test func updatingRecurrenceLeavesTodaysPlanUntouched() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 2)

        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .weekly, weekdays: [5], defaultSessionCount: 4)
        )

        #expect(manager.dailyPlan?.planItems.count == 1)
        #expect(manager.dailyPlan?.planItems.first?.plannedSessionCount == 2)
        #expect(manager.repository.snapshot.lastMaterializedLocalDay == nil)
    }

    @Test func clearingRecurrenceStopsFutureSeeding() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily)
        )
        #expect(manager.materializeCurrentDay())

        _ = manager.setActivityRecurrence(activityId: activity.activityId, recurrence: nil)

        clock.advance(by: 86_400)
        #expect(manager.materializeCurrentDay())
        #expect(manager.dailyPlan == nil)
    }

    @Test func updateAndConversionPreserveRecurrence() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        let recurrence = ActivityRecurrenceModel(kind: .daily, defaultSessionCount: 3)
        _ = manager.setActivityRecurrence(activityId: activity.activityId, recurrence: recurrence)

        let updated = try #require(
            manager.updateActivity(activityId: activity.activityId, name: "Renamed", category: .home)
        )
        #expect(updated.recurrence == recurrence)

        let converted = try #require(manager.convertActivity(activityId: activity.activityId, to: .checklist))
        #expect(converted.recurrence == recurrence)
    }

    @Test func emptyWeeklySelectionClearsRecurrence() throws {
        let clock = TestFocusClock(now: mondayDate())
        let manager = makeManager(clock: clock)
        let activity = try #require(
            manager.createActivity(name: "Deep work", category: .work, colorToken: nil)
        )
        _ = manager.setActivityRecurrence(
            activityId: activity.activityId,
            recurrence: ActivityRecurrenceModel(kind: .daily)
        )

        let cleared = try #require(
            manager.setActivityRecurrence(
                activityId: activity.activityId,
                recurrence: ActivityRecurrenceModel(kind: .weekly, weekdays: [])
            )
        )

        #expect(cleared.recurrence == nil)
    }
}
