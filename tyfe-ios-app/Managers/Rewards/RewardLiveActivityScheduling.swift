import Foundation

enum RewardLiveActivityEndReason: Equatable {
    case expired
}

@MainActor
protocol RewardLiveActivityScheduling: AnyObject {
    func start(for claim: RewardClaimModel, rewardTitle: String)
    func end(for claim: RewardClaimModel, reason: RewardLiveActivityEndReason)
    func reconcile(activeClaim: RewardClaimModel?, rewardTitle: String?)
}
