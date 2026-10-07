import Foundation

enum RewardCreditSource: String, Codable, CaseIterable, Hashable {
    case openingBalance
    case focusSession
    case checklistItem
    case todoTask
    case habitOccurrence
    case rewardClaim
    case dayReset
}
