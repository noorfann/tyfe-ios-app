import Foundation

extension TodayManager {

    @discardableResult
    func setActivityRecurrence(
        activityId: String,
        recurrence: ActivityRecurrenceModel?
    ) -> ActivityModel? {
        guard var activity = activities.first(where: { $0.activityId == activityId }) else {
            return nil
        }
        let normalizedRecurrence = recurrence.flatMap { model in
            model.kind == .weekly && model.weekdays.isEmpty ? nil : model
        }
        guard activity.recurrence != normalizedRecurrence else { return activity }
        activity.recurrence = normalizedRecurrence

        var didUpdate = false
        do {
            try repository.transaction { snapshot in
                guard let index = snapshot.activities.firstIndex(where: {
                    $0.activityId == activityId
                }) else {
                    return
                }
                snapshot.activities[index] = activity
                didUpdate = true
            }
        } catch {
            return nil
        }
        return didUpdate ? activity : nil
    }

    @discardableResult
    func materializeCurrentDay() -> Bool {
        let localDay = currentLocalDay
        guard repository.snapshot.lastMaterializedLocalDay != localDay else { return false }
        let seededItems = seededPlanItems(for: localDay)

        var materializedPlan: DailyPlanModel?
        do {
            try repository.transaction { snapshot in
                snapshot.lastMaterializedLocalDay = localDay
                materializedPlan = Self.makeMaterializedPlan(
                    in: &snapshot,
                    localDay: localDay,
                    seededItems: seededItems
                )
            }
        } catch {
            return false
        }
        if let materializedPlan {
            notificationScheduler?.schedulePlanReminders(for: materializedPlan)
        }
        return true
    }

    private func seededPlanItems(for localDay: LocalDay) -> [DailyPlanItemModel] {
        activities
            .filter { activity in
                isActivityAvailable(activity) && activity.recurrence?.isDue(on: localDay) == true
            }
            .compactMap { activity -> DailyPlanItemModel? in
                let count = seededPlannedUnitCount(for: activity)
                guard count > 0 else { return nil }
                return DailyPlanItemModel(
                    planItemId: "plan-item-" + activity.activityId,
                    activityId: activity.activityId,
                    unitKind: activity.type,
                    plannedSessionCount: count
                )
            }
    }

    private func seededPlannedUnitCount(for activity: ActivityModel) -> Int {
        switch activity.type {
        case .session:
            return max(activity.recurrence?.defaultSessionCount ?? 1, 1)
        case .checklist:
            return checklistItems(for: activity.activityId).count
        }
    }

    private static func makeMaterializedPlan(
        in snapshot: inout LocalAppSnapshot,
        localDay: LocalDay,
        seededItems: [DailyPlanItemModel]
    ) -> DailyPlanModel? {
        guard !seededItems.isEmpty else { return nil }
        guard let planIndex = snapshot.dailyPlans.firstIndex(where: { $0.localDay == localDay }) else {
            let totalCount = seededItems.reduce(0) { $0 + $1.plannedSessionCount }
            let plan = DailyPlanModel(
                dailyPlanId: "daily-plan-" + localDay.id,
                localDate: localDay.startDate,
                localDay: localDay,
                intendedSessionCount: totalCount,
                originalIntendedSessionCount: totalCount,
                activityIds: seededItems.map(\.activityId),
                planItems: seededItems,
                timeBlocks: nil,
                isRevised: false
            )
            snapshot.dailyPlans.append(plan)
            return plan
        }

        let plan = snapshot.dailyPlans[planIndex]
        let missingItems = seededItems.filter { item in
            !plan.planItems.contains { $0.activityId == item.activityId }
        }
        guard !missingItems.isEmpty else { return nil }
        let items = plan.planItems + missingItems
        let updatedPlan = DailyPlanModel(
            dailyPlanId: plan.dailyPlanId,
            localDate: plan.localDate,
            localDay: plan.localDay,
            intendedSessionCount: items.reduce(0) { $0 + $1.plannedSessionCount },
            originalIntendedSessionCount: plan.originalIntendedSessionCount,
            activityIds: items.map(\.activityId),
            planItems: items,
            timeBlocks: plan.timeBlocks,
            isRevised: true
        )
        snapshot.dailyPlans[planIndex] = updatedPlan
        return updatedPlan
    }
}
