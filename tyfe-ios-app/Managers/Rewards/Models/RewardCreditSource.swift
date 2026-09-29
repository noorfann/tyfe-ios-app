import Foundation

enum RewardCreditSource: String, Codable, CaseIterable, Hashable {
    case openingBalance
    case focusSession
    case checklistItem
    case rewardClaim
    case dayReset
}
