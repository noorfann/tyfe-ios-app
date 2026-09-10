import Foundation
import Observation

@Observable
@MainActor
final class RewardManager {

    private let repository: LocalAppRepository
    private let clock: FocusClock
    private let notificationScheduler: LocalTimerNotificationScheduling?

    init(
        repository: LocalAppRepository = MockLocalAppRepository(),
        clock: FocusClock = SystemFocusClock(),
        notificationScheduler: LocalTimerNotificationScheduling? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.notificationScheduler = notificationScheduler
    }

    var rewards: [RewardModel] {
        (RewardModel.starters + repository.snapshot.customRewards).map { reward in
            RewardModel(
                rewardId: reward.rewardId,
                name: reward.name,
                kind: reward.kind,
                durationTier: reward.durationTier,
                availability: availability(for: reward)
            )
        }
        .sorted { $0.durationTier.durationMinutes < $1.durationTier.durationMinutes }
    }

    var rewardClaims: [RewardClaimModel] {
        repository.snapshot.rewardClaims
    }

    var rewardCredits: Int {
        repository.snapshot.creditLedger.balance
    }

    var activeRewardClaim: RewardClaimModel? {
        rewardClaims.last { $0.state == .ready || $0.state == .active }
    }

    func availability(for reward: RewardModel) -> RewardAvailability {
        if activeRewardClaim != nil {
            return .unavailable
        }
        return repository.snapshot.creditLedger.balance >= reward.durationTier.creditCost
            ? .available
            : .insufficientBalance
    }

    @discardableResult
    func createCustomReward(name: String, durationTier: RewardDurationTier) -> RewardModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let snapshot = repository.snapshot
        let reward = RewardModel(
            rewardId: "reward-custom-" + String(snapshot.nextRewardNumber),
            name: trimmedName,
            kind: .custom,
            durationTier: durationTier,
            availability: .available
        )

        do {
            try repository.transaction { snapshot in
                snapshot.customRewards.append(reward)
                snapshot.nextRewardNumber += 1
            }
            return reward
        } catch {
            return nil
        }
    }

    @discardableResult
    func createRewardClaim(
        rewardId: String,
        durationTier: RewardDurationTier
    ) throws -> RewardClaimModel {
        let snapshot = repository.snapshot
        guard let reward = rewards.first(where: { $0.rewardId == rewardId }) else {
            throw RewardManagerError.rewardNotFound
        }
        guard durationTier == reward.durationTier else {
            throw RewardManagerError.invalidTier
        }
        guard activeRewardClaim == nil else {
            throw RewardManagerError.activeClaimExists
        }
        guard snapshot.creditLedger.balance >= durationTier.creditCost else {
            throw RewardManagerError.insufficientCredits
        }

        let claim = RewardClaimModel(
            rewardClaimId: "reward-claim-" + String(snapshot.nextRewardClaimNumber),
            rewardId: reward.rewardId,
            durationTier: durationTier,
            state: .ready,
            createdAt: clock.now
        )
        let spend = RewardCreditLedgerEntry(
            ledgerEntryId: claim.rewardClaimId + "-spend",
            source: .rewardClaim,
            sourceId: claim.rewardClaimId,
            amount: -durationTier.creditCost,
            recordedAt: clock.now,
            idempotencyKey: claim.rewardClaimId + "-spend"
        )

        do {
            try repository.transaction { snapshot in
                guard !snapshot.rewardClaims.contains(where: {
                    $0.state == .ready || $0.state == .active
                }) else {
                    throw RewardManagerError.activeClaimExists
                }
                try snapshot.creditLedger.apply(spend)
                snapshot.rewardClaims.append(claim)
                snapshot.nextRewardClaimNumber += 1
            }
            return claim
        } catch let error as RewardManagerError {
            throw error
        } catch {
            throw RewardManagerError.persistenceFailed
        }
    }

    @discardableResult
    func startRewardClaim(rewardClaimId: String) throws -> RewardClaimModel {
        guard let claim = rewardClaims.first(where: { $0.rewardClaimId == rewardClaimId }) else {
            throw RewardManagerError.claimNotFound
        }
        guard claim.state == .ready else {
            throw RewardManagerError.invalidClaimState
        }

        let active = RewardClaimModel(
            rewardClaimId: claim.rewardClaimId,
            rewardId: claim.rewardId,
            durationTier: claim.durationTier,
            state: .active,
            createdAt: claim.createdAt,
            startsAt: clock.now,
            endsAt: clock.now.addingTimeInterval(TimeInterval(claim.durationTier.durationMinutes * 60))
        )

        try replace(active)
        notificationScheduler?.scheduleRewardExpiry(for: active)
        return active
    }

    @discardableResult
    func refreshRewardClaim() throws -> RewardClaimModel? {
        guard let claim = activeRewardClaim else {
            return nil
        }
        guard claim.state == .active, let endsAt = claim.endsAt, clock.now >= endsAt else {
            return claim
        }

        let expired = RewardClaimModel(
            rewardClaimId: claim.rewardClaimId,
            rewardId: claim.rewardId,
            durationTier: claim.durationTier,
            state: .expired,
            createdAt: claim.createdAt,
            startsAt: claim.startsAt,
            endsAt: claim.endsAt
        )

        try replace(expired)
        notificationScheduler?.cancelRewardExpiry(rewardClaimId: expired.rewardClaimId)
        return expired
    }

    private func replace(_ claim: RewardClaimModel) throws {
        guard rewardClaims.contains(where: { $0.rewardClaimId == claim.rewardClaimId }) else {
            throw RewardManagerError.claimNotFound
        }
        try repository.transaction { snapshot in
            guard let index = snapshot.rewardClaims.firstIndex(where: {
                $0.rewardClaimId == claim.rewardClaimId
            }) else {
                return
            }
            snapshot.rewardClaims[index] = claim
        }
    }
}

enum RewardManagerError: Error, Equatable {
    case rewardNotFound
    case invalidTier
    case insufficientCredits
    case activeClaimExists
    case claimNotFound
    case invalidClaimState
    case persistenceFailed
}
