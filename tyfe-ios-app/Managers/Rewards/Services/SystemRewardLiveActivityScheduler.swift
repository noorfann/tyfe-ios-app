import Foundation

#if os(iOS) && canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

@MainActor
final class SystemRewardLiveActivityScheduler: RewardLiveActivityScheduling {

#if os(iOS) && canImport(ActivityKit)
    private let userDefaults: UserDefaults
    private let dismissedClaimIdsKey = "tyfe.reward-live-activity.dismissed-claim-ids"
    private var dismissedClaimIds: Set<String>
    private var stateTasks: [String: Task<Void, Never>] = [:]
#endif

    init(userDefaults: UserDefaults = .standard) {
#if os(iOS) && canImport(ActivityKit)
        self.userDefaults = userDefaults
        self.dismissedClaimIds = Set(
            userDefaults.stringArray(forKey: dismissedClaimIdsKey) ?? []
        )
#else
        _ = userDefaults
#endif
    }

    func start(for claim: RewardClaimModel, rewardTitle: String) {
#if os(iOS) && canImport(ActivityKit)
        let existingActivities = activities(for: claim.rewardClaimId)
        endImmediately(Array(existingActivities.dropFirst()))

        guard claim.state == .active,
              let endsAt = claim.endsAt,
              let startsAt = claim.startsAt,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard !dismissedClaimIds.contains(claim.rewardClaimId) else { return }

        let content = content(phase: .active, startedAt: startsAt, endsAt: endsAt)

        if let existingActivity = existingActivities.first {
            Task { @MainActor [existingActivity] in
                await existingActivity.update(content)
            }
            observe(existingActivity)
            return
        }

        do {
            let activity = try Activity.request(
                attributes: RewardLiveActivityAttributes(
                    rewardClaimId: claim.rewardClaimId,
                    rewardTitle: rewardTitle
                ),
                content: content,
                pushType: nil
            )
            observe(activity)
        } catch {
            return
        }
#else
        _ = (claim, rewardTitle)
#endif
    }

    func end(for claim: RewardClaimModel, reason: RewardLiveActivityEndReason) {
#if os(iOS) && canImport(ActivityKit)
        let phase: RewardLiveActivityAttributes.Phase = switch reason {
        case .expired: .expired
        }
        let startsAt = claim.startsAt ?? claim.createdAt ?? Date.now
        let endsAt = claim.endsAt ?? startsAt
        let content = content(phase: phase, startedAt: startsAt, endsAt: endsAt)

        for activity in activities(for: claim.rewardClaimId) {
            Task { @MainActor [activity] in
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
#else
        _ = (claim, reason)
#endif
    }

    func reconcile(activeClaim: RewardClaimModel?, rewardTitle: String?) {
#if os(iOS) && canImport(ActivityKit)
        guard let activeClaim,
              activeClaim.state == .active,
              let endsAt = activeClaim.endsAt,
              Date.now < endsAt,
              let rewardTitle else {
            endImmediately(Activity<RewardLiveActivityAttributes>.activities)
            return
        }

        dismissedClaimIds.remove(activeClaim.rewardClaimId)
        persistDismissedClaimIds()
        start(for: activeClaim, rewardTitle: rewardTitle)
#else
        _ = (activeClaim, rewardTitle)
#endif
    }

#if os(iOS) && canImport(ActivityKit)
    private func content(
        phase: RewardLiveActivityAttributes.Phase,
        startedAt: Date,
        endsAt: Date
    ) -> ActivityContent<RewardLiveActivityAttributes.ContentState> {
        ActivityContent(
            state: RewardLiveActivityAttributes.ContentState(
                phase: phase,
                startedAt: startedAt,
                endsAt: endsAt
            ),
            staleDate: endsAt,
            relevanceScore: 90
        )
    }

    private func activities(for claimId: String) -> [Activity<RewardLiveActivityAttributes>] {
        Activity<RewardLiveActivityAttributes>.activities.filter {
            $0.attributes.rewardClaimId == claimId
        }
    }

    private func endImmediately(_ activities: [Activity<RewardLiveActivityAttributes>]) {
        for activity in activities {
            Task { @MainActor [activity] in
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }

    private func observe(_ activity: Activity<RewardLiveActivityAttributes>) {
        stateTasks[activity.id]?.cancel()
        stateTasks[activity.id] = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if state == .dismissed {
                    dismissedClaimIds.insert(activity.attributes.rewardClaimId)
                    persistDismissedClaimIds()
                    return
                }
                if state == .ended {
                    return
                }
            }
        }
    }

    private func persistDismissedClaimIds() {
        userDefaults.set(
            Array(dismissedClaimIds),
            forKey: dismissedClaimIdsKey
        )
    }
#endif
}
