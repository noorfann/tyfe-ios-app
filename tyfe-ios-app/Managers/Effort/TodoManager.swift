import Foundation
import Observation

@Observable
@MainActor
final class TodoManager: TodoManaging {
    let repository: LocalAppRepository
    let clock: FocusClock
    private let calendar: Calendar
    private let logger: LogManager?
    private(set) var preparationFailed = false

    init(
        repository: LocalAppRepository, clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent, logger: LogManager? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.logger = logger
    }

    var currentDay: LocalDay { LocalDay(containing: clock.now, calendar: calendar) }
    var tasks: [TodoTaskModel] { repository.snapshot.effort.tasks }
    var history: [TodoCompletionRecord] { repository.snapshot.effort.taskHistory }

    func prepare() throws {
        do {
            try repository.retryLoad()
            var prepared = repository.snapshot
            prepared.migrateEffort(on: currentDay, now: clock.now)
            prepared.prepareEffortDays(through: currentDay)
            if prepared != repository.snapshot {
                try repository.transaction { $0 = prepared }
            }
            preparationFailed = false
        } catch {
            preparationFailed = true
            logger?.trackEvent(eventName: "Effort_Preparation_Fail", parameters: nil, type: .severe)
            throw error
        }
    }

    func save(_ draft: TodoDraft) throws {
        try prepare()
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, repository.snapshot.isValidEffortProject(draft.projectId),
              Set(draft.items.map(\.id)).count == draft.items.count,
              draft.items.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw EffortError.invalidEntry
        }
        try repository.transaction { snapshot in
            if let id = draft.taskId {
                guard let index = snapshot.effort.tasks.firstIndex(where: { $0.id == id }) else { throw EffortError.missingEntry }
                var task = snapshot.effort.tasks[index]
                task.title = title
                task.projectId = draft.projectId
                task.creditValue = draft.creditValue
                task.items = draft.items.map { item in
                    TodoChecklistItem(
                        id: item.id, title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        isCompleted: task.items.first(where: { $0.id == item.id })?.isCompleted ?? false
                    )
                }
                if !task.items.isEmpty {
                    try reconcile(&task, completed: task.items.allSatisfy(\.isCompleted), snapshot: &snapshot)
                }
                snapshot.effort.tasks[index] = task
            } else {
                let items = draft.items.map {
                    TodoChecklistItem(id: $0.id, title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                snapshot.effort.tasks.append(TodoTaskModel(
                    id: "todo-" + UUID().uuidString, title: title, projectId: draft.projectId,
                    items: items, creditValue: draft.creditValue, createdAt: clock.now
                ))
            }
        }
        logger?.trackEvent(eventName: "Todo_Save", parameters: nil, type: .analytic)
    }

    func setCompleted(taskId: String, completed: Bool) throws {
        try prepare()
        try repository.transaction { snapshot in
            guard let index = snapshot.effort.tasks.firstIndex(where: { $0.id == taskId }) else { throw EffortError.missingEntry }
            var task = snapshot.effort.tasks[index]
            guard !completed || task.items.allSatisfy(\.isCompleted) else { throw EffortError.invalidEntry }
            try reconcile(&task, completed: completed, snapshot: &snapshot)
            if !completed {
                // Reopening an all-checked task must leave a step available to finish again.
                for itemIndex in task.items.indices { task.items[itemIndex].isCompleted = false }
            }
            snapshot.effort.tasks[index] = task
        }
        logger?.trackEvent(eventName: "Todo_Completion_Change", parameters: nil, type: .analytic)
    }

    func toggleItem(taskId: String, itemId: String) throws {
        try prepare()
        try repository.transaction { snapshot in
            guard let taskIndex = snapshot.effort.tasks.firstIndex(where: { $0.id == taskId }),
                  let itemIndex = snapshot.effort.tasks[taskIndex].items.firstIndex(where: { $0.id == itemId }) else {
                throw EffortError.missingEntry
            }
            var task = snapshot.effort.tasks[taskIndex]
            task.items[itemIndex].isCompleted.toggle()
            try reconcile(&task, completed: task.items.allSatisfy(\.isCompleted), snapshot: &snapshot)
            snapshot.effort.tasks[taskIndex] = task
        }
        logger?.trackEvent(eventName: "Todo_Item_Toggle", parameters: nil, type: .analytic)
    }

    private func reconcile(_ task: inout TodoTaskModel, completed: Bool, snapshot: inout LocalAppSnapshot) throws {
        guard task.isCompleted != completed else { return }
        snapshot.creditLedger.startDay(currentDay, now: clock.now)
        if completed {
            if !task.hasEarnedAward {
                let amount = task.creditValue.creditValue
                try changeCredits(amount, taskId: task.id, snapshot: &snapshot)
                task.hasEarnedAward = true
                task.awardDay = currentDay
                task.awardAmount = amount
            }
            task.completedAt = clock.now
            snapshot.effort.taskHistory.append(TodoCompletionRecord(
                id: "todo-completion-" + UUID().uuidString, taskId: task.id, title: task.title,
                projectId: task.projectId, completedAt: clock.now, localDay: currentDay
            ))
        } else {
            if task.awardDay == currentDay && task.awardAmount > 0 {
                try changeCredits(-task.awardAmount, taskId: task.id, snapshot: &snapshot)
                task.hasEarnedAward = false
                task.awardDay = nil
                task.awardAmount = 0
            }
            if let index = snapshot.effort.taskHistory.lastIndex(where: {
                $0.taskId == task.id && $0.localDay == currentDay && $0.undoneAt == nil
            }) {
                snapshot.effort.taskHistory[index].undoneAt = clock.now
            }
            task.completedAt = nil
        }
    }

    private func changeCredits(_ amount: Decimal, taskId: String, snapshot: inout LocalAppSnapshot) throws {
        let key = "todo-credit-" + taskId + "-" + String(snapshot.creditLedger.entries.count)
        try snapshot.creditLedger.apply(RewardCreditLedgerEntry(
            ledgerEntryId: key, source: .todoTask, sourceId: taskId,
            amount: amount, recordedAt: clock.now, idempotencyKey: key
        ))
    }
}
