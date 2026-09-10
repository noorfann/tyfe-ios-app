import Foundation

@MainActor
protocol LocalTimerNotificationScheduling: AnyObject {
    func schedulePlanReminders(for plan: DailyPlanModel)
    func cancelPlanReminders(dailyPlanId: String)
    func scheduleFocusCompletion(for session: FocusSessionModel)
    func cancelFocusCompletion(focusSessionId: String)
    func scheduleRewardExpiry(for claim: RewardClaimModel)
    func cancelRewardExpiry(rewardClaimId: String)
}
