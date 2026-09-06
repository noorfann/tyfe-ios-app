import Foundation

enum RewardKind: String, Codable, CaseIterable, Hashable {
    case starter
    case custom
}

enum RewardDurationTier: String, Codable, CaseIterable, Hashable {
    case fifteenMinutes
    case thirtyMinutes
    case sixtyMinutes

    var durationMinutes: Int {
        switch self {
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .sixtyMinutes: return 60
        }
    }

    var creditCost: Int {
        switch self {
        case .fifteenMinutes: return 1
        case .thirtyMinutes: return 2
        case .sixtyMinutes: return 4
        }
    }

    var displayName: String {
        "\(durationMinutes) minutes"
    }
}

enum RewardAvailability: String, Codable, CaseIterable, Hashable {
    case available
    case insufficientBalance
    case unavailable

    var displayName: String {
        switch self {
        case .available: return "Available"
        case .insufficientBalance: return "Insufficient balance"
        case .unavailable: return "Unavailable"
        }
    }
}

struct RewardModel: Identifiable, Codable, Hashable {
    let rewardId: String
    let name: String
    let kind: RewardKind
    let durationTier: RewardDurationTier
    let availability: RewardAvailability

    var id: String {
        rewardId
    }

    var eventParameters: [String: Any] {
        [
            "reward_id": rewardId,
            "reward_name": name,
            "reward_kind": kind.rawValue,
            "reward_duration_tier": durationTier.rawValue,
            "reward_credit_cost": durationTier.creditCost,
            "reward_availability": availability.rawValue
        ]
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            RewardModel(
                rewardId: "reward-game-15",
                name: "Play a game",
                kind: .starter,
                durationTier: .fifteenMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-episode-30",
                name: "Watch an episode",
                kind: .starter,
                durationTier: .thirtyMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-social-60",
                name: "Scroll social media",
                kind: .starter,
                durationTier: .sixtyMinutes,
                availability: .insufficientBalance
            ),
            RewardModel(
                rewardId: "reward-custom-reading",
                name: "Read for a while",
                kind: .custom,
                durationTier: .fifteenMinutes,
                availability: .unavailable
            )
        ]
    }
}
