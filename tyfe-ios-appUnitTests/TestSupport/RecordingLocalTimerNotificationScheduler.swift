import Foundation
@testable import tyfe_ios_app

@MainActor
final class RecordingLocalTimerNotificationScheduler: LocalTimerNotificationScheduling {
    private(set) var scheduledPlans: [DailyPlanModel] = []
    private(set) var cancelledDailyPlanIds: [String] = []
    private(set) var scheduledFocusSessions: [FocusSessionModel] = []
    private(set) var cancelledFocusSessionIds: [String] = []
    private(set) var scheduledRewardClaims: [RewardClaimModel] = []
    private(set) var cancelledRewardClaimIds: [String] = []

    func schedulePlanReminders(for plan: DailyPlanModel) {
        scheduledPlans.append(plan)
    }

    func cancelPlanReminders(dailyPlanId: String) {
        cancelledDailyPlanIds.append(dailyPlanId)
    }

    func scheduleFocusCompletion(for session: FocusSessionModel) {
        scheduledFocusSessions.append(session)
    }

    func cancelFocusCompletion(focusSessionId: String) {
        cancelledFocusSessionIds.append(focusSessionId)
    }

    func scheduleRewardExpiry(for claim: RewardClaimModel) {
        scheduledRewardClaims.append(claim)
    }

    func cancelRewardExpiry(rewardClaimId: String) {
        cancelledRewardClaimIds.append(rewardClaimId)
    }
}
