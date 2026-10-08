import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct HabitManagerTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return value
    }

    @Test func checkSkipUndoAndDuplicateActionsHaveOneNetAward() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let manager = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Read"
        try manager.save(draft)
        let id = try #require(manager.habits.first?.id)
        let day = manager.currentDay
        try manager.setStatus(habitId: id, day: day, status: .completed)
        try manager.setStatus(habitId: id, day: day, status: .completed)
        #expect(repository.snapshot.creditLedger.balance == 0.5)
        #expect(repository.snapshot.effort.days.last?.outcome == .successful)
        try manager.setStatus(habitId: id, day: day, status: .skipped)
        #expect(repository.snapshot.creditLedger.balance == 0)
        #expect(repository.snapshot.effort.days.last?.outcome == .neutral)
        try manager.setStatus(habitId: id, day: day, status: .pending)
        #expect(repository.snapshot.effort.days.last?.outcome == .pending)
        try manager.setStatus(habitId: id, day: day, status: .completed)
        #expect(repository.snapshot.creditLedger.balance == 0.5)
    }

    @Test func nonDueAndPastDaysCannotEarnCredits() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let manager = HabitManager(repository: repository, clock: clock, calendar: calendar)
        let weekday = try #require(RepeatSchedule.isoWeekday(for: manager.currentDay))
        var draft = HabitDraft()
        draft.title = "Weekly"
        draft.schedule = RepeatSchedule(kind: .weekly, weekdays: [(weekday % 7) + 1])
        try manager.save(draft)
        let id = try #require(manager.habits.first?.id)
        let creationDay = manager.currentDay
        #expect(manager.occurrences.isEmpty)
        #expect(throws: EffortError.unavailableDay) { try manager.setStatus(habitId: id, day: creationDay, status: .completed) }
        clock.advance(by: 86_400)
        try manager.prepare()
        #expect(manager.occurrences.count == 1)
        #expect(throws: EffortError.unavailableDay) { try manager.setStatus(habitId: id, day: creationDay, status: .completed) }
        #expect(repository.snapshot.creditLedger.balance == 0)
    }

    @Test func scheduleCreditAndArchiveEditsBeginTomorrowAndHistorySurvives() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let manager = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Original"
        try manager.save(draft)
        let habit = try #require(manager.habits.first)
        let day = manager.currentDay
        var edit = HabitDraft(habit: habit)
        edit.title = "Renamed"
        edit.creditValue = .twoCredits
        edit.isArchived = true
        try manager.save(edit)
        #expect(manager.habits[0].isActive(on: day))
        #expect(manager.habits[0].title == "Renamed")
        try manager.setStatus(habitId: habit.id, day: day, status: .completed)
        #expect(repository.snapshot.creditLedger.balance == 0.5)
        #expect(manager.occurrences[0].title == "Original")
        clock.advance(by: 86_400)
        try manager.prepare()
        #expect(!manager.habits[0].isActive(on: manager.currentDay))
        #expect(manager.occurrences.count == 1)
        #expect(manager.occurrences[0].status == .completed)
    }

    @Test func offlineMissesBreakHabitStreakWhileSkipsAndUnscheduledDaysStayNeutral() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try todo.prepare()
        let manager = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Daily"
        try manager.save(draft)
        let id = try #require(manager.habits.first?.id)
        try manager.setStatus(habitId: id, day: manager.currentDay, status: .completed)
        clock.advance(by: 86_400)
        try manager.setStatus(habitId: id, day: manager.currentDay, status: .skipped)
        #expect(HabitStreakSummary(occurrences: manager.occurrences, today: manager.currentDay).current == 1)
        clock.advance(by: 2 * 86_400)
        try manager.prepare()
        #expect(manager.occurrences.contains { $0.status == .missed })
        #expect(HabitStreakSummary(occurrences: manager.occurrences, today: manager.currentDay).current == 0)
        #expect(HabitStreakSummary(occurrences: manager.occurrences, today: manager.currentDay).best == 1)
    }

    @Test func spentAwardCannotBeUndoneOrSkipped() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let manager = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Habit"
        try manager.save(draft)
        let id = try #require(manager.habits.first?.id)
        try manager.setStatus(habitId: id, day: manager.currentDay, status: .completed)
        try repository.transaction {
            try $0.creditLedger.apply(RewardCreditLedgerEntry(
                ledgerEntryId: "spend", source: .rewardClaim, sourceId: "reward",
                amount: -0.5, recordedAt: clock.now, idempotencyKey: "spend"
            ))
        }
        let before = repository.snapshot
        #expect(throws: RewardCreditLedgerError.insufficientCredits) { try manager.setStatus(habitId: id, day: manager.currentDay, status: .pending) }
        #expect(throws: RewardCreditLedgerError.insufficientCredits) { try manager.setStatus(habitId: id, day: manager.currentDay, status: .skipped) }
        #expect(repository.snapshot == before)
    }
}
