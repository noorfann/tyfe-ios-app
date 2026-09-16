import Foundation
import Testing
@testable import tyfe_ios_app

struct RewardCreditLedgerTests {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func localDay(at timestamp: TimeInterval) -> LocalDay {
        LocalDay(containing: Date(timeIntervalSince1970: timestamp), calendar: utcCalendar)
    }

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

    @Test func startDayDoesNotCarryCreditsIntoTheNewDay() {
        let yesterday = localDay(at: 1_756_857_600)
        let today = localDay(at: 1_756_944_000)
        var ledger = RewardCreditLedger.openingBalance(amount: 2, recordedAt: yesterday.startDate)

        ledger.startDay(today, now: today.startDate)

        #expect(ledger.balance == 0)
        #expect(ledger.entries.filter { $0.source == .dayReset }.count == 1)
        #expect(ledger.entries.last?.amount == -2)
        #expect(ledger.entries.last?.sourceId == today.id)
    }

    @Test func startDayIsIdempotentForTheSameDay() {
        let yesterday = localDay(at: 1_756_857_600)
        let today = localDay(at: 1_756_944_000)
        var ledger = RewardCreditLedger.openingBalance(amount: 2, recordedAt: yesterday.startDate)

        ledger.startDay(today, now: today.startDate)
        ledger.startDay(today, now: today.startDate)

        #expect(ledger.balance == 0)
        #expect(ledger.entries.count == 2)
        #expect(ledger.entries.filter { $0.source == .dayReset }.count == 1)
    }

    @Test func startDayKeepsCreditsRecordedEarlierTheSameDay() {
        let today = localDay(at: 1_756_944_000)
        var ledger = RewardCreditLedger.openingBalance(amount: 2, recordedAt: today.startDate)

        ledger.startDay(today, now: today.startDate.addingTimeInterval(8 * 3_600))

        #expect(ledger.balance == 2)
        #expect(ledger.entries.count == 1)
    }

    @Test func startDayLeavesAZeroBalanceUntouched() {
        let today = localDay(at: 1_756_944_000)
        var ledger = RewardCreditLedger()

        ledger.startDay(today, now: today.startDate)

        #expect(ledger.entries.isEmpty)
        #expect(ledger.balance == 0)
    }

    @Test func applyAfterStartDayUsesOnlyTheNewDayCredits() throws {
        let yesterday = localDay(at: 1_756_857_600)
        let today = localDay(at: 1_756_944_000)
        var ledger = RewardCreditLedger.openingBalance(amount: 2, recordedAt: yesterday.startDate)

        ledger.startDay(today, now: today.startDate)
        try ledger.apply(
            RewardCreditLedgerEntry(
                ledgerEntryId: "credit-focus-session-1",
                source: .focusSession,
                sourceId: "focus-session-1",
                amount: 1,
                recordedAt: today.startDate,
                idempotencyKey: "focus-session-1-credit"
            )
        )

        #expect(ledger.balance == 1)
    }
}
