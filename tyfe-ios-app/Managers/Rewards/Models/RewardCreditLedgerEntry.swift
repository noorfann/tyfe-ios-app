import Foundation

struct RewardCreditLedgerEntry: Identifiable, Codable, Hashable {
    let ledgerEntryId: String
    let source: RewardCreditSource
    let sourceId: String
    let amount: Int
    let recordedAt: Date
    let idempotencyKey: String

    var id: String { ledgerEntryId }
}
