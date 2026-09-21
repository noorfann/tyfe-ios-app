import Foundation
import Observation
import Testing
@testable import tyfe_ios_app

@MainActor
struct RewardManagerTests {

    private static var seededSnapshot: LocalAppSnapshot {
        var snapshot = LocalAppSnapshot.mock
        snapshot.creditLedger = .openingBalance(amount: 2, recordedAt: TestFocusClock().now)
        return snapshot
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeManager(
        repository: LocalAppRepository? = nil,
        clock: FocusClock? = nil,
        scheduler: LocalTimerNotificationScheduling? = nil
    ) -> RewardManager {
        RewardManager(
            repository: repository ?? MockLocalAppRepository(snapshot: Self.seededSnapshot),
            clock: clock ?? TestFocusClock(),
            calendar: utcCalendar(),
            notificationScheduler: scheduler
        )
    }

    @Test func starterCatalogIncludesGamesEpisodesAndSocial() {
        let manager = makeManager()
        let starters = manager.rewards.filter { $0.kind == .starter }

        #expect(Set(starters.map(\.name)) == Set(["Scroll social media", "Watch an episode", "Play a game"]))
        #expect(starters.allSatisfy {
            $0.durationTier == .tenMinutes && $0.durationTier.creditCost == 1
        })
    }

    @Test func customRewardTrimsNameAndKeepsOneTier() throws {
        let manager = makeManager()

        let reward = try #require(
            manager.createCustomReward(name: "  Read a book  ", durationTier: .tenMinutes)
        )

        #expect(reward.name == "Read a book")
        #expect(reward.kind == .custom)
        #expect(reward.durationTier == .tenMinutes)
    }

    @Test func customRewardRejectsBlankName() {
        let manager = makeManager()

        #expect(manager.createCustomReward(name: "   ", durationTier: .tenMinutes) == nil)
        #expect(manager.rewards.allSatisfy { $0.kind == .starter })
    }

    @Test func customRewardPersistsAcrossRecreation() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-rewards-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let persistence = LocalFileRepositoryPersistence(fileURL: fileURL)

        let first = RewardManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: TestFocusClock()
        )
        let created = try #require(
            first.createCustomReward(name: "Practice guitar", durationTier: .tenMinutes)
        )

        let relaunched = RewardManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: TestFocusClock()
        )
        let persisted = try #require(relaunched.rewards.first { $0.rewardId == created.rewardId })

        #expect(persisted.name == "Practice guitar")
        #expect(persisted.durationTier == .tenMinutes)
    }

    @Test func availabilityReflectsBalanceAndLiveClaim() throws {
        let manager = makeManager()
        let game = try #require(manager.rewards.first { $0.rewardId == "reward-starter-game" })
        let social = try #require(manager.rewards.first { $0.rewardId == "reward-starter-social" })

        #expect(manager.availability(for: social) == .available)
        #expect(manager.availability(for: game) == .available)

        _ = try manager.createRewardClaim(rewardId: social.rewardId, durationTier: .tenMinutes)

        #expect(manager.availability(for: social) == .unavailable)
    }

    @Test func createClaimDeductsCreditsImmediately() throws {
        let repository = MockLocalAppRepository(snapshot: Self.seededSnapshot)
        let manager = makeManager(repository: repository)

        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        #expect(claim.state == .ready)
        #expect(manager.rewardCredits == 1)
        #expect(repository.snapshot.creditLedger.entries.contains {
            $0.source == .rewardClaim && $0.sourceId == claim.rewardClaimId && $0.amount == -1
        })
    }

    @Test func createClaimWithoutBalanceThrowsAndMutatesNothing() {
        let repository = MockLocalAppRepository()
        let manager = makeManager(repository: repository)

        #expect(throws: RewardManagerError.insufficientCredits) {
            try manager.createRewardClaim(
                rewardId: "reward-starter-game",
                durationTier: .tenMinutes
            )
        }

        #expect(manager.rewardCredits == 0)
        #expect(manager.rewardClaims.isEmpty)
        #expect(repository.snapshot.creditLedger.entries.isEmpty)
    }

    @Test func secondLiveClaimIsRejected() throws {
        let manager = makeManager()
        _ = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        #expect(throws: RewardManagerError.activeClaimExists) {
            try manager.createRewardClaim(
                rewardId: "reward-starter-social",
                durationTier: .tenMinutes
            )
        }
    }

    @Test func startClaimTransitionsReadyToActiveWithScheduledEnd() throws {
        let clock = TestFocusClock()
        let manager = makeManager(clock: clock)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        let active = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(active.state == .active)
        #expect(active.startsAt == clock.now)
        #expect(active.endsAt == clock.now.addingTimeInterval(
            TimeInterval(RewardDurationTier.tenMinutes.durationMinutes * 60)
        ))
    }

    @Test func readyClaimWaitsUntilStarted() throws {
        let manager = makeManager()

        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        #expect(claim.startsAt == nil)
        #expect(claim.endsAt == nil)
        #expect(manager.activeRewardClaim?.state == .ready)
    }

    @Test func rewardClaimChangesInvalidateObservers() throws {
        let manager = makeManager()
        let recorder = ObservationRecorder()

        withObservationTracking {
            _ = manager.activeRewardClaim
        } onChange: {
            recorder.count += 1
        }

        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        #expect(recorder.count == 1)

        withObservationTracking {
            _ = manager.activeRewardClaim
        } onChange: {
            recorder.count += 1
        }

        _ = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(recorder.count == 2)
    }

    @Test func refreshExpiresOverdueClaimWithoutRefund() throws {
        let clock = TestFocusClock()
        let manager = makeManager(clock: clock)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )
        _ = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)
        let balanceAfterClaim = manager.rewardCredits

        clock.advance(by: TimeInterval(RewardDurationTier.tenMinutes.durationMinutes * 60))
        let expired = try manager.refreshRewardClaim()

        #expect(expired?.state == .expired)
        #expect(manager.rewardCredits == balanceAfterClaim)
        #expect(manager.activeRewardClaim == nil)
    }

    @Test func expiredClaimNeedsNewClaimToExtend() throws {
        let clock = TestFocusClock()
        let manager = makeManager(clock: clock)
        let first = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )
        _ = try manager.startRewardClaim(rewardClaimId: first.rewardClaimId)
        clock.advance(by: TimeInterval(RewardDurationTier.tenMinutes.durationMinutes * 60))
        _ = try manager.refreshRewardClaim()

        let second = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        #expect(second.rewardClaimId != first.rewardClaimId)
        #expect(second.state == .ready)
        #expect(manager.rewardCredits == 0)
    }

    @Test func claimSurvivesRepositoryRecreation() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-rewards-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let persistence = LocalFileRepositoryPersistence(fileURL: fileURL)

        let first = RewardManager(
            repository: LocalFileRepository(persistence: persistence, fallback: Self.seededSnapshot),
            clock: TestFocusClock()
        )
        let claim = try first.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )
        _ = try first.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        let relaunched = RewardManager(
            repository: LocalFileRepository(persistence: persistence, fallback: Self.seededSnapshot),
            clock: TestFocusClock()
        )

        #expect(relaunched.activeRewardClaim?.rewardClaimId == claim.rewardClaimId)
        #expect(relaunched.activeRewardClaim?.state == .active)
        #expect(relaunched.rewardCredits == 1)
    }

    @Test func startingClaimSchedulesExpiryNotification() throws {
        let scheduler = RecordingLocalTimerNotificationScheduler()
        let manager = makeManager(scheduler: scheduler)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        _ = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(scheduler.scheduledRewardClaims.map(\.rewardClaimId) == [claim.rewardClaimId])
    }

    @Test func refreshExpiryCancelsNotification() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingLocalTimerNotificationScheduler()
        let manager = makeManager(clock: clock, scheduler: scheduler)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )
        _ = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        clock.advance(by: TimeInterval(RewardDurationTier.tenMinutes.durationMinutes * 60))
        _ = try manager.refreshRewardClaim()

        #expect(scheduler.cancelledRewardClaimIds == [claim.rewardClaimId])
    }

    @Test func synchronizeCreditDayClearsThePreviousDayBalanceOnce() throws {
        var snapshot = LocalAppSnapshot.mock
        snapshot.creditLedger = .openingBalance(
            amount: 2,
            recordedAt: Date(timeIntervalSince1970: 1_756_857_600)
        )
        let repository = MockLocalAppRepository(snapshot: snapshot)
        let manager = makeManager(repository: repository)

        #expect(manager.synchronizeCreditDay())
        #expect(manager.rewardCredits == 0)
        #expect(repository.snapshot.creditLedger.entries.contains {
            $0.source == .dayReset && $0.amount == -2
        })

        #expect(manager.synchronizeCreditDay() == false)
        #expect(repository.snapshot.creditLedger.entries.count == 2)
    }

    @Test func claimCreatedDuringTheDaySurvivesTheNextDayReset() throws {
        let clock = TestFocusClock()
        let manager = makeManager(clock: clock)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        clock.advance(by: 86_400)
        #expect(manager.synchronizeCreditDay())
        #expect(manager.rewardCredits == 0)

        let active = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(active.state == .active)
        #expect(manager.activeRewardClaim?.rewardClaimId == claim.rewardClaimId)
    }

    @Test func claimCannotSpendThePreviousDayBalance() {
        var snapshot = LocalAppSnapshot.mock
        snapshot.creditLedger = .openingBalance(
            amount: 2,
            recordedAt: Date(timeIntervalSince1970: 1_756_857_600)
        )
        let repository = MockLocalAppRepository(snapshot: snapshot)
        let manager = makeManager(repository: repository)

        #expect(throws: RewardManagerError.insufficientCredits) {
            try manager.createRewardClaim(
                rewardId: "reward-starter-social",
                durationTier: .tenMinutes
            )
        }

        #expect(manager.rewardCredits == 0)
        #expect(manager.rewardClaims.isEmpty)
        #expect(repository.snapshot.creditLedger.entries.contains {
            $0.source == .dayReset && $0.amount == -2
        })
    }

    @Test func claimOnANewDaySpendsOnlyTheNewDayCredits() throws {
        var snapshot = LocalAppSnapshot.mock
        snapshot.creditLedger = RewardCreditLedger(entries: [
            creditEntry(id: "previous-day", amount: 2, recordedAt: 1_756_857_600),
            creditEntry(id: "today", amount: 1, recordedAt: 1_756_944_000)
        ])
        let repository = MockLocalAppRepository(snapshot: snapshot)
        let manager = makeManager(repository: repository)

        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .tenMinutes
        )

        #expect(claim.state == .ready)
        #expect(manager.rewardCredits == 0)
        #expect(repository.snapshot.creditLedger.entries.contains {
            $0.source == .dayReset && $0.amount == -2
        })
        #expect(repository.snapshot.creditLedger.entries.contains {
            $0.source == .rewardClaim && $0.amount == -1
        })
    }

    private func creditEntry(
        id: String,
        amount: Int,
        recordedAt timestamp: TimeInterval
    ) -> RewardCreditLedgerEntry {
        RewardCreditLedgerEntry(
            ledgerEntryId: id,
            source: .openingBalance,
            sourceId: "",
            amount: amount,
            recordedAt: Date(timeIntervalSince1970: timestamp),
            idempotencyKey: id
        )
    }
}

private final class ObservationRecorder: @unchecked Sendable {
    var count = 0
}
