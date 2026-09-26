import Foundation

enum RewardClaimState: String, Codable, CaseIterable, Hashable {
    case ready
    case active
    case expired
}

struct RewardClaimModel: Identifiable, Codable, Hashable {
    let rewardClaimId: String
    let rewardId: String
    let durationTier: RewardDurationTier
    let state: RewardClaimState
    let createdAt: Date?
    let startsAt: Date?
    let endsAt: Date?

    var id: String {
        rewardClaimId
    }

    init(
        rewardClaimId: String,
        rewardId: String,
        durationTier: RewardDurationTier,
        state: RewardClaimState,
        createdAt: Date? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil
    ) {
        self.rewardClaimId = rewardClaimId
        self.rewardId = rewardId
        self.durationTier = durationTier
        self.state = state
        self.createdAt = createdAt
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    var eventParameters: [String: Any] {
        [
            "reward_claim_id": rewardClaimId,
            "reward_claim_reward_id": rewardId,
            "reward_claim_duration_tier": durationTier.rawValue,
            "reward_claim_state": state.rawValue,
            "reward_claim_created_at": createdAt as Any,
            "reward_claim_starts_at": startsAt as Any,
            "reward_claim_ends_at": endsAt as Any
        ]
    }

    static var mock: Self {
        Self(
            rewardClaimId: "reward-claim-ready",
            rewardId: RewardModel.mock.rewardId,
            durationTier: RewardModel.mock.durationTier,
            state: .ready,
            createdAt: Date(timeIntervalSince1970: 1_756_944_000)
        )
    }

    static var activeMock: Self {
        let start = Date(timeIntervalSince1970: 1_756_944_000)
        return Self(
            rewardClaimId: "reward-claim-active",
            rewardId: RewardModel.mock.rewardId,
            durationTier: RewardModel.mock.durationTier,
            state: .active,
            createdAt: start,
            startsAt: start,
            endsAt: start.addingTimeInterval(
                TimeInterval(RewardModel.mock.durationTier.durationMinutes * 60)
            )
        )
    }
}
