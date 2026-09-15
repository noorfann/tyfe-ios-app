import SwiftUI

@MainActor
protocol TodayInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }
    var isRewardInProgress: Bool { get }
    var phase1Activities: [ActivityModel] { get }
    var phase1DailyPlan: DailyPlanModel? { get }
    var phase1CurrentLocalDay: LocalDay { get }
    var phase1EarliestRecordedLocalDay: LocalDay? { get }
    var phase1CompletedSessionCount: Int { get }
    var phase1CompletedSessionCounts: [String: Int] { get }
    var phase1RewardCredits: Int { get }
    var hasSeenDeckSwipeCoachmark: Bool { get }
    var colorScheme: ColorScheme { get }

    func toggleColorScheme()
    func markDeckSwipeCoachmarkSeen()

    func phase1DailyPlan(for localDay: LocalDay) -> DailyPlanModel?
    func phase1CompletedSessionCount(on localDay: LocalDay) -> Int
    func phase1CompletedSessionCounts(on localDay: LocalDay) -> [String: Int]

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel?

    @discardableResult
    func addPhase1ActivityToDailyPlan(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel?

    @discardableResult
    func updatePhase1DailyPlanItemCount(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel?

    @discardableResult
    func removePhase1ActivityFromDailyPlan(activityId: String) -> DailyPlanModel?

    @discardableResult
    func startPhase1FocusSession(activityId: String) -> FocusSessionModel?
}

extension CoreInteractor: TodayInteractor { }
