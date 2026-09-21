import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct RewardsInteractorTests {

    @Test func rewardsExposeStarterCatalogStartingFromZeroBalance() {
        let interactor = makeInteractor()

        #expect(interactor.rewardCredits == 0)
        #expect(interactor.rewards.contains { $0.rewardId == "reward-starter-game" })
        #expect(interactor.activeRewardClaim == nil)
    }

    @Test func creatingACustomRewardPersistsIt() throws {
        let interactor = makeInteractor()

        let reward = try #require(
            interactor.createCustomReward(name: "  Practice guitar  ", durationTier: .tenMinutes)
        )

        #expect(reward.name == "Practice guitar")
        #expect(interactor.rewards.contains { $0.rewardId == reward.rewardId && $0.kind == .custom })
    }

    @Test func claimingARewardWithoutBalanceIsRejected() {
        let interactor = makeInteractor()

        #expect(throws: RewardManagerError.insufficientCredits) {
            try interactor.createRewardClaim(
                rewardId: "reward-starter-social",
                durationTier: .tenMinutes
            )
        }
        #expect(interactor.rewardCredits == 0)
        #expect(interactor.activeRewardClaim == nil)
    }

#if MOCK
    @Test func activeRewardBlocksStartingFocusFromToday() throws {
        let interactor = makeInteractor()
        let activityId = ActivityModel.mock.activityId
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
        #expect(interactor.startPhase1FocusSession(activityId: activityId) == nil)
    }

    @Test func readyFocusSessionBlocksCreatingARewardClaim() throws {
        let interactor = makeInteractor()
        let session = try #require(
            interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try interactor.focusManager.markFocusSessionCompleteForTesting(
            focusSessionId: session.focusSessionId
        )
        let liveSession = try #require(
            interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )

        #expect(liveSession.state == .ready)
        #expect(interactor.hasLiveFocusSession)
        #expect(throws: RewardManagerError.focusSessionInProgress) {
            try interactor.createRewardClaim(
                rewardId: "reward-starter-social",
                durationTier: .tenMinutes
            )
        }
    }

    @Test func runningFocusSessionBlocksStartingASavedRewardClaim() throws {
        let interactor = makeInteractor()
        let earningSession = try #require(
            interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try interactor.focusManager.markFocusSessionCompleteForTesting(
            focusSessionId: earningSession.focusSessionId
        )
        #expect(!interactor.hasLiveFocusSession)
        let claim = try interactor.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )
        let focusSession = try #require(
            interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try interactor.focusManager.beginFocusSession(focusSessionId: focusSession.focusSessionId)

        #expect(throws: RewardManagerError.focusSessionInProgress) {
            try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)
        }

        _ = try interactor.focusManager.abandonFocusSession(focusSessionId: focusSession.focusSessionId)
        #expect(!interactor.hasLiveFocusSession)
        let activeClaim = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)
        #expect(activeClaim.state == .active)
        #expect(interactor.activeRewardClaim?.state == .active)
    }
#endif

    private func makeInteractor() -> CoreInteractor {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        return CoreInteractor(container: dependencies.container)
    }
}
