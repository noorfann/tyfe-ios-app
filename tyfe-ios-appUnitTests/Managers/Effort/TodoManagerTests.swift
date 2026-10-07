import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodoManagerTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return value
    }

    @Test func checklistCompletionIsAtomicAndAwardsOnlyTheParent() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        var draft = TodoDraft()
        draft.title = "Kitchen"
        draft.creditValue = .oneCredit
        draft.items = [TodoChecklistItem(id: "dishes", title: "Dishes"), TodoChecklistItem(id: "counter", title: "Counter")]
        try manager.save(draft)
        let task = try #require(manager.tasks.first)
        try manager.toggleItem(taskId: task.id, itemId: "dishes")
        #expect(repository.snapshot.creditLedger.balance == 0)
        #expect(!manager.tasks[0].isCompleted)
        try manager.toggleItem(taskId: task.id, itemId: "counter")
        #expect(repository.snapshot.creditLedger.balance == 1)
        #expect(manager.tasks[0].isCompleted)
        try manager.setCompleted(taskId: task.id, completed: true)
        #expect(manager.history.count == 1)
        #expect(repository.snapshot.creditLedger.balance == 1)
        try manager.toggleItem(taskId: task.id, itemId: "counter")
        #expect(repository.snapshot.creditLedger.balance == 0)
        #expect(!manager.tasks[0].isCompleted)
        #expect(manager.history[0].undoneAt != nil)
        try manager.toggleItem(taskId: task.id, itemId: "counter")
        #expect(repository.snapshot.creditLedger.balance == 1)
    }

    @Test func insufficientBalanceRejectsTheWholeChecklistChange() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        var draft = TodoDraft()
        draft.title = "Task"
        draft.items = [TodoChecklistItem(id: "step", title: "Step")]
        try manager.save(draft)
        let id = try #require(manager.tasks.first?.id)
        try manager.toggleItem(taskId: id, itemId: "step")
        try repository.transaction {
            try $0.creditLedger.apply(RewardCreditLedgerEntry(
                ledgerEntryId: "spend", source: .rewardClaim, sourceId: "reward",
                amount: -0.5, recordedAt: clock.now, idempotencyKey: "spend"
            ))
        }
        let before = repository.snapshot
        #expect(throws: RewardCreditLedgerError.insufficientCredits) { try manager.toggleItem(taskId: id, itemId: "step") }
        #expect(repository.snapshot == before)
        var edit = TodoDraft(task: manager.tasks[0])
        edit.items.append(TodoChecklistItem(id: "new-step", title: "New step"))
        #expect(throws: RewardCreditLedgerError.insufficientCredits) { try manager.save(edit) }
        #expect(repository.snapshot == before)
    }

    @Test func tasksAndTicksPersistAfterMidnightAndReopeningNeverAwardsAgain() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        var draft = TodoDraft()
        draft.title = "Persistent"
        draft.items = [TodoChecklistItem(id: "one", title: "One"), TodoChecklistItem(id: "two", title: "Two")]
        try manager.save(draft)
        let id = try #require(manager.tasks.first?.id)
        try manager.toggleItem(taskId: id, itemId: "one")
        clock.advance(by: 86_400)
        try manager.prepare()
        #expect(manager.tasks[0].items[0].isCompleted)
        try manager.toggleItem(taskId: id, itemId: "two")
        #expect(repository.snapshot.creditLedger.balance == 0.5)
        let completion = try #require(manager.history.first)
        clock.advance(by: 86_400)
        try manager.setCompleted(taskId: id, completed: false)
        #expect(repository.snapshot.creditLedger.balance == 0)
        #expect(manager.history[0] == completion)
        try manager.toggleItem(taskId: id, itemId: "one")
        try manager.toggleItem(taskId: id, itemId: "two")
        #expect(repository.snapshot.creditLedger.balance == 0)
        #expect(manager.history.count == 2)
        let restored = try JSONDecoder().decode(LocalAppSnapshot.self, from: JSONEncoder().encode(repository.snapshot))
        #expect(restored.effort == repository.snapshot.effort)
    }

    @Test func simpleTaskSameDayUndoUsesTheAwardSnapshot() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        var draft = TodoDraft()
        draft.title = "Simple"
        draft.creditValue = .twoCredits
        try manager.save(draft)
        let id = try #require(manager.tasks.first?.id)
        try manager.setCompleted(taskId: id, completed: true)
        var edit = TodoDraft(task: manager.tasks[0])
        edit.creditValue = .halfCredit
        try manager.save(edit)
        try manager.setCompleted(taskId: id, completed: false)
        #expect(repository.snapshot.creditLedger.balance == 0)
        try manager.setCompleted(taskId: id, completed: true)
        #expect(repository.snapshot.creditLedger.balance == 0.5)
    }
}
