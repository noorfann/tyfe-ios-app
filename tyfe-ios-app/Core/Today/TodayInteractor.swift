import SwiftUI

@MainActor
protocol TodayInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }
    var isRewardInProgress: Bool { get }
    var phase1Activities: [ActivityModel] { get }
    var phase1Projects: [ProjectModel] { get }
    var phase1SelectedProjectId: String? { get }
    var phase1DailyPlan: DailyPlanModel? { get }
    var phase1CurrentLocalDay: LocalDay { get }
    var phase1EarliestRecordedLocalDay: LocalDay? { get }
    var phase1CompletedSessionCount: Int { get }
    var phase1CompletedSessionCounts: [String: Int] { get }
    var phase1RewardCredits: Int { get }
    var currentStreakData: CurrentStreakData { get }
    var hasSeenDeckSwipeCoachmark: Bool { get }
    var colorScheme: ColorScheme { get }

    func toggleColorScheme()
    func markDeckSwipeCoachmarkSeen()
    func synchronizeRewardCreditDay()

    func phase1DailyPlan(for localDay: LocalDay) -> DailyPlanModel?
    func phase1VisiblePlanItems(on localDay: LocalDay) -> [DailyPlanItemModel]
    func phase1CompletedSessionCount(on localDay: LocalDay) -> Int
    func phase1VisibleCompletedSessionCount(on localDay: LocalDay) -> Int
    func phase1CompletedSessionCounts(on localDay: LocalDay) -> [String: Int]

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel?

    @discardableResult
    func updatePhase1Activity(
        activityId: String,
        name: String,
        category: ActivityCategory?
    ) -> ActivityModel?

    @discardableResult
    func createPhase1Project(name: String, colorToken: String) -> ProjectModel?

    @discardableResult
    func renamePhase1Project(
        projectId: String,
        name: String,
        colorToken: String
    ) -> ProjectModel?

    @discardableResult
    func deletePhase1Project(projectId: String) -> Bool

    @discardableResult
    func setPhase1ProjectArchived(projectId: String, isArchived: Bool) -> Bool

    @discardableResult
    func reorderPhase1Project(projectId: String, toIndex: Int) -> Bool

    @discardableResult
    func assignPhase1Activity(activityId: String, to projectId: String?) -> Bool

    func setPhase1SelectedProjectId(_ projectId: String?)

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

    @discardableResult
    func abandonPhase1FocusSession(focusSessionId: String) -> FocusSessionModel?
}

extension CoreInteractor: TodayInteractor { }
