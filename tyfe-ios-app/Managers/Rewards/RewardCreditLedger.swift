import Foundation

enum RewardCreditLedgerError: Error, Equatable {
    case insufficientCredits
}

struct RewardCreditLedger: Codable, Hashable {
    private(set) var entries: [RewardCreditLedgerEntry]

    init(entries: [RewardCreditLedgerEntry] = []) {
        self.entries = entries
    }

    var balance: Int {
        entries.reduce(0) { total, entry in total + entry.amount }
    }

    mutating func apply(_ entry: RewardCreditLedgerEntry) throws {
        guard !entries.contains(where: { $0.idempotencyKey == entry.idempotencyKey }) else {
            return
        }
        guard balance + entry.amount >= 0 else {
            throw RewardCreditLedgerError.insufficientCredits
        }
        entries.append(entry)
    }

    static func openingBalance(amount: Int) -> RewardCreditLedger {
        RewardCreditLedger(entries: [
            RewardCreditLedgerEntry(
                ledgerEntryId: "opening-balance",
                source: .openingBalance,
                sourceId: "",
                amount: amount,
                recordedAt: Date(timeIntervalSince1970: 0),
                idempotencyKey: "opening-balance"
            )
        ])
    }
}
