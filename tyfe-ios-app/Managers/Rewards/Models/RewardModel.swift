import Foundation

enum RewardKind: String, Codable, CaseIterable, Hashable {
    case starter
    case custom
}

enum RewardDurationTier: String, Codable, CaseIterable, Hashable {
    case tenMinutes
    case twentyMinutes
    case thirtyMinutes
    case fortyMinutes
    case fiftyMinutes
    case sixtyMinutes

    /// One Reward Credit buys ten minutes of downtime.
    static let creditMinutes = 10

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "tenMinutes", "fifteenMinutes":
            self = .tenMinutes
        case "twentyMinutes":
            self = .twentyMinutes
        case "thirtyMinutes":
            self = .thirtyMinutes
        case "fortyMinutes":
            self = .fortyMinutes
        case "fiftyMinutes":
            self = .fiftyMinutes
        case "sixtyMinutes":
            self = .sixtyMinutes
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
        switch self {
        case .tenMinutes: return 10
        case .twentyMinutes: return 20
        case .thirtyMinutes: return 30
        case .fortyMinutes: return 40
        case .fiftyMinutes: return 50
        case .sixtyMinutes: return 60
        }
    }

    var creditCost: Int {
        durationMinutes / Self.creditMinutes
    }

    var displayName: String {
        "\(durationMinutes) minutes"
    }

    var creditLabel: String {
        creditCost == 1 ? "1 Credit" : "\(creditCost) Credits"
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
                rewardId: "reward-starter-social",
                name: "Scroll social media",
                kind: .starter,
                durationTier: .tenMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-starter-episode",
                name: "Watch an episode",
                kind: .starter,
                durationTier: .thirtyMinutes,
                availability: .available
            ),
            RewardModel(
                rewardId: "reward-starter-game",
                name: "Play a game",
                kind: .starter,
                durationTier: .sixtyMinutes,
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
                rewardId: "reward-social-10",
                name: "Scroll social media",
                kind: .starter,
                durationTier: .tenMinutes,
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
                rewardId: "reward-game-60",
                name: "Play a game",
                kind: .starter,
                durationTier: .sixtyMinutes,
                availability: .insufficientBalance
            ),
            RewardModel(
                rewardId: "reward-custom-reading",
                name: "Read for a while",
                kind: .custom,
                durationTier: .twentyMinutes,
                availability: .unavailable
            )
        ]
    }
}
