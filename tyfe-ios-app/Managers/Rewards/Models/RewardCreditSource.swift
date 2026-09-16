import Foundation

enum RewardCreditSource: String, Codable, CaseIterable, Hashable {
    case openingBalance
    case focusSession
    case rewardClaim
    case dayReset
}
