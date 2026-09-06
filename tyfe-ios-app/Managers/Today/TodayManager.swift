import Foundation
import Observation

@Observable
@MainActor
final class TodayManager {

    private let repository: FocusRepository
    private let clock: FocusClock

    init(
        repository: FocusRepository = MockFocusRepository(),
        clock: FocusClock = SystemFocusClock()
    ) {
        self.repository = repository
        self.clock = clock
    }

    var activities: [ActivityModel] {
        repository.snapshot.activities
    }

    var dailyPlan: DailyPlanModel? {
        repository.snapshot.dailyPlan
    }

    var completedSessionCount: Int {
        repository.snapshot.completedSessionCount
    }

    var rewardCredits: Int {
        repository.snapshot.rewardCredits
    }

    var progression: ProgressionSnapshotModel {
        repository.snapshot.progression
    }

    @discardableResult
    func createActivity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        guard !activities.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame && !$0.isArchived
        }) else {
            return activities.first(where: {
                $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame && !$0.isArchived
            })
        }

        var createdActivity: ActivityModel?
        do {
            try repository.transaction { snapshot in
                let activity = ActivityModel(
                    activityId: "activity-" + String(snapshot.nextActivityNumber),
                    name: trimmedName,
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
    func acceptDailyPlan(
        intendedSessionCount: Int,
        activityIds: [String],
        timeBlocks: [PlanTimeBlockModel]?,
        planItems: [DailyPlanItemModel]? = nil
    ) -> DailyPlanModel {
        let validActivityIds = uniqueActivityIds(from: activityIds)
        let selectedActivityIds = validActivityIds.isEmpty
            ? activities.first(where: { !$0.isArchived }).map { [$0.activityId] } ?? []
            : validActivityIds
        let count = max(intendedSessionCount, 1)
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
        let plan = DailyPlanModel(
            dailyPlanId: dailyPlan?.dailyPlanId ?? "daily-plan-current",
            localDate: Calendar.current.startOfDay(for: clock.now),
            intendedSessionCount: count,
            originalIntendedSessionCount: dailyPlan?.originalIntendedSessionCount ?? count,
            activityIds: selectedActivityIds,
            planItems: planItems,
            timeBlocks: normalizedTimeBlocks,
            isRevised: dailyPlan != nil
        )
        try? repository.transaction { snapshot in
            snapshot.dailyPlan = plan
        }
        return plan
    }

    @discardableResult
    func addActivityToDailyPlan(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        guard activities.contains(where: { $0.activityId == activityId && !$0.isArchived }) else {
            return dailyPlan
        }

        let count = max(sessionCount, 1)
        guard let dailyPlan else {
            return acceptDailyPlan(
                intendedSessionCount: count,
                activityIds: [activityId],
                timeBlocks: nil,
                planItems: [
                    DailyPlanItemModel(
                        planItemId: "plan-item-" + activityId,
                        activityId: activityId,
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
                plannedSessionCount: item.plannedSessionCount + count
            )
        } else {
            items.append(
                DailyPlanItemModel(
                    planItemId: "plan-item-" + activityId,
                    activityId: activityId,
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
              let itemIndex = dailyPlan.planItems.firstIndex(where: { $0.activityId == activityId }) else {
            return dailyPlan
        }

        let completedCount = completedSessionCount(for: activityId)
        let count = max(sessionCount, completedCount)
        var items = dailyPlan.planItems
        let item = items[itemIndex]
        items[itemIndex] = DailyPlanItemModel(
            planItemId: item.planItemId,
            activityId: item.activityId,
            plannedSessionCount: count
        )
        return replaceDailyPlan(dailyPlan, planItems: items)
    }

    @discardableResult
    func removeActivityFromDailyPlan(activityId: String) -> DailyPlanModel? {
        guard let dailyPlan, completedSessionCount(for: activityId) == 0 else {
            return dailyPlan
        }

        let items = dailyPlan.planItems.filter { $0.activityId != activityId }
        if items.isEmpty {
            try? repository.transaction { snapshot in
                snapshot.dailyPlan = nil
            }
            return nil
        }
        return replaceDailyPlan(dailyPlan, planItems: items)
    }

    func completedSessionCount(for activityId: String) -> Int {
        repository.snapshot.focusSessions.filter {
            $0.activityId == activityId && $0.state == .completed
        }.count
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
            intendedSessionCount: normalizedItems.reduce(0) { $0 + $1.plannedSessionCount },
            originalIntendedSessionCount: plan.originalIntendedSessionCount,
            activityIds: normalizedItems.map(\.activityId),
            planItems: normalizedItems,
            timeBlocks: plan.timeBlocks,
            isRevised: true
        )
        try? repository.transaction { snapshot in
            snapshot.dailyPlan = updatedPlan
        }
        return updatedPlan
    }

    private func uniqueActivityIds(from ids: [String]) -> [String] {
        var result: [String] = []
        for id in ids {
            guard !result.contains(id), activities.contains(where: { $0.activityId == id && !$0.isArchived }) else {
                continue
            }
            result.append(id)
        }
        return result
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
