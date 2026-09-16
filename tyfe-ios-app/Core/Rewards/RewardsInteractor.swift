import SwiftUI

@MainActor
protocol RewardsInteractor: GlobalInteractor {
    var rewards: [RewardModel] { get }
    var rewardCredits: Int { get }
    var activeRewardClaim: RewardClaimModel? { get }
    var rewardClaims: [RewardClaimModel] { get }
    var hasLiveFocusSession: Bool { get }

    @discardableResult
    func createCustomReward(name: String, durationTier: RewardDurationTier) -> RewardModel?

    @discardableResult
    func createRewardClaim(
        rewardId: String,
        durationTier: RewardDurationTier
    ) throws -> RewardClaimModel

    @discardableResult
    func startRewardClaim(rewardClaimId: String) throws -> RewardClaimModel

    @discardableResult
    func refreshRewardClaim() throws -> RewardClaimModel?

    func synchronizeRewardCreditDay()
}

extension CoreInteractor: RewardsInteractor { }
