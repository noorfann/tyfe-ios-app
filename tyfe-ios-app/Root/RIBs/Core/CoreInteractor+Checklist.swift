import Foundation

extension CoreInteractor {

    func scheduleChecklistStreakRecording(for completion: ChecklistItemCompletionModel) {
        Task {
            do {
                try await recordChecklistCompletionForStreak(completion)
            } catch {
                var parameters = error.eventParameters
                parameters["checklist_completion_id"] = completion.completionId
                trackEvent(
                    eventName: "Checklist_StreakRecording_Fail",
                    parameters: parameters,
                    type: .severe
                )
            }
        }
    }

    func recordChecklistCompletionForStreak(_ completion: ChecklistItemCompletionModel) async throws {
        let completionId = GamificationDictionaryValue.string(completion.completionId)
        let existingEvents = try await getAllStreakEvents()
        let alreadyRecorded = existingEvents.contains(where: {
            $0.metadata["checklist_completion_id"] == completionId
        })

        if !alreadyRecorded {
            try await addStreakEvent(metadata: [
                "checklist_completion_id": completionId,
                "source": .string("checklist_item")
            ])
        }

        await awardStreakFreezeIfEligible(sourceId: completion.completionId)
    }
}

extension CoreInteractor {

    func phase1CompletedUnitCounts(on localDay: LocalDay) -> [String: Int] {
        guard let dailyPlan = todayManager.dailyPlan(for: localDay) else { return [:] }
        return Dictionary(uniqueKeysWithValues: dailyPlan.planItems.map { item in
            (item.activityId, todayManager.completedItems(for: item, on: localDay))
        })
    }

    func phase1PlannedUnitCount(_ unitKind: ActivityType, on localDay: LocalDay) -> Int {
        todayManager.plannedUnitCount(unitKind, on: localDay)
    }

    func phase1VisibleCompletedChecklistItemCount(on localDay: LocalDay) -> Int {
        todayManager.visibleCompletedChecklistItemCount(on: localDay)
    }

    func phase1CompletedChecklistItemCount(for activityId: String, on localDay: LocalDay) -> Int {
        todayManager.completedChecklistItemCount(for: activityId, on: localDay)
    }

    func phase1ChecklistItems(for activityId: String) -> [ChecklistItemModel] {
        todayManager.checklistItems(for: activityId)
    }

    func phase1IsChecklistItemTicked(itemId: String, on localDay: LocalDay) -> Bool {
        todayManager.isChecklistItemTicked(itemId: itemId, on: localDay)
    }

    func phase1HasStartedFocusActivityToday(activityId: String) -> Bool {
        todayManager.hasStartedFocusActivityToday(
            activityId: activityId,
            on: todayManager.currentLocalDay
        )
    }

    @discardableResult
    func convertPhase1Activity(activityId: String, to type: ActivityType) -> ActivityModel? {
        todayManager.convertActivity(activityId: activityId, to: type)
    }

    @discardableResult
    func addPhase1ChecklistItem(
        activityId: String,
        title: String,
        creditValue: ChecklistCreditValue
    ) -> ChecklistItemModel? {
        todayManager.addChecklistItem(activityId: activityId, title: title, creditValue: creditValue)
    }

    @discardableResult
    func updatePhase1ChecklistItem(
        itemId: String,
        title: String,
        creditValue: ChecklistCreditValue
    ) -> ChecklistItemModel? {
        todayManager.updateChecklistItem(itemId: itemId, title: title, creditValue: creditValue)
    }

    @discardableResult
    func deletePhase1ChecklistItem(itemId: String) -> Bool {
        todayManager.deleteChecklistItem(itemId: itemId)
    }

    @discardableResult
    func completePhase1ChecklistItem(itemId: String) -> ChecklistItemCompletionModel? {
        let completion = todayManager.completeChecklistItem(itemId: itemId)
        if let completion {
            scheduleChecklistStreakRecording(for: completion)
        }
        return completion
    }

    @discardableResult
    func uncompletePhase1ChecklistItem(itemId: String) -> Bool {
        todayManager.uncompleteChecklistItem(itemId: itemId)
    }

}
