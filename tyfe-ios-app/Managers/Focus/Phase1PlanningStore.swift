import Foundation
import Observation

@Observable
@MainActor
final class Phase1PlanningStore {

    private(set) var activities: [ActivityModel]
    private(set) var dailyPlan: DailyPlanModel?
    private(set) var completedSessionCount: Int
    private(set) var rewardCredits: Int
    private(set) var progression: ProgressionSnapshotModel
    private(set) var currentFocusSession: FocusSessionModel?
    private(set) var focusSessions: [FocusSessionModel]

    private var nextActivityNumber: Int
    private var nextSessionNumber = 1

    init(
        activities: [ActivityModel] = [ActivityModel.mock],
        dailyPlan: DailyPlanModel? = nil,
        completedSessionCount: Int = 0,
        rewardCredits: Int = 2,
        progression: ProgressionSnapshotModel = .mock,
        focusSessions: [FocusSessionModel] = []
    ) {
        self.activities = activities
        self.dailyPlan = dailyPlan
        self.completedSessionCount = max(completedSessionCount, 0)
        self.rewardCredits = max(rewardCredits, 0)
        self.progression = progression
        self.focusSessions = focusSessions
        self.nextActivityNumber = activities.count + 1
    }

    @discardableResult
    func createActivity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        if let existing = activities.first(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame && !$0.isArchived
        }) {
            return existing
        }

        let activity = ActivityModel(
            activityId: "activity-\(nextActivityNumber)",
            name: trimmedName,
            category: category,
            iconToken: iconToken(for: category),
            colorToken: colorToken,
            createdAt: Date()
        )
        nextActivityNumber += 1
        activities.append(activity)
        return activity
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
            localDate: Calendar.current.startOfDay(for: Date()),
            intendedSessionCount: count,
            originalIntendedSessionCount: dailyPlan?.originalIntendedSessionCount ?? count,
            activityIds: selectedActivityIds,
            planItems: planItems,
            timeBlocks: normalizedTimeBlocks,
            isRevised: dailyPlan != nil
        )
        dailyPlan = plan
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
                        planItemId: "plan-item-\(activityId)",
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
                    planItemId: "plan-item-\(activityId)",
                    activityId: activityId,
                    plannedSessionCount: count
                )
            )
        }

        return replaceDailyPlan(dailyPlan, planItems: items, isRevised: true)
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

        return replaceDailyPlan(dailyPlan, planItems: items, isRevised: true)
    }

    @discardableResult
    func removeActivityFromDailyPlan(activityId: String) -> DailyPlanModel? {
        guard let dailyPlan,
              completedSessionCount(for: activityId) == 0 else {
            return dailyPlan
        }

        let items = dailyPlan.planItems.filter { $0.activityId != activityId }
        guard !items.isEmpty else {
            self.dailyPlan = nil
            return nil
        }

        return replaceDailyPlan(dailyPlan, planItems: items, isRevised: true)
    }

    func completedSessionCount(for activityId: String) -> Int {
        focusSessions.filter {
            $0.activityId == activityId && $0.state == .completed
        }.count
    }

    @discardableResult
    func completeFocusSession(
        focusSessionId: String,
        completedAt: Date = Date()
    ) -> FocusSessionModel? {
        guard let index = focusSessions.firstIndex(where: { $0.focusSessionId == focusSessionId }) else {
            return nil
        }

        let session = focusSessions[index]
        guard session.state != .completed && session.state != .abandoned else { return session }
        let completedSession = session.updated(state: .completed, completedAt: completedAt)
        focusSessions[index] = completedSession
        completedSessionCount += 1
        currentFocusSession = completedSession
        return completedSession
    }

    @discardableResult
    func abandonFocusSession(focusSessionId: String) -> FocusSessionModel? {
        guard let index = focusSessions.firstIndex(where: { $0.focusSessionId == focusSessionId }) else {
            return nil
        }

        let session = focusSessions[index]
        guard session.state != .completed && session.state != .abandoned else { return session }
        let abandonedSession = session.updated(state: .abandoned)
        focusSessions[index] = abandonedSession
        currentFocusSession = abandonedSession
        return abandonedSession
    }

    @discardableResult
    func startFocusSession(activityId: String) -> FocusSessionModel? {
        guard activities.contains(where: { $0.activityId == activityId && !$0.isArchived }) else {
            return nil
        }

        let isBonusSession = dailyPlan.map { plan in
            guard let item = plan.planItems.first(where: { $0.activityId == activityId }) else {
                return true
            }
            return completedSessionCount(for: activityId) >= item.plannedSessionCount
        } ?? true
        let session = FocusSessionModel(
            focusSessionId: "focus-session-\(nextSessionNumber)",
            activityId: activityId,
            state: .ready,
            startedAt: Date(),
            isBonusSession: isBonusSession
        )
        nextSessionNumber += 1
        focusSessions.append(session)
        currentFocusSession = session
        return session
    }

    private func replaceDailyPlan(
        _ plan: DailyPlanModel,
        planItems: [DailyPlanItemModel],
        isRevised: Bool
    ) -> DailyPlanModel {
        let normalizedItems = planItems.filter { item in
            activities.contains(where: { activity in
                activity.activityId == item.activityId && !activity.isArchived
            })
        }
        let total = normalizedItems.reduce(0) { $0 + $1.plannedSessionCount }
        let updatedPlan = DailyPlanModel(
            dailyPlanId: plan.dailyPlanId,
            localDate: plan.localDate,
            intendedSessionCount: total,
            originalIntendedSessionCount: plan.originalIntendedSessionCount,
            activityIds: normalizedItems.map(\.activityId),
            planItems: normalizedItems,
            timeBlocks: plan.timeBlocks,
            isRevised: isRevised
        )
        dailyPlan = updatedPlan
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
