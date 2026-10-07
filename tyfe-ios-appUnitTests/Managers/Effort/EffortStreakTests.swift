import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct EffortStreakTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return value
    }

    @Test func extraSessionsCannotReplaceDueHabitsAndTasksDoNotCount() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try todo.prepare()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let day = today.currentLocalDay
        let activity = try #require(today.activities.first)
        _ = today.addActivityToDailyPlan(activityId: activity.id, sessionCount: 1)
        let habit = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Walk"
        try habit.save(draft)
        let habitId = try #require(habit.habits.first?.id)
        let focus = FocusManager(repository: repository, clock: clock, calendar: calendar)
        for _ in 0..<2 {
            let session = try #require(focus.startFocusSession(activityId: activity.id))
            _ = try focus.beginFocusSession(focusSessionId: session.id)
            clock.advance(by: TimeInterval(session.durationSeconds))
            _ = try focus.refreshFocusSession(focusSessionId: session.id)
            _ = try focus.skipFocusRest(focusSessionId: session.id)
        }
        try habit.prepare()
        #expect(repository.snapshot.effort.days.last?.outcome == .pending)
        try habit.setStatus(habitId: habitId, day: day, status: .completed)
        #expect(repository.snapshot.effort.days.last?.outcome == .successful)
        var task = TodoDraft()
        task.title = "Unfinished task"
        try todo.save(task)
        #expect(repository.snapshot.effort.days.last?.outcome == .successful)
        try habit.setStatus(habitId: habitId, day: day, status: .pending)
        #expect(repository.snapshot.effort.days.last?.outcome == .pending)
    }

    @Test func completedHabitsCannotReplacePlannedSessionsAndAllSkipsCanBeNeutral() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let activity = try #require(today.activities.first)
        _ = today.addActivityToDailyPlan(activityId: activity.id, sessionCount: 1)
        let habit = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Walk"
        try habit.save(draft)
        let id = try #require(habit.habits.first?.id)
        try habit.setStatus(habitId: id, day: habit.currentDay, status: .completed)
        #expect(repository.snapshot.effort.days.last?.outcome == .pending)
        try habit.setStatus(habitId: id, day: habit.currentDay, status: .skipped)
        #expect(repository.snapshot.effort.days.last?.outcome == .pending)
        try repository.transaction { snapshot in
            snapshot.dailyPlans.removeAll()
            snapshot.prepareEffortDays(through: habit.currentDay)
        }
        #expect(repository.snapshot.effort.days.last?.outcome == .neutral)
        #expect(repository.snapshot.creditLedger.balance == 0)
        #expect(HabitStreakSummary(occurrences: habit.occurrences, today: habit.currentDay).current == 0)
    }

    @Test func neutralDaysPreserveStreakWithoutIncrementingOrConsumingFreezes() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try todo.prepare()
        let manager = EffortStreakManager(repository: repository, clock: clock, calendar: calendar)
        let legacy = CurrentStreakData(streakKey: "focus", userId: "user", currentStreak: 4, longestStreak: 8, dateStreakStart: clock.now)
        let freeze = StreakFreeze(id: "old-freeze", dateEarned: clock.now.addingTimeInterval(-86_400))
        try manager.seed(userId: "user", legacy: legacy, events: [], freezes: [freeze])
        clock.advance(by: 3 * 86_400)
        try manager.reconcile()
        let data = manager.data(userId: "user", fallback: legacy)
        #expect(data.currentStreak == 4)
        #expect(data.longestStreak == 8)
        #expect(data.freezesAvailableCount == 1)
        #expect(manager.events(userId: "user").isEmpty)
    }

    @Test func successUndoAndRetickProduceOnlyOneCurrentDayEvent() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let habit = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Habit"
        try habit.save(draft)
        let id = try #require(habit.habits.first?.id)
        let manager = EffortStreakManager(repository: repository, clock: clock, calendar: calendar)
        let legacy = CurrentStreakData(streakKey: "focus", userId: "user", currentStreak: 6, longestStreak: 6, dateStreakStart: clock.now)
        try manager.seed(userId: "user", legacy: legacy, events: [], freezes: [])
        try habit.setStatus(habitId: id, day: habit.currentDay, status: .completed)
        try manager.reconcile()
        #expect(manager.data(userId: "user", fallback: legacy).currentStreak == 7)
        #expect(manager.freezes(userId: "user").count == 1)
        try habit.setStatus(habitId: id, day: habit.currentDay, status: .pending)
        try manager.reconcile()
        #expect(manager.data(userId: "user", fallback: legacy).currentStreak == 6)
        #expect(manager.events(userId: "user").isEmpty)
        #expect(manager.freezes(userId: "user").isEmpty)
        try habit.setStatus(habitId: id, day: habit.currentDay, status: .completed)
        try manager.reconcile()
        try manager.reconcile()
        #expect(manager.events(userId: "user").count == 1)
        #expect(manager.freezes(userId: "user").count == 1)
    }

    @Test func missedRequiredDayConsumesAnExistingFreezeExactlyOnce() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        try TodoManager(repository: repository, clock: clock, calendar: calendar).prepare()
        let habit = HabitManager(repository: repository, clock: clock, calendar: calendar)
        var draft = HabitDraft()
        draft.title = "Habit"
        try habit.save(draft)
        let manager = EffortStreakManager(repository: repository, clock: clock, calendar: calendar)
        let legacy = CurrentStreakData(streakKey: "focus", userId: "user", currentStreak: 2, longestStreak: 2, dateStreakStart: clock.now)
        try manager.seed(
            userId: "user", legacy: legacy, events: [],
            freezes: [StreakFreeze(id: "freeze", dateEarned: clock.now.addingTimeInterval(-86_400))]
        )
        clock.advance(by: 86_400)
        try manager.reconcile()
        try manager.reconcile()
        #expect(manager.data(userId: "user", fallback: legacy).currentStreak == 2)
        #expect(manager.data(userId: "user", fallback: legacy).freezesAvailableCount == 0)
        #expect(manager.events(userId: "user").filter(\.isFreeze).count == 1)
        clock.advance(by: 86_400)
        try manager.reconcile()
        #expect(manager.data(userId: "user", fallback: legacy).currentStreak == 0)
    }
}
