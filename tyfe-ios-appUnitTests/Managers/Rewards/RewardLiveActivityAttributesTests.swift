#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct RewardLiveActivityAttributesTests {
    @Test func attributesRoundTripRewardTitle() throws {
        let attributes = RewardLiveActivityAttributes(
            rewardClaimId: "reward-claim-1",
            rewardTitle: "Watch an episode"
        )

        let data = try JSONEncoder().encode(attributes)
        let decoded = try JSONDecoder().decode(RewardLiveActivityAttributes.self, from: data)

        #expect(decoded.rewardClaimId == attributes.rewardClaimId)
        #expect(decoded.rewardTitle == "Watch an episode")
    }

    @Test func contentStateUsesDefaultCodableWireShapeBelowActivityKitLimit() throws {
        let state = RewardLiveActivityAttributes.ContentState(
            phase: .active,
            startedAt: Date(timeIntervalSince1970: 1_757_000_000),
            endsAt: Date(timeIntervalSince1970: 1_757_000_600)
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            RewardLiveActivityAttributes.ContentState.self,
            from: data
        )

        #expect(decoded == state)
        #expect(data.count < 4_096)
    }
}
#endif
