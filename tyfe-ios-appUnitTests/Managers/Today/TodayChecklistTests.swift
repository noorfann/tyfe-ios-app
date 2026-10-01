import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayChecklistTests {

    @Test func tickingAnItemAwardsItsConfiguredCreditAndUndoReversesIt() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let activity = try #require(
            today.createActivity(name: "Reset kitchen", category: nil, colorToken: nil, type: .checklist)
        )
        let item = try #require(
            today.addChecklistItem(
                activityId: activity.activityId,
                title: "Wipe counters",
                creditValue: .halfCredit
            )
        )
        _ = today.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)

        let completion = try #require(today.completeChecklistItem(itemId: item.itemId))
        #expect(completion.creditValueSnapshot == .halfCredit)
        #expect(today.rewardCredits == 0.5)
        #expect(today.completedChecklistItemCount(for: activity.activityId, on: today.currentLocalDay) == 1)
        #expect(today.completeChecklistItem(itemId: item.itemId) == nil)

        #expect(today.uncompleteChecklistItem(itemId: item.itemId))
        #expect(today.rewardCredits == 0)
        #expect(today.completedChecklistItemCount(for: activity.activityId, on: today.currentLocalDay) == 0)

        let retick = try #require(today.completeChecklistItem(itemId: item.itemId))
        #expect(retick.completionId == completion.completionId)
        #expect(today.rewardCredits == 0.5)

        clock.advance(by: 86_400)
        #expect(today.completedChecklistItemCount(for: activity.activityId, on: today.currentLocalDay) == 0)
    }

    @Test func checklistItemListIsThePlan() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let activity = try #require(
            today.createActivity(name: "Reset kitchen", category: nil, colorToken: nil, type: .checklist)
        )
        _ = today.addChecklistItem(activityId: activity.activityId, title: "Dishes", creditValue: .oneCredit)
        _ = today.addChecklistItem(activityId: activity.activityId, title: "Counters", creditValue: .oneCredit)
        _ = today.addChecklistItem(activityId: activity.activityId, title: "Trash", creditValue: .halfCredit)

        _ = today.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 2)
        #expect(today.dailyPlan?.planItems.first?.unitKind == .checklist)
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 3)

        let items = today.checklistItems(for: activity.activityId)
        _ = today.completeChecklistItem(itemId: items[0].itemId)
        _ = today.completeChecklistItem(itemId: items[2].itemId)
        #expect(today.rewardCredits == 1.5)
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 3)

        let partialProgress = try #require(today.progress(for: today.currentLocalDay))
        #expect(partialProgress.completedUnitCount == 2)
        #expect(!partialProgress.isSuccessful)

        _ = today.completeChecklistItem(itemId: items[1].itemId)
        let completedProgress = try #require(today.progress(for: today.currentLocalDay))
        #expect(completedProgress.completedUnitCount == 3)
        #expect(completedProgress.isSuccessful)
        #expect(today.rewardCredits == 2.5)
    }

    @Test func addingAndDeletingItemsKeepsThePlanCountInSync() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let activity = try #require(
            today.createActivity(name: "Reset kitchen", category: nil, colorToken: nil, type: .checklist)
        )
        _ = today.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 0)

        let item = try #require(
            today.addChecklistItem(activityId: activity.activityId, title: "Dishes", creditValue: .oneCredit)
        )
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 1)

        _ = try #require(
            today.addChecklistItem(activityId: activity.activityId, title: "Trash", creditValue: .halfCredit)
        )
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 2)

        #expect(today.deleteChecklistItem(itemId: item.itemId))
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 1)
    }

    @Test func checkedItemMustBeUncheckedBeforeDeletion() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let activity = try #require(
            today.createActivity(name: "Reset kitchen", category: nil, colorToken: nil, type: .checklist)
        )
        let item = try #require(
            today.addChecklistItem(activityId: activity.activityId, title: "Trash", creditValue: .oneCredit)
        )

        _ = today.completeChecklistItem(itemId: item.itemId)
        #expect(!today.deleteChecklistItem(itemId: item.itemId))
        #expect(today.uncompleteChecklistItem(itemId: item.itemId))
        #expect(today.deleteChecklistItem(itemId: item.itemId))
    }

    @Test func activityTypeConversionRequiresAnUnrecordedDay() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)
        let activity = ActivityModel.mock
        _ = today.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)

        let converted = try #require(today.convertActivity(activityId: activity.activityId, to: .checklist))
        #expect(converted.type == .checklist)
        #expect(today.dailyPlan?.planItems.first?.unitKind == .checklist)
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 0)

        let restored = try #require(today.convertActivity(activityId: activity.activityId, to: .session))
        #expect(restored.type == .session)
        #expect(today.dailyPlan?.planItems.first?.unitKind == .session)
        #expect(today.dailyPlan?.planItems.first?.plannedSessionCount == 1)

        _ = try #require(focus.startFocusSession(activityId: activity.activityId))
        #expect(today.convertActivity(activityId: activity.activityId, to: .checklist) == nil)
    }

    @Test func checklistActivityCannotStartAFocusSession() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)
        let activity = try #require(
            today.createActivity(name: "Reset kitchen", category: nil, colorToken: nil, type: .checklist)
        )

        #expect(focus.startFocusSession(activityId: activity.activityId) == nil)
    }

    @Test func ledgerSupportsFractionalChecklistCredits() throws {
        var ledger = RewardCreditLedger()
        try ledger.apply(
            RewardCreditLedgerEntry(
                ledgerEntryId: "credit-half",
                source: .checklistItem,
                sourceId: "checklist-completion-1",
                amount: 0.5,
                recordedAt: Date(),
                idempotencyKey: "credit-half"
            )
        )
        #expect(ledger.balance == 0.5)
    }

    @Test func legacySnapshotsDecodeChecklistDefaults() throws {
        let activityData = Data("{\"activityId\":\"legacy\",\"name\":\"Legacy\",\"createdAt\":0}".utf8)
        let activity = try JSONDecoder().decode(ActivityModel.self, from: activityData)
        #expect(activity.type == .session)

        let itemData = Data(
            "{\"planItemId\":\"plan-item\",\"activityId\":\"legacy\",\"plannedSessionCount\":2}".utf8
        )
        let item = try JSONDecoder().decode(DailyPlanItemModel.self, from: itemData)
        #expect(item.unitKind == .session)
        #expect(item.plannedSessionCount == 2)
    }
}
