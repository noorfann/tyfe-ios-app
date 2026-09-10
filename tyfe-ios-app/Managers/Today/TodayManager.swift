import Foundation
import Observation

@Observable
@MainActor
final class TodayManager {

    private let repository: LocalAppRepository
    private let clock: FocusClock
    private let calendar: Calendar
    private let notificationScheduler: LocalTimerNotificationScheduling?

    init(
        repository: LocalAppRepository = MockLocalAppRepository(),
        clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent,
        notificationScheduler: LocalTimerNotificationScheduling? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.notificationScheduler = notificationScheduler

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

    var dailyPlan: DailyPlanModel? {
        dailyPlan(for: currentLocalDay)
    }

    var completedSessionCount: Int {
        completedSessionCount(on: currentLocalDay)
    }

    var rewardCredits: Int {
        repository.snapshot.creditLedger.balance
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

    func completedSessionCount(on localDay: LocalDay) -> Int {
        repository.snapshot.focusSessions.filter {
            $0.localDay == localDay && $0.state == .completed
        }.count
    }

    func completedSessionCount(for activityId: String, on localDay: LocalDay) -> Int {
        repository.snapshot.focusSessions.filter {
            $0.localDay == localDay
                && $0.activityId == activityId
                && $0.state == .completed
                && !$0.isBonusSession
        }.count
    }

    func progress(for localDay: LocalDay) -> DailyPlanProgressModel? {
        guard let plan = dailyPlan(for: localDay) else { return nil }
        let sessions = repository.snapshot.focusSessions.filter {
            $0.localDay == localDay && $0.state == .completed
        }
        return DailyPlanProgressModel(
            localDay: localDay,
            originalPlannedSessionCount: plan.originalIntendedSessionCount,
            finalPlannedSessionCount: plan.intendedSessionCount,
            plannedCompletionCount: sessions.filter { !$0.isBonusSession }.count,
            bonusCompletionCount: sessions.filter(\.isBonusSession).count
        )
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
