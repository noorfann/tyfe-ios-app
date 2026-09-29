import Foundation
import Observation

@Observable
@MainActor
final class TodayManager {

    let repository: LocalAppRepository
    let clock: FocusClock
    private let calendar: Calendar
    let notificationScheduler: LocalTimerNotificationScheduling?
    @ObservationIgnored private let userDefaults: UserDefaults?

    private static let deckSwipeCoachmarkKey = "tyfe.today-deck-coachmark-seen"
    private static let selectedProjectKey = "tyfe.today-selected-project-id"

    private(set) var hasSeenDeckSwipeCoachmark: Bool

    init(
        repository: LocalAppRepository = MockLocalAppRepository(),
        clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent,
        notificationScheduler: LocalTimerNotificationScheduling? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.notificationScheduler = notificationScheduler
        self.userDefaults = userDefaults
        self.hasSeenDeckSwipeCoachmark = userDefaults?.bool(forKey: Self.deckSwipeCoachmarkKey) ?? false

        if let dailyPlan {
            notificationScheduler?.schedulePlanReminders(for: dailyPlan)
        }
    }

    var currentLocalDay: LocalDay {
        LocalDay(containing: clock.now, calendar: calendar)
    }

    var activities: [ActivityModel] {
        repository.snapshot.activities
    }

    var projects: [ProjectModel] {
        repository.snapshot.projects
    }

    var activeProjects: [ProjectModel] {
        projects.filter { !$0.isArchived }
    }

    var selectedProjectId: String? {
        guard let selectedProjectId = userDefaults?.string(forKey: Self.selectedProjectKey),
              activeProjects.contains(where: { $0.projectId == selectedProjectId }) else {
            return nil
        }
        return selectedProjectId
    }

    var dailyPlan: DailyPlanModel? {
        dailyPlan(for: currentLocalDay)
    }

    var earliestRecordedLocalDay: LocalDay? {
        let recordedDays = repository.snapshot.dailyPlans.map(\.localDay)
            + repository.snapshot.focusSessions.map(\.localDay)
        return recordedDays.min { $0.startDate < $1.startDate }
    }

    var completedSessionCount: Int {
        completedSessionCount(on: currentLocalDay)
    }

    var rewardCredits: Decimal {
        repository.snapshot.creditLedger.balance
    }

    @discardableResult
    func createActivity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?,
        type: ActivityType = .session
    ) -> ActivityModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        guard !activities.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
                && $0.type == type
                && isActivityAvailable($0)
        }) else {
            return activities.first(where: {
                $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
                    && $0.type == type
                    && isActivityAvailable($0)
            })
        }

        var createdActivity: ActivityModel?
        do {
            try repository.transaction { snapshot in
                let activity = ActivityModel(
                    activityId: "activity-" + String(snapshot.nextActivityNumber),
                    name: trimmedName,
                    type: type,
                    category: category,
                    iconToken: iconToken(for: category),
                    colorToken: colorToken,
                    createdAt: clock.now
                )
                snapshot.nextActivityNumber += 1
                snapshot.activities.append(activity)
                createdActivity = activity
            }
        } catch {
            return nil
        }
        return createdActivity
    }

    @discardableResult
    func createProject(
        name: String,
        colorToken: String = ProjectModel.defaultColorToken
    ) -> ProjectModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !projects.contains(where: {
                  normalizedProjectName($0.name) == normalizedProjectName(trimmedName)
              }) else {
            return nil
        }

        var createdProject: ProjectModel?
        do {
            try repository.transaction { snapshot in
                guard !snapshot.projects.contains(where: {
                    normalizedProjectName($0.name) == normalizedProjectName(trimmedName)
                }) else { return }
                let project = ProjectModel(
                    projectId: "project-" + String(snapshot.nextProjectNumber),
                    name: trimmedName,
                    colorToken: colorToken
                )
                snapshot.nextProjectNumber += 1
                snapshot.projects.append(project)
                createdProject = project
            }
        } catch {
            return nil
        }
        return createdProject
    }

    @discardableResult
    func renameProject(
        projectId: String,
        name: String,
        colorToken: String? = nil
    ) -> ProjectModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let existingProject = projects.first(where: { $0.projectId == projectId }),
              !projects.contains(where: {
                  $0.projectId != projectId
                      && normalizedProjectName($0.name) == normalizedProjectName(trimmedName)
              }) else {
            return nil
        }

        let updatedProject = ProjectModel(
            projectId: existingProject.projectId,
            name: trimmedName,
            iconToken: existingProject.iconToken,
            colorToken: colorToken ?? existingProject.colorToken ?? ProjectModel.defaultColorToken,
            isArchived: existingProject.isArchived
        )
        var didUpdate = false
        do {
            try repository.transaction { snapshot in
                guard let index = snapshot.projects.firstIndex(where: { $0.projectId == projectId }),
                      !snapshot.projects.contains(where: {
                          $0.projectId != projectId
                              && normalizedProjectName($0.name) == normalizedProjectName(trimmedName)
                      }) else { return }
                snapshot.projects[index] = updatedProject
                didUpdate = true
            }
        } catch {
            return nil
        }
        return didUpdate ? updatedProject : nil
    }

    @discardableResult
    func deleteProject(projectId: String) -> Bool {
        guard projects.contains(where: { $0.projectId == projectId }) else { return false }

        var didDelete = false
        do {
            try repository.transaction { snapshot in
                guard snapshot.projects.contains(where: { $0.projectId == projectId }) else { return }
                snapshot.projects.removeAll { $0.projectId == projectId }
                for index in snapshot.activities.indices where snapshot.activities[index].projectId == projectId {
                    snapshot.activities[index].projectId = nil
                }
                didDelete = true
            }
        } catch {
            return false
        }
        if didDelete, userDefaults?.string(forKey: Self.selectedProjectKey) == projectId {
            userDefaults?.removeObject(forKey: Self.selectedProjectKey)
        }
        return didDelete
    }

    @discardableResult
    func reorderProject(projectId: String, toIndex: Int) -> Bool {
        guard let sourceIndex = projects.firstIndex(where: { $0.projectId == projectId }),
              projects.indices.contains(toIndex) else {
            return false
        }
        guard sourceIndex != toIndex else { return true }

        var didReorder = false
        do {
            try repository.transaction { snapshot in
                guard let currentSourceIndex = snapshot.projects.firstIndex(where: {
                    $0.projectId == projectId
                }), snapshot.projects.indices.contains(toIndex) else { return }
                let project = snapshot.projects.remove(at: currentSourceIndex)
                snapshot.projects.insert(project, at: min(toIndex, snapshot.projects.count))
                didReorder = true
            }
        } catch {
            return false
        }
        return didReorder
    }

    @discardableResult
    func assignActivity(activityId: String, to projectId: String?) -> Bool {
        guard activities.contains(where: { $0.activityId == activityId }),
              projectId == nil || activeProjects.contains(where: { $0.projectId == projectId }) else {
            return false
        }

        var didAssign = false
        do {
            try repository.transaction { snapshot in
                guard let activityIndex = snapshot.activities.firstIndex(where: {
                    $0.activityId == activityId
                }), projectId == nil || snapshot.projects.contains(where: {
                    $0.projectId == projectId && !$0.isArchived
                }) else { return }
                snapshot.activities[activityIndex].projectId = projectId
                didAssign = true
            }
        } catch {
            return false
        }
        return didAssign
    }

    func setSelectedProjectId(_ projectId: String?) {
        guard projectId == nil || activeProjects.contains(where: { $0.projectId == projectId }) else { return }
        userDefaults?.set(projectId, forKey: Self.selectedProjectKey)
    }

    @discardableResult
    func updateActivity(
        activityId: String,
        name: String,
        category: ActivityCategory?
    ) -> ActivityModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let existingActivity = activities.first(where: { $0.activityId == activityId }) else {
            return nil
        }

        let updatedActivity = ActivityModel(
            activityId: existingActivity.activityId,
            name: trimmedName,
            type: existingActivity.type,
            category: category,
            iconToken: iconToken(for: category),
            colorToken: existingActivity.colorToken,
            projectId: existingActivity.projectId,
            recurrence: existingActivity.recurrence,
            isArchived: existingActivity.isArchived,
            createdAt: existingActivity.createdAt
        )

        var didUpdate = false
        do {
            try repository.transaction { snapshot in
                guard let index = snapshot.activities.firstIndex(where: { $0.activityId == activityId }) else {
                    return
                }
                snapshot.activities[index] = updatedActivity
                didUpdate = true
            }
        } catch {
            return nil
        }
        return didUpdate ? updatedActivity : nil
    }

    func markDeckSwipeCoachmarkSeen() {
        hasSeenDeckSwipeCoachmark = true
        userDefaults?.set(true, forKey: Self.deckSwipeCoachmarkKey)
    }

    @discardableResult
    func acceptDailyPlan(
        intendedSessionCount: Int,
        activityIds: [String],
        timeBlocks: [PlanTimeBlockModel]?,
        planItems: [DailyPlanItemModel]? = nil
    ) -> DailyPlanModel {
        let validActivityIds = uniqueActivityIds(from: activityIds)
        let selectedActivityIds = validActivityIds.isEmpty
            ? activities.first(where: isActivityAvailable).map { [$0.activityId] } ?? []
            : validActivityIds
        let count = max(intendedSessionCount, 0)
        let normalizedTimeBlocks = timeBlocks?.map {
            PlanTimeBlockModel(
                timeBlockId: $0.timeBlockId,
                activityId: selectedActivityIds.contains($0.activityId)
                    ? $0.activityId
                    : selectedActivityIds.first ?? $0.activityId,
                plannedStart: $0.plannedStart,
                durationMinutes: FocusSessionModel.durationMinutes
            )
        }
        let existingPlan = dailyPlan
        let plan = DailyPlanModel(
            dailyPlanId: existingPlan?.dailyPlanId ?? "daily-plan-" + currentLocalDay.id,
            localDate: currentLocalDay.startDate,
            localDay: currentLocalDay,
            intendedSessionCount: count,
            originalIntendedSessionCount: existingPlan?.originalIntendedSessionCount ?? count,
            activityIds: selectedActivityIds,
            planItems: planItems,
            timeBlocks: normalizedTimeBlocks,
            isRevised: existingPlan != nil
        )
        do {
            try repository.transaction { snapshot in
                upsert(plan, in: &snapshot)
            }
            notificationScheduler?.schedulePlanReminders(for: plan)
        } catch {
            return plan
        }
        return plan
    }

    @discardableResult
    func addActivityToDailyPlan(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        guard let activity = activities.first(where: {
            $0.activityId == activityId && isActivityAvailable($0)
        }) else {
            return dailyPlan
        }

        let unitKind = activity.type
        let count = clampedPlannedUnitCount(sessionCount, for: activity, unitKind: unitKind)
        guard let dailyPlan else {
            return acceptDailyPlan(
                intendedSessionCount: count,
                activityIds: [activityId],
                timeBlocks: nil,
                planItems: [
                    DailyPlanItemModel(
                        planItemId: "plan-item-" + activityId,
                        activityId: activityId,
                        unitKind: unitKind,
                        plannedSessionCount: count
                    )
                ]
            )
        }

        var items = dailyPlan.planItems
        if let itemIndex = items.firstIndex(where: { $0.activityId == activityId }) {
            let item = items[itemIndex]
            items[itemIndex] = DailyPlanItemModel(
                planItemId: item.planItemId,
                activityId: item.activityId,
                unitKind: unitKind,
                plannedSessionCount: clampedPlannedUnitCount(
                    item.plannedSessionCount + count,
                    for: activity,
                    unitKind: unitKind,
                    minimum: item.plannedSessionCount
                )
            )
        } else {
            items.append(
                DailyPlanItemModel(
                    planItemId: "plan-item-" + activityId,
                    activityId: activityId,
                    unitKind: unitKind,
                    plannedSessionCount: count
                )
            )
        }
        return replaceDailyPlan(dailyPlan, planItems: items)
    }

    @discardableResult
    func updateDailyPlanItemCount(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        guard let dailyPlan,
              let itemIndex = dailyPlan.planItems.firstIndex(where: { $0.activityId == activityId }),
              let activity = activities.first(where: { $0.activityId == activityId }) else {
            return dailyPlan
        }

        let item = dailyPlan.planItems[itemIndex]
        let completedUnitCount: Int
        switch item.unitKind {
        case .session:
            completedUnitCount = completedSessionCount(for: activityId)
        case .checklist:
            completedUnitCount = completedChecklistItemCount(for: activityId, on: currentLocalDay)
        }
        let count = clampedPlannedUnitCount(
            sessionCount,
            for: activity,
            unitKind: item.unitKind,
            minimum: completedUnitCount
        )
        var items = dailyPlan.planItems
        items[itemIndex] = DailyPlanItemModel(
            planItemId: item.planItemId,
            activityId: item.activityId,
            unitKind: item.unitKind,
            plannedSessionCount: count
        )
        return replaceDailyPlan(dailyPlan, planItems: items)
    }

    @discardableResult
    func removeActivityFromDailyPlan(activityId: String) -> DailyPlanModel? {
        guard let dailyPlan,
              completedSessionCount(for: activityId) == 0,
              completedChecklistItemCount(for: activityId, on: currentLocalDay) == 0 else {
            return dailyPlan
        }

        let items = dailyPlan.planItems.filter { $0.activityId != activityId }
        if items.isEmpty {
            do {
                try repository.transaction { snapshot in
                    snapshot.dailyPlans.removeAll { $0.localDay == currentLocalDay }
                }
                notificationScheduler?.cancelPlanReminders(dailyPlanId: dailyPlan.dailyPlanId)
            } catch {
                return dailyPlan
            }
            return nil
        }
        return replaceDailyPlan(dailyPlan, planItems: items)
    }

    func completedSessionCount(for activityId: String) -> Int {
        completedSessionCount(for: activityId, on: currentLocalDay)
    }

    func dailyPlan(for localDay: LocalDay) -> DailyPlanModel? {
        repository.snapshot.dailyPlans.last { $0.localDay == localDay }
    }

    private func replaceDailyPlan(
        _ plan: DailyPlanModel,
        planItems: [DailyPlanItemModel]
    ) -> DailyPlanModel {
        let normalizedItems = planItems.filter { item in
            activities.contains(where: { activity in
                activity.activityId == item.activityId && !activity.isArchived
            })
        }
        let updatedPlan = DailyPlanModel(
            dailyPlanId: plan.dailyPlanId,
            localDate: plan.localDate,
            localDay: plan.localDay,
            intendedSessionCount: normalizedItems.reduce(0) { $0 + $1.plannedSessionCount },
            originalIntendedSessionCount: plan.originalIntendedSessionCount,
            activityIds: normalizedItems.map(\.activityId),
            planItems: normalizedItems,
            timeBlocks: plan.timeBlocks,
            isRevised: true
        )
        do {
            try repository.transaction { snapshot in
                upsert(updatedPlan, in: &snapshot)
            }
            notificationScheduler?.schedulePlanReminders(for: updatedPlan)
        } catch {
            return plan
        }
        return updatedPlan
    }

    private func upsert(_ plan: DailyPlanModel, in snapshot: inout LocalAppSnapshot) {
        if let index = snapshot.dailyPlans.firstIndex(where: { $0.localDay == plan.localDay }) {
            snapshot.dailyPlans[index] = plan
        } else {
            snapshot.dailyPlans.append(plan)
        }
    }

    private func uniqueActivityIds(from ids: [String]) -> [String] {
        var result: [String] = []
        for id in ids {
            guard !result.contains(id), activities.contains(where: {
                $0.activityId == id && isActivityAvailable($0)
            }) else {
                continue
            }
            result.append(id)
        }
        return result
    }

    private func normalizedProjectName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func iconToken(for category: ActivityCategory?) -> String {
        switch category {
        case .study: return "book.closed.fill"
        case .work: return "doc.text.fill"
        case .home: return "house.fill"
        case .personal, .none: return "sparkles"
        }
    }
}

extension TodayManager {
    func isActivityAvailable(_ activity: ActivityModel) -> Bool {
        guard !activity.isArchived else { return false }
        guard let projectId = activity.projectId else { return true }
        return activeProjects.contains { $0.projectId == projectId }
    }

    func visiblePlanItems(on localDay: LocalDay) -> [DailyPlanItemModel] {
        guard let plan = dailyPlan(for: localDay) else { return [] }
        guard localDay == currentLocalDay else { return plan.planItems }
        return plan.planItems.filter { item in
            activities.contains { $0.activityId == item.activityId && isActivityAvailable($0) }
        }
    }

    func visibleCompletedSessionCount(on localDay: LocalDay) -> Int {
        guard localDay == currentLocalDay else { return completedSessionCount(on: localDay) }
        let visibleActivityIds = Set(activities.filter(isActivityAvailable).map(\.activityId))
        return repository.snapshot.focusSessions.filter {
            $0.localDay == localDay && $0.state == .completed
                && visibleActivityIds.contains($0.activityId)
        }.count
    }

    @discardableResult
    func setProjectArchived(projectId: String, isArchived: Bool) -> Bool {
        guard let project = projects.first(where: { $0.projectId == projectId }),
              project.isArchived != isArchived else { return false }

        var didUpdate = false
        do {
            try repository.transaction { snapshot in
                guard let index = snapshot.projects.firstIndex(where: { $0.projectId == projectId }) else {
                    return
                }
                let current = snapshot.projects[index]
                snapshot.projects[index] = ProjectModel(
                    projectId: current.projectId,
                    name: current.name,
                    iconToken: current.iconToken,
                    colorToken: current.colorToken,
                    isArchived: isArchived
                )
                didUpdate = true
            }
        } catch {
            return false
        }
        if didUpdate, isArchived, userDefaults?.string(forKey: Self.selectedProjectKey) == projectId {
            userDefaults?.removeObject(forKey: Self.selectedProjectKey)
        }
        return didUpdate
    }
}
