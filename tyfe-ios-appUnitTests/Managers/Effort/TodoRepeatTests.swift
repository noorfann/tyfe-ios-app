import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodoRepeatTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT") ?? .current
        return calendar
    }

    private struct Fixture {
        let manager: TodoManager
        let repository: MockLocalAppRepository
        let clock: TestFocusClock
    }

    private func fixture(weekdays: Set<Int>? = nil) throws -> Fixture {
        let monday = LocalDay(year: 2026, month: 3, day: 2, timeZoneIdentifier: "GMT")
        let clock = TestFocusClock(now: monday.startDate.addingTimeInterval(3_600))
        let repository = MockLocalAppRepository()
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        var draft = TodoDraft()
        draft.title = "Reset room"
        draft.items = [TodoChecklistItem(id: "desk", title: "Desk"), TodoChecklistItem(id: "floor", title: "Floor")]
        draft.repeatDraft.choice = weekdays == nil ? .everyDay : .certainDays
        draft.repeatDraft.weekdays = weekdays ?? []
        try manager.save(draft)
        return Fixture(manager: manager, repository: repository, clock: clock)
    }

    private func complete(_ manager: TodoManager) throws {
        let task = try #require(manager.tasks.first)
        for item in task.items where !item.isCompleted { try manager.toggleItem(taskId: task.id, itemId: item.id) }
    }

    @Test func dailyResetPreservesIdentityHistoryAndAwardsOnlyOncePerCycle() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        let repository = fixture.repository
        let clock = fixture.clock
        let original = try #require(manager.tasks.first)
        try complete(manager)
        let history = manager.history
        clock.advance(by: 86_400)
        try manager.prepare()
        let reset = try #require(manager.tasks.first)
        #expect(reset.id == original.id && reset.createdAt == original.createdAt)
        #expect(!reset.isCompleted && !reset.hasEarnedAward)
        #expect(reset.items.allSatisfy { !$0.isCompleted })
        #expect(manager.history == history && manager.tasks.count == 1)
        let prepared = repository.snapshot
        try manager.prepare()
        #expect(repository.snapshot == prepared)
        try complete(manager)
        try manager.setCompleted(taskId: reset.id, completed: true)
        #expect(manager.history.count == 2)
        #expect(repository.snapshot.creditLedger.balance == 0.5)
    }

    @Test func unfinishedWorkCarriesAcrossScheduledAndUnscheduledDays() throws {
        let fixture = try fixture(weekdays: [1, 3])
        let manager = fixture.manager
        let clock = fixture.clock
        let id = try #require(manager.tasks.first?.id)
        try manager.toggleItem(taskId: id, itemId: "desk")
        clock.advance(by: 9 * 86_400)
        try manager.prepare()
        #expect(manager.tasks.count == 1)
        #expect(manager.tasks[0].items[0].isCompleted)
        #expect(!manager.tasks[0].items[1].isCompleted)
        #expect(manager.history.isEmpty)
    }

    @Test func weeklyTaskWaitsForNextSelectedDay() throws {
        let fixture = try fixture(weekdays: [1, 3])
        let manager = fixture.manager
        let clock = fixture.clock
        try complete(manager)
        clock.advance(by: 86_400)
        try manager.prepare()
        #expect(manager.tasks[0].isCompleted)
        clock.advance(by: 86_400)
        try manager.prepare()
        #expect(!manager.tasks[0].isCompleted)
    }

    @Test func absenceReopensOnceWithoutInventingHistoryOrCredits() throws {
        let fixture = try fixture(weekdays: [1])
        let manager = fixture.manager
        let repository = fixture.repository
        let clock = fixture.clock
        try complete(manager)
        let entries = repository.snapshot.creditLedger.entries
        clock.advance(by: 23 * 86_400)
        try manager.prepare()
        #expect(!manager.tasks[0].isCompleted)
        #expect(manager.history.count == 1 && manager.tasks.count == 1)
        #expect(repository.snapshot.creditLedger.entries == entries)
    }

    @Test func scheduleEditsReplaceTomorrowAndNeverStopsFutureReset() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        let clock = fixture.clock
        try complete(manager)
        var draft = TodoDraft(task: manager.tasks[0])
        draft.repeatDraft.choice = .certainDays
        draft.repeatDraft.weekdays = [3]
        try manager.save(draft)
        draft = TodoDraft(task: manager.tasks[0])
        draft.repeatDraft.choice = .never
        try manager.save(draft)
        let task = manager.tasks[0]
        #expect(task.schedule(on: manager.currentDay)?.kind == .daily)
        #expect(task.pendingSchedule(after: manager.currentDay)?.schedule == nil)
        #expect(task.scheduleRevisions.count == 2)
        #expect(task.isCompleted && task.hasEarnedAward)
        clock.advance(by: 14 * 86_400)
        try manager.prepare()
        #expect(manager.tasks[0].isCompleted)
    }

    @Test func newTaskAppearsImmediatelyEvenWhenWeekdayDoesNotMatch() throws {
        let fixture = try fixture(weekdays: [5])
        let manager = fixture.manager
        #expect(manager.tasks.count == 1 && !manager.tasks[0].isCompleted)
        #expect(manager.tasks[0].schedule(on: manager.currentDay)?.isDue(on: manager.currentDay) == false)
    }

    @Test func invalidWeekdaysRejectSaveWithoutChangingTask() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        let repository = fixture.repository
        var draft = TodoDraft(task: manager.tasks[0])
        draft.repeatDraft.choice = .certainDays
        draft.repeatDraft.weekdays = []
        let before = repository.snapshot
        #expect(throws: EffortError.invalidEntry) { try manager.save(draft) }
        #expect(repository.snapshot == before)
    }

    @Test func sameDayUndoUsesAwardSnapshotAndInsufficientCreditIsAtomic() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        let repository = fixture.repository
        let clock = fixture.clock
        try complete(manager)
        var edit = TodoDraft(task: manager.tasks[0])
        edit.creditValue = .twoCredits
        try manager.save(edit)
        try manager.toggleItem(taskId: manager.tasks[0].id, itemId: "floor")
        #expect(repository.snapshot.creditLedger.balance == 0)
        try complete(manager)
        #expect(repository.snapshot.creditLedger.balance == 2)
        try repository.transaction {
            try $0.creditLedger.apply(RewardCreditLedgerEntry(
                ledgerEntryId: "spend", source: .rewardClaim, sourceId: "reward", amount: -2,
                recordedAt: clock.now, idempotencyKey: "spend"
            ))
        }
        let before = repository.snapshot
        #expect(throws: RewardCreditLedgerError.insufficientCredits) {
            try manager.setCompleted(taskId: manager.tasks[0].id, completed: false)
        }
        #expect(repository.snapshot == before)
    }

    @Test func previousDayReopenRetainsAwardUntilLaterScheduledCycle() throws {
        let fixture = try fixture(weekdays: [5])
        let manager = fixture.manager
        let clock = fixture.clock
        try complete(manager)
        clock.advance(by: 86_400)
        try manager.setCompleted(taskId: manager.tasks[0].id, completed: false)
        #expect(manager.tasks[0].hasEarnedAward)
        try complete(manager)
        clock.advance(by: 3 * 86_400)
        try manager.prepare()
        #expect(!manager.tasks[0].hasEarnedAward && !manager.tasks[0].isCompleted)
        #expect(manager.history.count == 2)
    }

    @Test func restartPreservesPendingScheduleAndDoesNotResetTwice() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        let repository = fixture.repository
        let clock = fixture.clock
        try complete(manager)
        let restored = try JSONDecoder().decode(LocalAppSnapshot.self, from: JSONEncoder().encode(repository.snapshot))
        let relaunched = MockLocalAppRepository(snapshot: restored)
        clock.advance(by: 86_400)
        let next = TodoManager(repository: relaunched, clock: clock, calendar: calendar)
        try next.prepare()
        #expect(!next.tasks[0].isCompleted)
        try next.toggleItem(taskId: next.tasks[0].id, itemId: "desk")
        try next.prepare()
        #expect(next.tasks[0].items[0].isCompleted)
    }

    @Test func timezoneAndBackwardClockPreserveProgress() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        let repository = fixture.repository
        let clock = fixture.clock
        try complete(manager)
        clock.advance(by: -86_400)
        try manager.prepare()
        #expect(manager.tasks[0].isCompleted)
        clock.advance(by: 2 * 86_400)
        var shifted = calendar
        shifted.timeZone = try #require(TimeZone(identifier: "Asia/Jakarta"))
        let next = TodoManager(repository: repository, clock: clock, calendar: shifted)
        try next.prepare()
        #expect(!next.tasks[0].isCompleted)
        try next.toggleItem(taskId: next.tasks[0].id, itemId: "desk")
        try manager.prepare()
        #expect(manager.tasks[0].items[0].isCompleted)
    }

    @Test func oldTaskWithoutScheduleRemainsNever() throws {
        let fixture = try fixture()
        let manager = fixture.manager
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(manager.tasks[0])) as? [String: Any])
        object.removeValue(forKey: "schedule_revisions")
        let task = try JSONDecoder().decode(TodoTaskModel.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(task.scheduleRevisions.isEmpty)
        #expect(task.schedule(on: manager.currentDay) == nil)
    }

    @Test func midnightAndMondayBoundaryResetOnlyAfterTheDueDayBegins() throws {
        let fixture = try fixture(weekdays: [1])
        let manager = fixture.manager
        let clock = fixture.clock
        try complete(manager)
        clock.now = manager.currentDay.adding(days: 7).startDate.addingTimeInterval(-1)
        try manager.prepare()
        #expect(manager.tasks[0].isCompleted)
        clock.advance(by: 1)
        try manager.prepare()
        #expect(!manager.tasks[0].isCompleted)
    }

    @Test func draftValidatesWeekdaysAndNormalizesSelections() {
        var draft = TodoRepeatDraft(recurrence: nil)
        #expect(draft.choice == .never && draft.isValid && draft.recurrence() == nil)
        draft.choice = .certainDays
        draft.weekdays = [0, 8]
        #expect(!draft.isValid)
        draft.weekdays = [5, 1, 8]
        #expect(draft.isValid && draft.recurrence()?.weekdays == [1, 5])
    }

    @Test func daylightSavingResetFollowsLocalMidnightRatherThanTwentyFourHours() throws {
        var localCalendar = calendar
        localCalendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let sunday = LocalDay(year: 2026, month: 3, day: 8, timeZoneIdentifier: "America/New_York")
        let clock = TestFocusClock(now: sunday.startDate.addingTimeInterval(1_800))
        let repository = MockLocalAppRepository()
        let manager = TodoManager(repository: repository, clock: clock, calendar: localCalendar)
        var draft = TodoDraft()
        draft.title = "Daily"
        draft.repeatDraft.choice = .everyDay
        try manager.save(draft)
        let id = try #require(manager.tasks.first?.id)
        try manager.setCompleted(taskId: id, completed: true)
        clock.now = sunday.adding(days: 1).startDate.addingTimeInterval(-1)
        try manager.prepare()
        #expect(manager.tasks[0].isCompleted)
        clock.advance(by: 1)
        try manager.prepare()
        #expect(!manager.tasks[0].isCompleted)
    }
}
