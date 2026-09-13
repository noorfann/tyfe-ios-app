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
            interactor.createCustomReward(name: "  Practice guitar  ", durationTier: .thirtyMinutes)
        )

        #expect(reward.name == "Practice guitar")
        #expect(interactor.rewards.contains { $0.rewardId == reward.rewardId && $0.kind == .custom })
    }

    @Test func claimingARewardWithoutBalanceIsRejected() {
        let interactor = makeInteractor()

        #expect(throws: RewardManagerError.insufficientCredits) {
            try interactor.createRewardClaim(
                rewardId: "reward-starter-social",
                durationTier: .fifteenMinutes
            )
        }
        #expect(interactor.rewardCredits == 0)
        #expect(interactor.activeRewardClaim == nil)
    }

    @Test func activeRewardBlocksStartingFocusFromToday() throws {
        let interactor = makeInteractor()
        let activityId = ActivityModel.mock.activityId
        let session = try #require(interactor.focusManager.startFocusSession(activityId: activityId))
        _ = try interactor.focusManager.markFocusSessionCompleteForTesting(
            focusSessionId: session.focusSessionId
        )
        let claim = try interactor.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )
        _ = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(interactor.isRewardInProgress)
        #expect(interactor.startPhase1FocusSession(activityId: activityId) == nil)
    }

    private func makeInteractor() -> CoreInteractor {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        return CoreInteractor(container: dependencies.container)
    }
}
