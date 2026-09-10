import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct RewardsInteractorTests {

    @Test func rewardsExposeStarterCatalogAndSeedBalance() {
        let interactor = makeInteractor()

        #expect(interactor.rewardCredits == 2)
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

    @Test func claimingARewardDeductsImmediately() throws {
        let interactor = makeInteractor()

        let claim = try interactor.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )

        #expect(claim.state == .ready)
        #expect(interactor.rewardCredits == 1)
        #expect(interactor.activeRewardClaim?.rewardClaimId == claim.rewardClaimId)
    }

    private func makeInteractor() -> CoreInteractor {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        return CoreInteractor(container: dependencies.container)
    }
}
