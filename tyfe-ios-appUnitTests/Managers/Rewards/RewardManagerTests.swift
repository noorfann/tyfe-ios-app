import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct RewardManagerTests {

    private func makeManager(
        repository: LocalAppRepository? = nil,
        clock: FocusClock? = nil,
        scheduler: LocalTimerNotificationScheduling? = nil
    ) -> RewardManager {
        RewardManager(
            repository: repository ?? MockLocalAppRepository(),
            clock: clock ?? TestFocusClock(),
            notificationScheduler: scheduler
        )
    }

    @Test func starterCatalogIncludesGamesEpisodesAndSocial() {
        let manager = makeManager()
        let starters = manager.rewards.filter { $0.kind == .starter }

        #expect(starters.map(\.name) == ["Play a game", "Watch an episode", "Scroll social media"])
        #expect(starters.map(\.durationTier) == [.sixtyMinutes, .thirtyMinutes, .fifteenMinutes])
    }

    @Test func customRewardTrimsNameAndKeepsOneTier() throws {
        let manager = makeManager()

        let reward = try #require(
            manager.createCustomReward(name: "  Read a book  ", durationTier: .thirtyMinutes)
        )

        #expect(reward.name == "Read a book")
        #expect(reward.kind == .custom)
        #expect(reward.durationTier == .thirtyMinutes)
    }

    @Test func customRewardRejectsBlankName() {
        let manager = makeManager()

        #expect(manager.createCustomReward(name: "   ", durationTier: .fifteenMinutes) == nil)
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
            first.createCustomReward(name: "Practice guitar", durationTier: .sixtyMinutes)
        )

        let relaunched = RewardManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: TestFocusClock()
        )
        let persisted = try #require(relaunched.rewards.first { $0.rewardId == created.rewardId })

        #expect(persisted.name == "Practice guitar")
        #expect(persisted.durationTier == .sixtyMinutes)
    }

    @Test func availabilityReflectsBalanceAndLiveClaim() throws {
        let manager = makeManager()
        let game = try #require(manager.rewards.first { $0.rewardId == "reward-starter-game" })
        let social = try #require(manager.rewards.first { $0.rewardId == "reward-starter-social" })

        #expect(manager.availability(for: social) == .available)
        #expect(manager.availability(for: game) == .insufficientBalance)

        _ = try manager.createRewardClaim(rewardId: social.rewardId, durationTier: .fifteenMinutes)

        #expect(manager.availability(for: social) == .unavailable)
    }

    @Test func createClaimDeductsCreditsImmediately() throws {
        let repository = MockLocalAppRepository()
        let manager = makeManager(repository: repository)

        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
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
                durationTier: .sixtyMinutes
            )
        }

        #expect(manager.rewardCredits == 2)
        #expect(manager.rewardClaims.isEmpty)
        #expect(repository.snapshot.creditLedger.entries.count == 1)
    }

    @Test func secondLiveClaimIsRejected() throws {
        let manager = makeManager()
        _ = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )

        #expect(throws: RewardManagerError.activeClaimExists) {
            try manager.createRewardClaim(
                rewardId: "reward-starter-social",
                durationTier: .fifteenMinutes
            )
        }
    }

    @Test func startClaimTransitionsReadyToActiveWithScheduledEnd() throws {
        let clock = TestFocusClock()
        let manager = makeManager(clock: clock)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )

        let active = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        #expect(active.state == .active)
        #expect(active.startsAt == clock.now)
        #expect(active.endsAt == clock.now.addingTimeInterval(900))
    }

    @Test func readyClaimWaitsUntilStarted() throws {
        let manager = makeManager()

        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )

        #expect(claim.startsAt == nil)
        #expect(claim.endsAt == nil)
        #expect(manager.activeRewardClaim?.state == .ready)
    }

    @Test func refreshExpiresOverdueClaimWithoutRefund() throws {
        let clock = TestFocusClock()
        let manager = makeManager(clock: clock)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )
        _ = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)
        let balanceAfterClaim = manager.rewardCredits

        clock.advance(by: 900)
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
            durationTier: .fifteenMinutes
        )
        _ = try manager.startRewardClaim(rewardClaimId: first.rewardClaimId)
        clock.advance(by: 900)
        _ = try manager.refreshRewardClaim()

        let second = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
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
            repository: LocalFileRepository(persistence: persistence),
            clock: TestFocusClock()
        )
        let claim = try first.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
        )

        let relaunched = RewardManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: TestFocusClock()
        )

        #expect(relaunched.activeRewardClaim?.rewardClaimId == claim.rewardClaimId)
        #expect(relaunched.rewardCredits == 1)
    }

    @Test func startingClaimSchedulesExpiryNotification() throws {
        let scheduler = RecordingLocalTimerNotificationScheduler()
        let manager = makeManager(scheduler: scheduler)
        let claim = try manager.createRewardClaim(
            rewardId: "reward-starter-social",
            durationTier: .fifteenMinutes
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
            durationTier: .fifteenMinutes
        )
        _ = try manager.startRewardClaim(rewardClaimId: claim.rewardClaimId)

        clock.advance(by: 900)
        _ = try manager.refreshRewardClaim()

        #expect(scheduler.cancelledRewardClaimIds == [claim.rewardClaimId])
    }
}
