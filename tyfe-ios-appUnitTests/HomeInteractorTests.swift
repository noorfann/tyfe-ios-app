import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct HomeInteractorTests {

    @Test func dashboardReadsLivePlanProgressAndCredits() throws {
        let interactor = makeInteractor()
        let activityId = ActivityModel.mock.activityId

        _ = interactor.todayManager.addActivityToDailyPlan(
            activityId: activityId,
            sessionCount: 2
        )

        let state = interactor.dashboardState

        #expect(state.nextActivity?.activityId == activityId)
        #expect(state.plannedSessionCount == 2)
        #expect(state.completedSessionCount == 0)
        #expect(state.rewardCredits == 0)
        #expect(state.activeFocusSession == nil)
        #expect(state.activeFocusActivity == nil)
    }

    @Test func emptyPlanDoesNotStartFocus() {
        let interactor = makeInteractor()

        #expect(interactor.dashboardState.nextActivity == nil)
        #expect(interactor.dashboardState.plannedSessionCount == 0)
        #expect(interactor.startFocusFromHome() == nil)
    }

    @Test func archivedSpaceIsExcludedFromDashboardAndNewFocus() throws {
        let interactor = makeInteractor()
        let activity = try #require(interactor.todayManager.activities.first)
        let project = try #require(interactor.todayManager.createProject(name: "Writing"))
        #expect(interactor.todayManager.assignActivity(activityId: activity.activityId, to: project.projectId))
        _ = interactor.todayManager.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 2)
        #expect(interactor.todayManager.setProjectArchived(projectId: project.projectId, isArchived: true))

        #expect(interactor.dashboardState.plannedSessionCount == 0)
        #expect(interactor.dashboardState.completedSessionCount == 0)
        #expect(interactor.dashboardState.nextActivity == nil)
        #expect(interactor.startFocusFromHome() == nil)
        #expect(interactor.focusManager.startFocusSession(activityId: activity.activityId) == nil)

        #expect(interactor.todayManager.setProjectArchived(projectId: project.projectId, isArchived: false))
        #expect(interactor.dashboardState.plannedSessionCount == 2)
        #expect(interactor.dashboardState.nextActivity?.activityId == activity.activityId)
    }

    @Test func homeStartsAndReusesTheSameActiveSession() throws {
        let interactor = makeInteractor()
        let activityId = ActivityModel.mock.activityId
        _ = interactor.todayManager.addActivityToDailyPlan(
            activityId: activityId,
            sessionCount: 2
        )

        let firstSession = try #require(interactor.startFocusFromHome())
        let secondSession = try #require(interactor.startFocusFromHome())

        #expect(firstSession.focusSessionId == secondSession.focusSessionId)
        #expect(interactor.focusManager.focusSessions.count == 1)
        #expect(interactor.dashboardState.activeFocusSession?.focusSessionId == firstSession.focusSessionId)
        #expect(interactor.dashboardState.activeFocusActivity?.activityId == activityId)
    }

    @Test func runningFocusRemainsResumableAfterArchivingItsSpace() throws {
        let interactor = makeInteractor()
        let activity = try #require(interactor.todayManager.activities.first)
        let project = try #require(interactor.todayManager.createProject(name: "Writing"))
        #expect(interactor.todayManager.assignActivity(activityId: activity.activityId, to: project.projectId))
        _ = interactor.todayManager.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)
        let session = try #require(interactor.startFocusFromHome())

        #expect(interactor.todayManager.setProjectArchived(projectId: project.projectId, isArchived: true))
        #expect(interactor.dashboardState.nextActivity == nil)
        #expect(interactor.dashboardState.activeFocusSession?.focusSessionId == session.focusSessionId)
        #expect(interactor.startFocusFromHome()?.focusSessionId == session.focusSessionId)
    }

#if MOCK
    @Test func activeRewardBlocksStartingFocusFromHome() throws {
        let interactor = makeInteractor()
        let activityId = ActivityModel.mock.activityId
        _ = interactor.todayManager.addActivityToDailyPlan(
            activityId: activityId,
            sessionCount: 2
        )

        let session = try #require(interactor.focusManager.startFocusSession(activityId: activityId))
        _ = try interactor.focusManager.markFocusSessionCompleteForTesting(
            focusSessionId: session.focusSessionId
        )
        let claim = try interactor.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )
        _ = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(interactor.isRewardInProgress)
        #expect(interactor.startFocusFromHome() == nil)
    }
#endif

    private func makeInteractor() -> CoreInteractor {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        return CoreInteractor(container: dependencies.container)
    }
}
