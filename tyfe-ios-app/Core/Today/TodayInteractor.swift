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
    var currentStreakData: CurrentStreakData { get }
    var hasSeenDeckSwipeCoachmark: Bool { get }
    func markDeckSwipeCoachmarkSeen()
    func synchronizeCurrentDay()

    func phase1DailyPlan(for localDay: LocalDay) -> DailyPlanModel?
    func phase1VisiblePlanItems(on localDay: LocalDay) -> [DailyPlanItemModel]
    func phase1CompletedSessionCount(on localDay: LocalDay) -> Int
    func phase1VisibleCompletedSessionCount(on localDay: LocalDay) -> Int
    func phase1CompletedUnitCounts(on localDay: LocalDay) -> [String: Int]
    func phase1PlannedUnitCount(_ unitKind: ActivityType, on localDay: LocalDay) -> Int
    func phase1VisibleCompletedChecklistItemCount(on localDay: LocalDay) -> Int
    func phase1CompletedChecklistItemCount(for activityId: String, on localDay: LocalDay) -> Int
    func phase1ChecklistItems(for activityId: String) -> [ChecklistItemModel]
    func phase1IsChecklistItemTicked(itemId: String, on localDay: LocalDay) -> Bool
    func phase1HasStartedFocusActivityToday(activityId: String) -> Bool

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?,
        type: ActivityType
    ) -> ActivityModel?

    @discardableResult
    func updatePhase1Activity(
        activityId: String,
        name: String,
        category: ActivityCategory?
    ) -> ActivityModel?

    @discardableResult
    func setPhase1ActivityRecurrence(
        activityId: String,
        recurrence: ActivityRecurrenceModel?
    ) -> ActivityModel?

    @discardableResult
    func convertPhase1Activity(activityId: String, to type: ActivityType) -> ActivityModel?

    @discardableResult
    func addPhase1ChecklistItem(
        activityId: String,
        title: String,
        creditValue: ChecklistCreditValue
    ) -> ChecklistItemModel?

    @discardableResult
    func updatePhase1ChecklistItem(
        itemId: String,
        title: String,
        creditValue: ChecklistCreditValue
    ) -> ChecklistItemModel?

    @discardableResult
    func deletePhase1ChecklistItem(itemId: String) -> Bool

    @discardableResult
    func completePhase1ChecklistItem(itemId: String) -> ChecklistItemCompletionModel?

    @discardableResult
    func uncompletePhase1ChecklistItem(itemId: String) -> Bool

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
