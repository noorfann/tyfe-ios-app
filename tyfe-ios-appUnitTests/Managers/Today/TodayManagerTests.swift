import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayManagerTests {

    @Test func todayManagerStartsWithStarterActivityAndNoPlan() {
        let manager = TodayManager(repository: MockFocusRepository())

        #expect(manager.dailyPlan == nil)
        #expect(manager.activities.first?.name == "Study Swift")
        #expect(manager.rewardCredits == 2)
        #expect(manager.progression.totalXP == 40)
    }

    @Test func creatingActivityTrimsNameAndKeepsStableIdentity() throws {
        let manager = TodayManager(repository: MockFocusRepository())

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
        let repository = MockFocusRepository()
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
        #expect(today.completedSessionCount(for: activityId) == 1)
    }

    @Test func todayProjectionReadsFocusCompletionFromTheSharedRepository() throws {
        let clock = TestFocusClock()
        let repository = MockFocusRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)
        let session = try #require(focus.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try focus.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try focus.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(today.completedSessionCount == 1)
        #expect(today.completedSessionCount(for: ActivityModel.mock.activityId) == 1)
        #expect(today.rewardCredits == 3)
        #expect(today.progression.totalXP == 50)
    }
}
