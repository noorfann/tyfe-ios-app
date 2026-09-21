import Foundation

enum RewardKind: String, Codable, CaseIterable, Hashable {
    case starter
    case custom
}

enum RewardDurationTier: String, Codable, CaseIterable, Hashable {
    case tenMinutes

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "tenMinutes", "fifteenMinutes", "thirtyMinutes", "sixtyMinutes":
            self = .tenMinutes
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown reward duration tier."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var durationMinutes: Int {
        10
    }

    var creditCost: Int {
        1
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

    static var starters: [Self] {
        [
            RewardModel(
                rewardId: "reward-starter-game",
                name: "Play a game",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-starter-episode",
                name: "Watch an episode",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-starter-social",
                name: "Scroll social media",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .available
            )
        ]
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            RewardModel(
                rewardId: "reward-game-10",
                name: "Play a game",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-episode-10",
                name: "Watch an episode",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-social-10",
                name: "Scroll social media",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .insufficientBalance
            ),
            RewardModel(
                rewardId: "reward-custom-reading",
                name: "Read for a while",
                kind: .custom,
                durationTier: .tenMinutes,
                availability: .unavailable
            )
        ]
    }
}
