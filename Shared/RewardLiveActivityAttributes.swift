#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct RewardLiveActivityAttributes: ActivityAttributes {
    let rewardClaimId: String
    let rewardTitle: String

    enum Phase: String, Codable, Hashable {
        case active
        case expired
    }

    struct ContentState: Codable, Hashable {
        let phase: Phase
        let startedAt: Date
        let endsAt: Date
    }
}
#endif
