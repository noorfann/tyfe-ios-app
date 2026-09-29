import Foundation

extension TodayManager {

    func progress(for localDay: LocalDay) -> DailyPlanProgressModel? {
        guard let plan = dailyPlan(for: localDay) else { return nil }
        let sessions = repository.snapshot.focusSessions.filter {
            $0.localDay == localDay && $0.state == .completed
        }
        let checklistCompletions = repository.snapshot.checklistItemCompletions.filter {
            $0.localDay == localDay
        }
        var plannedCompletionCount = sessions.filter { !$0.isBonusSession }.count
        var bonusCompletionCount = sessions.filter(\.isBonusSession).count
        for item in plan.planItems where item.unitKind == .checklist {
            let completedCount = checklistCompletions.filter { $0.activityId == item.activityId }.count
            plannedCompletionCount += min(completedCount, item.plannedSessionCount)
        }
        return DailyPlanProgressModel(
            localDay: localDay,
            originalPlannedSessionCount: plan.originalIntendedSessionCount,
            finalPlannedSessionCount: plan.intendedSessionCount,
            plannedCompletionCount: plannedCompletionCount,
            bonusCompletionCount: bonusCompletionCount
        )
    }

    func clampedPlannedUnitCount(
        _ requestedCount: Int,
        for activity: ActivityModel,
        unitKind: ActivityType,
        minimum: Int = 0
    ) -> Int {
        switch unitKind {
        case .session:
            return max(requestedCount, minimum, 1)
        case .checklist:
            return checklistItems(for: activity.activityId).count
        }
    }
}

extension TodayManager {

    var checklistItemCompletions: [ChecklistItemCompletionModel] {
        repository.snapshot.checklistItemCompletions
    }

    func checklistItems(for activityId: String) -> [ChecklistItemModel] {
        repository.snapshot.checklistItems
            .filter { $0.activityId == activityId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func addChecklistItem(
        activityId: String,
        title: String,
        creditValue: ChecklistCreditValue
    ) -> ChecklistItemModel? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let activity = activities.first(where: { $0.activityId == activityId && !$0.isArchived }),
              activity.type == .checklist else {
            return nil
        }

        var createdItem: ChecklistItemModel?
        do {
            try repository.transaction { snapshot in
                let item = ChecklistItemModel(
                    itemId: "checklist-item-" + String(snapshot.nextChecklistItemNumber),
                    activityId: activityId,
                    title: trimmedTitle,
                    creditValue: creditValue,
                    createdAt: clock.now
                )
                snapshot.nextChecklistItemNumber += 1
                snapshot.checklistItems.append(item)
                setTodayPlanItem(
                    activityId: activityId,
                    unitKind: .checklist,
                    plannedCount: snapshot.checklistItems.filter { $0.activityId == activityId }.count,
                    localDay: currentLocalDay,
                    in: &snapshot
                )
                createdItem = item
            }
        } catch {
            return nil
        }
        return createdItem
    }

    @discardableResult
    func updateChecklistItem(
        itemId: String,
        title: String,
        creditValue: ChecklistCreditValue
    ) -> ChecklistItemModel? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let existingItem = repository.snapshot.checklistItems.first(where: { $0.itemId == itemId }) else {
            return nil
        }

        let updatedItem = ChecklistItemModel(
            itemId: existingItem.itemId,
            activityId: existingItem.activityId,
            title: trimmedTitle,
            creditValue: creditValue,
            createdAt: existingItem.createdAt
        )
        var didUpdate = false
        do {
            try repository.transaction { snapshot in
                guard let index = snapshot.checklistItems.firstIndex(where: { $0.itemId == itemId }) else {
                    return
                }
                snapshot.checklistItems[index] = updatedItem
                didUpdate = true
            }
        } catch {
            return nil
        }
        return didUpdate ? updatedItem : nil
    }

    @discardableResult
    func deleteChecklistItem(itemId: String) -> Bool {
        guard let existingItem = repository.snapshot.checklistItems.first(where: { $0.itemId == itemId }),
              !isChecklistItemTicked(itemId: itemId) else {
            return false
        }

        var didDelete = false
        do {
            try repository.transaction { snapshot in
                snapshot.checklistItems.removeAll { $0.itemId == itemId }
                setTodayPlanItem(
                    activityId: existingItem.activityId,
                    unitKind: .checklist,
                    plannedCount: snapshot.checklistItems.filter {
                        $0.activityId == existingItem.activityId
                    }.count,
                    localDay: currentLocalDay,
                    in: &snapshot
                )
                didDelete = true
            }
        } catch {
            return false
        }
        return didDelete
    }

    func isChecklistItemTicked(itemId: String, on localDay: LocalDay? = nil) -> Bool {
        let day = localDay ?? currentLocalDay
        return repository.snapshot.checklistItemCompletions.contains {
            $0.itemId == itemId && $0.localDay == day
        }
    }

    func completedChecklistItemCount(for activityId: String, on localDay: LocalDay) -> Int {
        repository.snapshot.checklistItemCompletions.filter {
            $0.localDay == localDay && $0.activityId == activityId
        }.count
    }

    func completedChecklistItemCount(on localDay: LocalDay) -> Int {
        repository.snapshot.checklistItemCompletions.filter {
            $0.localDay == localDay
        }.count
    }

    func visibleCompletedChecklistItemCount(on localDay: LocalDay) -> Int {
        guard localDay == currentLocalDay else { return completedChecklistItemCount(on: localDay) }
        let visibleActivityIds = Set(activities.filter(isActivityAvailable).map(\.activityId))
        return repository.snapshot.checklistItemCompletions.filter {
            $0.localDay == localDay && visibleActivityIds.contains($0.activityId)
        }.count
    }

    func plannedUnitCount(_ unitKind: ActivityType, on localDay: LocalDay) -> Int {
        visiblePlanItems(on: localDay)
            .filter { $0.unitKind == unitKind }
            .reduce(0) { $0 + $1.plannedSessionCount }
    }

    func completedItems(for item: DailyPlanItemModel, on localDay: LocalDay) -> Int {
        switch item.unitKind {
        case .session:
            return completedSessionCount(for: item.activityId, on: localDay)
        case .checklist:
            return completedChecklistItemCount(for: item.activityId, on: localDay)
        }
    }

    @discardableResult
    func completeChecklistItem(itemId: String) -> ChecklistItemCompletionModel? {
        guard let item = repository.snapshot.checklistItems.first(where: { $0.itemId == itemId }),
              let activity = activities.first(where: { $0.activityId == item.activityId }),
              activity.type == .checklist,
              isActivityAvailable(activity),
              !isChecklistItemTicked(itemId: itemId) else {
            return nil
        }

        let localDay = currentLocalDay
        let completion = ChecklistItemCompletionModel(
            completionId: Self.checklistCompletionId(itemId: itemId, localDay: localDay),
            itemId: itemId,
            activityId: item.activityId,
            localDay: localDay,
            itemTitleSnapshot: item.title,
            creditValueSnapshot: item.creditValue,
            completedAt: clock.now
        )
        let priorEntryCount = creditEntries(for: completion.completionId).count

        do {
            try repository.transaction { snapshot in
                guard !snapshot.checklistItemCompletions.contains(where: {
                    $0.itemId == itemId && $0.localDay == localDay
                }) else {
                    return
                }
                snapshot.checklistItemCompletions.append(completion)
                snapshot.creditLedger.startDay(localDay, now: clock.now)
                try snapshot.creditLedger.apply(
                    RewardCreditLedgerEntry(
                        ledgerEntryId: "credit-" + completion.completionId + "-" + String(priorEntryCount),
                        source: .checklistItem,
                        sourceId: completion.completionId,
                        amount: item.creditValue.creditValue,
                        recordedAt: clock.now,
                        idempotencyKey: "checklist-credit-" + completion.completionId + "-" + String(priorEntryCount)
                    )
                )
            }
        } catch {
            return nil
        }
        return completion
    }

    @discardableResult
    func uncompleteChecklistItem(itemId: String) -> Bool {
        let localDay = currentLocalDay
        guard let completion = repository.snapshot.checklistItemCompletions.first(where: {
            $0.itemId == itemId && $0.localDay == localDay
        }) else {
            return false
        }
        let priorEntryCount = creditEntries(for: completion.completionId).count

        do {
            try repository.transaction { snapshot in
                snapshot.checklistItemCompletions.removeAll { $0.completionId == completion.completionId }
                try snapshot.creditLedger.apply(
                    RewardCreditLedgerEntry(
                        ledgerEntryId: "credit-reversal-" + completion.completionId + "-" + String(priorEntryCount),
                        source: .checklistItem,
                        sourceId: completion.completionId,
                        amount: -completion.creditValueSnapshot.creditValue,
                        recordedAt: clock.now,
                        idempotencyKey: "checklist-reversal-" + completion.completionId + "-" + String(priorEntryCount)
                    )
                )
            }
        } catch {
            return false
        }
        return true
    }

    @discardableResult
    func convertActivity(activityId: String, to newType: ActivityType) -> ActivityModel? {
        guard let activity = activities.first(where: { $0.activityId == activityId }),
              activity.type != newType,
              canConvertActivity(activity, to: newType) else {
            return nil
        }

        let localDay = currentLocalDay
        let updatedActivity = ActivityModel(
            activityId: activity.activityId,
            name: activity.name,
            type: newType,
            category: activity.category,
            iconToken: activity.iconToken,
            colorToken: activity.colorToken,
            projectId: activity.projectId,
            isArchived: activity.isArchived,
            createdAt: activity.createdAt
        )
        let itemCount = checklistItems(for: activityId).count
        let existingPlannedCount = dailyPlan?
            .planItems
            .first { $0.activityId == activityId }?
            .plannedSessionCount ?? 0

        var didConvert = false
        do {
            try repository.transaction { snapshot in
                guard let index = snapshot.activities.firstIndex(where: { $0.activityId == activityId }) else {
                    return
                }
                snapshot.activities[index] = updatedActivity
                let plannedCount: Int
                switch newType {
                case .session:
                    plannedCount = max(existingPlannedCount, 1)
                case .checklist:
                    plannedCount = itemCount
                }
                setTodayPlanItem(
                    activityId: activityId,
                    unitKind: newType,
                    plannedCount: plannedCount,
                    localDay: localDay,
                    in: &snapshot
                )
                didConvert = true
            }
        } catch {
            return nil
        }
        return didConvert ? updatedActivity : nil
    }

    func canConvertActivity(_ activity: ActivityModel, to newType: ActivityType) -> Bool {
        let localDay = currentLocalDay
        switch (activity.type, newType) {
        case (.session, .checklist):
            return !hasStartedFocusActivityToday(activityId: activity.activityId, on: localDay)
        case (.checklist, .session):
            return completedChecklistItemCount(for: activity.activityId, on: localDay) == 0
        case (.session, .session), (.checklist, .checklist):
            return false
        }
    }

    private func setTodayPlanItem(
        activityId: String,
        unitKind: ActivityType,
        plannedCount: Int,
        localDay: LocalDay,
        in snapshot: inout LocalAppSnapshot
    ) {
        guard let planIndex = snapshot.dailyPlans.firstIndex(where: { $0.localDay == localDay }),
              let itemIndex = snapshot.dailyPlans[planIndex].planItems.firstIndex(where: {
                  $0.activityId == activityId
              }) else {
            return
        }

        let plan = snapshot.dailyPlans[planIndex]
        var items = plan.planItems
        let existingItem = items[itemIndex]
        items[itemIndex] = DailyPlanItemModel(
            planItemId: existingItem.planItemId,
            activityId: existingItem.activityId,
            unitKind: unitKind,
            plannedSessionCount: plannedCount
        )
        snapshot.dailyPlans[planIndex] = DailyPlanModel(
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
    }

    func hasStartedFocusActivityToday(activityId: String, on localDay: LocalDay) -> Bool {
        repository.snapshot.focusSessions.contains {
            $0.activityId == activityId && $0.localDay == localDay && $0.state != .abandoned
        }
    }

    static func checklistCompletionId(itemId: String, localDay: LocalDay) -> String {
        "checklist-completion-" + itemId + "-" + localDay.id
    }

    private func creditEntries(for completionId: String) -> [RewardCreditLedgerEntry] {
        repository.snapshot.creditLedger.entries.filter {
            $0.source == .checklistItem && $0.sourceId == completionId
        }
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
}
