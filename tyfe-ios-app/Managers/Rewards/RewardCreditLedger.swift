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

    mutating func startDay(_ localDay: LocalDay, now: Date) {
        let key = Self.dayResetKey(for: localDay)
        guard !entries.contains(where: { $0.idempotencyKey == key }) else {
            return
        }
        let previousDayBalance = priorDayBalance(for: localDay)
        guard previousDayBalance != 0 else {
            return
        }
        entries.append(
            RewardCreditLedgerEntry(
                ledgerEntryId: key,
                source: .dayReset,
                sourceId: localDay.id,
                amount: -previousDayBalance,
                recordedAt: now,
                idempotencyKey: key
            )
        )
    }

    func priorDayBalance(for localDay: LocalDay) -> Int {
        entries
            .filter { $0.recordedAt < localDay.startDate }
            .reduce(0) { $0 + $1.amount }
    }

    static func dayResetKey(for localDay: LocalDay) -> String {
        "credit-day-reset-" + localDay.id
    }

    static func openingBalance(amount: Int, recordedAt: Date = Date(timeIntervalSince1970: 0)) -> RewardCreditLedger {
        RewardCreditLedger(entries: [
            RewardCreditLedgerEntry(
                ledgerEntryId: "opening-balance",
                source: .openingBalance,
                sourceId: "",
                amount: amount,
                recordedAt: recordedAt,
                idempotencyKey: "opening-balance"
            )
        ])
    }
}
