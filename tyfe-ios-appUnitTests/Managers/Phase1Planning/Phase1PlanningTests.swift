import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct Phase1PlanningTests {

    @Test func storeStartsWithStarterActivityAndNoPlan() {
        let store = Phase1PlanningStore()

        #expect(store.dailyPlan == nil)
        #expect(store.activities.first?.name == "Study Swift")
        #expect(store.rewardCredits == 2)
        #expect(store.progression.totalXP == 40)
    }

    @Test func creatingActivityTrimsNameAndKeepsStableIdentity() {
        let store = Phase1PlanningStore()

        let activity = store.createActivity(
            name: "  Read a chapter  ",
            category: .study,
            colorToken: "teal"
        )

        guard let activity else {
            Issue.record("Expected a trimmed activity to be created")
            return
        }

        #expect(activity.name == "Read a chapter")
        #expect(!activity.id.isEmpty)
        #expect(activity.id.hasPrefix("activity-"))
        #expect(store.activities.contains(where: { $0.id == activity.id }))

        let secondActivity = store.createActivity(
            name: "Plan a walk",
            category: .personal,
            colorToken: "teal"
        )
        #expect(secondActivity?.id != activity.id)
    }

    @Test func acceptingPlanCanOmitTimeBlocks() {
        let store = Phase1PlanningStore()
        let activityId = ActivityModel.mock.activityId

        let plan = store.acceptDailyPlan(
            intendedSessionCount: 3,
            activityIds: [activityId],
            timeBlocks: nil
        )

        #expect(plan.intendedSessionCount == 3)
        #expect(plan.activityIds == [activityId])
        #expect(plan.timeBlocks == nil)
        #expect(store.dailyPlan == plan)
    }

    @Test func acceptingPlanPreservesOptionalFixedDurationTimeline() {
        let store = Phase1PlanningStore()
        let start = Date(timeIntervalSince1970: 1_756_944_000 + 32_400)
        let blocks = [
            PlanTimeBlockModel(
                timeBlockId: "draft-1",
                activityId: ActivityModel.mock.activityId,
                plannedStart: start
            ),
            PlanTimeBlockModel(
                timeBlockId: "draft-2",
                activityId: ActivityModel.mock.activityId,
                plannedStart: start.addingTimeInterval(30 * 60)
            )
        ]

        let plan = store.acceptDailyPlan(
            intendedSessionCount: 2,
            activityIds: [ActivityModel.mock.activityId],
            timeBlocks: blocks
        )

        #expect(plan.timeBlocks?.count == 2)
        #expect(plan.timeBlocks?.allSatisfy { $0.durationMinutes == 25 } == true)
        #expect(plan.timeBlocks?.first?.plannedStart == start)
    }

    @Test func startingPlannedActivityCreatesReadyFocusSession() {
        let store = Phase1PlanningStore()
        let activityId = ActivityModel.mock.activityId
        _ = store.acceptDailyPlan(
            intendedSessionCount: 3,
            activityIds: [activityId],
            timeBlocks: nil
        )

        let session = store.startFocusSession(activityId: activityId)

        #expect(session?.state == .ready)
        #expect(session?.activityId == activityId)
        #expect(session?.isBonusSession == false)
        #expect(session?.durationMinutes == 25)
    }

    @Test func dailyPlanItemsAggregateAndMergeByActivity() {
        let store = Phase1PlanningStore()
        let secondActivity = store.createActivity(
            name: "Plan a walk",
            category: .personal,
            colorToken: "teal"
        )!

        _ = store.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 16
        )
        _ = store.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        #expect(store.dailyPlan?.intendedSessionCount == 17)
        #expect(store.dailyPlan?.planItems.map(\.activityId) == [
            ActivityModel.mock.activityId,
            secondActivity.activityId
        ])
        #expect(store.dailyPlan?.planItems.last?.plannedSessionCount == 1)

        _ = store.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 2
        )

        #expect(store.dailyPlan?.intendedSessionCount == 19)
        #expect(store.dailyPlan?.planItems.first?.plannedSessionCount == 18)
        #expect(store.dailyPlan?.planItems.count == 2)
    }

    @Test func dailyPlanItemCountCannotDropBelowCompletedSessions() {
        let store = Phase1PlanningStore()
        _ = store.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 3
        )
        let session = store.startFocusSession(activityId: ActivityModel.mock.activityId)!
        _ = store.completeFocusSession(focusSessionId: session.focusSessionId)

        _ = store.updateDailyPlanItemCount(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 0
        )

        #expect(store.dailyPlan?.planItems.first?.plannedSessionCount == 1)
        #expect(store.completedSessionCount(for: ActivityModel.mock.activityId) == 1)
    }

    @Test func emptyActivityCanBeRemovedButCompletedActivityRemains() {
        let store = Phase1PlanningStore()
        let secondActivity = store.createActivity(
            name: "Plan a walk",
            category: .personal,
            colorToken: "teal"
        )!
        _ = store.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 3
        )
        _ = store.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        _ = store.removeActivityFromDailyPlan(activityId: secondActivity.activityId)
        #expect(store.dailyPlan?.planItems.map(\.activityId) == [ActivityModel.mock.activityId])

        let session = store.startFocusSession(activityId: ActivityModel.mock.activityId)!
        _ = store.completeFocusSession(focusSessionId: session.focusSessionId)
        _ = store.removeActivityFromDailyPlan(activityId: ActivityModel.mock.activityId)
        #expect(store.dailyPlan?.planItems.map(\.activityId) == [ActivityModel.mock.activityId])
    }
}
