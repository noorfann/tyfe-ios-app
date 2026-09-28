import Foundation

@MainActor
final class MockRewardLiveActivityScheduler: RewardLiveActivityScheduling {
    private(set) var startedClaims: [RewardClaimModel] = []
    private(set) var startedRewardTitles: [String] = []
    private(set) var endedClaims: [(claim: RewardClaimModel, reason: RewardLiveActivityEndReason)] = []
    private(set) var reconciledClaims: [RewardClaimModel?] = []
    private(set) var reconciledRewardTitles: [String?] = []

    func start(for claim: RewardClaimModel, rewardTitle: String) {
        startedClaims.append(claim)
        startedRewardTitles.append(rewardTitle)
    }

    func end(for claim: RewardClaimModel, reason: RewardLiveActivityEndReason) {
        endedClaims.append((claim, reason))
    }

    func reconcile(activeClaim: RewardClaimModel?, rewardTitle: String?) {
        reconciledClaims.append(activeClaim)
        reconciledRewardTitles.append(rewardTitle)
    }
}
