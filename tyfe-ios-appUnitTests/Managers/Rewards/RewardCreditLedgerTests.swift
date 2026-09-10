import Foundation
import Testing
@testable import tyfe_ios_app

struct RewardCreditLedgerTests {

    @Test func openingBalanceSetsTheDerivedBalance() {
        let ledger = RewardCreditLedger.openingBalance(amount: 2)

        #expect(ledger.balance == 2)
        #expect(ledger.entries.count == 1)
    }

    @Test func applyIgnoresDuplicateIdempotencyKey() throws {
        var ledger = RewardCreditLedger.openingBalance(amount: 2)
        let duplicate = RewardCreditLedgerEntry(
            ledgerEntryId: "duplicate",
            source: .focusSession,
            sourceId: "focus-session-1",
            amount: 5,
            recordedAt: Date(timeIntervalSince1970: 0),
            idempotencyKey: "opening-balance"
        )

        try ledger.apply(duplicate)

        #expect(ledger.balance == 2)
        #expect(ledger.entries.count == 1)
    }

    @Test func applyRejectsSpendBelowZero() {
        var ledger = RewardCreditLedger.openingBalance(amount: 2)
        let overdraft = RewardCreditLedgerEntry(
            ledgerEntryId: "spend-overdraft",
            source: .rewardClaim,
            sourceId: "reward-claim-1",
            amount: -3,
            recordedAt: Date(timeIntervalSince1970: 0),
            idempotencyKey: "spend-overdraft"
        )

        #expect(throws: RewardCreditLedgerError.insufficientCredits) {
            try ledger.apply(overdraft)
        }
        #expect(ledger.balance == 2)
        #expect(ledger.entries.count == 1)
    }

    @Test func applyAcceptsSpendWithinBalance() throws {
        var ledger = RewardCreditLedger.openingBalance(amount: 2)
        let spend = RewardCreditLedgerEntry(
            ledgerEntryId: "spend-2",
            source: .rewardClaim,
            sourceId: "reward-claim-1",
            amount: -2,
            recordedAt: Date(timeIntervalSince1970: 0),
            idempotencyKey: "spend-2"
        )

        try ledger.apply(spend)

        #expect(ledger.balance == 0)
        #expect(ledger.entries.count == 2)
    }
}
