import Foundation
import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct HabitCardPeriodTests {
    @Test func weekIsMondayFirstAcrossMonthAndYearBoundaries() throws {
        for (today, monday) in [(day(2026, 1, 1), day(2025, 12, 29)), (day(2026, 2, 1), day(2026, 1, 26)), (day(2028, 3, 1), day(2028, 2, 28))] {
            let fixture = try makeFixture(on: today)
            let history = try #require(fixture.presenter.habitCardHistories.values.first)
            #expect(history.period == .week)
            #expect(history.days.map(\.day) == (0..<7).map { monday.adding(days: $0) })
            #expect(history.weeks.isEmpty)
            #expect(history.days.filter(\.isToday).count == 1)
            #expect(history.days.filter { $0.day.startDate > today.startDate }.allSatisfy { $0.status == .future })
        }
    }

    @Test func monthHasLeapDayAndSubduedAdjacentMonthCells() throws {
        for (today, count) in [(day(2028, 2, 10), 29), (day(2026, 2, 10), 28)] {
            let fixture = try makeFixture(on: today)
            fixture.presenter.selectHabitViewPeriod(.month)
            let history = try #require(fixture.presenter.habitCardHistories.values.first)
            #expect(history.visibleDays.count == count)
            #expect(history.visibleDays.first?.day.day == 1)
            #expect(history.visibleDays.last?.day.day == count)
            #expect(history.days.count.isMultiple(of: 7))
            #expect(RepeatSchedule.isoWeekday(for: try #require(history.days.first?.day)) == 1)
            #expect(history.days.contains { !$0.isInMonth })
            #expect(history.weeks.isEmpty)
        }
    }

    @Test func yearIncludesEveryDateWithBlankPaddingAndTodayScrollAnchor() throws {
        for (today, count) in [(day(2026, 10, 7), 365), (day(2028, 10, 7), 366)] {
            let fixture = try makeFixture(on: today)
            fixture.presenter.selectHabitViewPeriod(.year)
            let history = try #require(fixture.presenter.habitCardHistories.values.first)
            #expect(history.visibleDays.count == count)
            #expect(history.visibleDays.first?.day == day(today.year, 1, 1))
            #expect(history.visibleDays.last?.day == day(today.year, 12, 31))
            #expect(history.days.contains { $0.day.year != today.year })
            #expect(history.weeks.allSatisfy { $0.days.count == 7 })
            #expect(history.weeks.flatMap(\.days).map(\.id) == history.days.map(\.id))
            #expect(RepeatSchedule.isoWeekday(for: try #require(history.days.first?.day)) == 1)
            let index = try #require(history.weeks.firstIndex { $0.days.contains(where: \.isToday) })
            #expect(history.initialScrollFraction == Double(index) / Double(history.weeks.count - 1))
            #expect(history.initialScrollFraction > 0.7 && history.initialScrollFraction < 0.9)
        }
    }

    @Test func periodsExposeStoredStatusesAndDatesBeforeCreationStayUnscheduled() throws {
        let fixture = try makeFixture(on: day(2026, 10, 7), age: 7)
        let habit = try #require(fixture.presenter.habits.first)
        let today = fixture.presenter.today
        try fixture.repository.transaction { snapshot in
            for index in snapshot.effort.occurrences.indices where snapshot.effort.occurrences[index].habitId == habit.id {
                switch snapshot.effort.occurrences[index].localDay {
                case today.adding(days: -1): snapshot.effort.occurrences[index].status = .skipped
                case today.adding(days: -2): snapshot.effort.occurrences[index].status = .completed
                default: break
                }
            }
        }
        fixture.presenter.reload()
        for period in HabitViewPeriod.allCases {
            fixture.presenter.selectHabitViewPeriod(period)
            let history = try #require(fixture.presenter.habitCardHistories[habit.id])
            #expect(history.days.first { $0.day == today }?.status == .pending)
            #expect(history.days.first { $0.day == today.adding(days: -1) }?.status == .skipped)
            #expect(history.days.first { $0.day == today.adding(days: -2) }?.status == .completed)
            #expect(history.days.first { $0.day == today.adding(days: 1) }?.status == .future)
            #expect(history.days.filter { $0.day.startDate < habit.createdAt }.allSatisfy { $0.status == .unscheduled })
        }
        let history = try #require(fixture.presenter.habitCardHistories[habit.id])
        #expect(history.days.first { $0.day == today.adding(days: -3) }?.status == .missed)
        #expect(history.visibleDays.contains { $0.status == .unscheduled })
        #expect(history.days.first(where: \.isToday)?.accessibilityLabel.contains("today") == true)
    }

    @Test func selectionLeavesOccurrencesCreditsAndTodayActionsIntact() throws {
        let fixture = try makeFixture(on: day(2026, 10, 7))
        let habit = try #require(fixture.presenter.habits.first)
        fixture.presenter.toggleHabit(habit)
        #expect(fixture.repository.snapshot.creditLedger.balance == 0.5)
        let completed = fixture.repository.snapshot
        for period in HabitViewPeriod.allCases {
            fixture.presenter.selectHabitViewPeriod(period)
            #expect(fixture.repository.snapshot == completed)
            #expect(fixture.presenter.occurrence(for: habit.id)?.status == .completed)
            #expect(fixture.presenter.habitCardHistories[habit.id]?.days.first(where: \.isToday)?.status == .completed)
            #expect(fixture.presenter.streak(for: habit.id).current == 1)
        }
        fixture.presenter.toggleSkip(habit)
        #expect(fixture.presenter.occurrence(for: habit.id)?.status == .skipped)
        #expect(fixture.repository.snapshot.creditLedger.balance == 0)
        fixture.presenter.toggleSkip(habit)
        #expect(fixture.presenter.occurrence(for: habit.id)?.status == .pending)
        fixture.presenter.toggleHabit(habit)
        fixture.presenter.toggleHabit(habit)
        #expect(fixture.presenter.occurrence(for: habit.id)?.status == .pending)
        #expect(fixture.repository.snapshot.creditLedger.balance == 0)
    }

    @Test func detailMonthDoesNotChangeCardDatesAndReloadAdvancesCurrentPeriod() throws {
        let fixture = try makeFixture(on: day(2026, 10, 31))
        let habit = try #require(fixture.presenter.habits.first)
        fixture.presenter.selectHabitViewPeriod(.month)
        let currentDays = try #require(fixture.presenter.habitCardHistories[habit.id]).days.map(\.id)
        fixture.presenter.showHabit(habit)
        fixture.presenter.moveMonth(by: -1)
        #expect(fixture.presenter.selectedMonth.month == 9)
        #expect(fixture.presenter.calendarDays(for: habit).filter(\.isInMonth).allSatisfy { $0.day.month == 9 })
        #expect(fixture.presenter.habitCardHistories[habit.id]?.days.map(\.id) == currentDays)
        fixture.clock.now = day(2026, 11, 1).startDate.addingTimeInterval(43_200)
        fixture.presenter.reload()
        #expect(fixture.presenter.habitViewPeriod == .month)
        let nextHistory = try #require(fixture.presenter.habitCardHistories[habit.id])
        #expect(nextHistory.anchorDay.month == 11)
        #expect(nextHistory.visibleDays.allSatisfy { $0.day.month == 11 })
        #expect(nextHistory.days.filter(\.isToday).count == 1)
    }

    @Test func sharedSelectionSurvivesSpacesArchiveAndPresenterRecreation() throws {
        let fixture = try makeFixture(on: day(2026, 10, 7))
        let habit = try #require(fixture.presenter.habits.first)
        let project = try #require(fixture.todayManager.createProject(name: "Home"))
        var draft = HabitDraft(habit: habit)
        draft.projectId = project.id
        draft.isArchived = true
        fixture.presenter.selectHabitViewPeriod(.year)
        try fixture.habitManager.save(draft)
        fixture.clock.now = day(2026, 10, 8).startDate.addingTimeInterval(43_200)
        fixture.presenter.reload()
        #expect(fixture.presenter.habits(in: project.id).isEmpty)
        fixture.presenter.toggleArchivedHabits()
        #expect(fixture.presenter.habits(in: project.id).map(\.id) == [habit.id])
        #expect(fixture.presenter.habitViewPeriod == .year)
        #expect(fixture.presenter.habitCardHistories[habit.id]?.period == .year)
        let restored = TodayEffortPresenter(interactor: fixture.interactor, router: HabitPeriodTestRouter())
        restored.reload()
        #expect(restored.habitViewPeriod == .year)
        #expect(restored.habitCardHistories[habit.id]?.period == .year)
    }

    @Test func periodsUseDeviceLocalDayAcrossDSTAndUTCDateBoundaries() throws {
        let today = LocalDay(year: 2026, month: 3, day: 8, timeZoneIdentifier: "America/Los_Angeles")
        let fixture = try makeFixture(on: today)
        for period in HabitViewPeriod.allCases {
            fixture.presenter.selectHabitViewPeriod(period)
            let history = try #require(fixture.presenter.habitCardHistories.values.first)
            #expect(history.anchorDay == today)
            #expect(history.days.allSatisfy { $0.day.timeZoneIdentifier == today.timeZoneIdentifier })
            #expect(history.days.first(where: \.isToday)?.day == today)
            #expect(history.days.filter { $0.day.startDate > today.startDate }.allSatisfy { $0.status == .future })
            if period != .week {
                #expect(history.days.first { $0.day == today.adding(days: 1) }?.status == .future)
            }
        }
        fixture.clock.now = today.startDate.addingTimeInterval(23 * 3_600 - 1)
        fixture.presenter.reload()
        #expect(fixture.presenter.today == today)
        fixture.clock.advance(by: 1)
        fixture.presenter.reload()
        #expect(fixture.presenter.today == today.adding(days: 1))
    }

    @Test func newHabitHasNoHistoryBeforeCreation() throws {
        let fixture = try makeFixture(on: day(2026, 10, 7), age: 0)
        for period in HabitViewPeriod.allCases {
            fixture.presenter.selectHabitViewPeriod(period)
            let history = try #require(fixture.presenter.habitCardHistories.values.first)
            #expect(history.days.first(where: \.isToday)?.status == .pending)
            let past = history.visibleDays.filter { $0.day.startDate < fixture.presenter.today.startDate }
            #expect(!past.isEmpty)
            #expect(past.allSatisfy { $0.status == .unscheduled })
        }
    }

    @Test func yearReloadMovesFromDecemberToJanuary() throws {
        let fixture = try makeFixture(on: day(2026, 12, 31))
        fixture.presenter.selectHabitViewPeriod(.year)
        let oldHistory = try #require(fixture.presenter.habitCardHistories.values.first)
        #expect(oldHistory.anchorDay.year == 2026)
        #expect(oldHistory.initialScrollFraction > 0.95)
        fixture.clock.now = day(2027, 1, 1).startDate.addingTimeInterval(43_200)
        fixture.presenter.reload()
        let newHistory = try #require(fixture.presenter.habitCardHistories.values.first)
        #expect(newHistory.anchorDay.year == 2027)
        #expect(newHistory.visibleDays.allSatisfy { $0.day.year == 2027 })
        #expect(newHistory.initialScrollFraction == 0)
        #expect(newHistory.visibleDays.first?.isToday == true)
    }

    private func day(_ year: Int, _ month: Int, _ date: Int) -> LocalDay {
        LocalDay(year: year, month: month, day: date, timeZoneIdentifier: TimeZone(secondsFromGMT: 0)?.identifier ?? "GMT")
    }

    private struct Fixture {
        let presenter: TodayEffortPresenter
        let repository: MockLocalAppRepository
        let clock: TestFocusClock
        let todayManager: TodayManager
        let habitManager: HabitManager
        let interactor: CoreInteractor
    }

    private func makeFixture(on today: LocalDay, age: Int = 40) throws -> Fixture {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: today.timeZoneIdentifier) ?? .current
        let clock = TestFocusClock(now: today.adding(days: -age).startDate)
        let repository = MockLocalAppRepository()
        let todoManager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        let habitManager = HabitManager(repository: repository, clock: clock, calendar: calendar)
        let todayManager = TodayManager(repository: repository, clock: clock, calendar: calendar)
        try todoManager.prepare()
        var draft = HabitDraft()
        draft.title = "Read"
        try habitManager.save(draft)
        clock.now = today.startDate.addingTimeInterval(43_200)
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        dependencies.container.register(TodayManager.self, service: todayManager)
        dependencies.container.register(TodoManager.self, service: todoManager)
        dependencies.container.register(HabitManager.self, service: habitManager)
        dependencies.container.register(RewardManager.self, service: RewardManager(repository: repository, clock: clock, calendar: calendar))
        dependencies.container.register(EffortStreakManager.self, service: EffortStreakManager(repository: repository, clock: clock, calendar: calendar))
        let interactor = CoreInteractor(container: dependencies.container)
        let presenter = TodayEffortPresenter(interactor: interactor, router: HabitPeriodTestRouter())
        presenter.reload()
        return Fixture(
            presenter: presenter, repository: repository, clock: clock,
            todayManager: todayManager, habitManager: habitManager, interactor: interactor
        )
    }
}

@MainActor
private final class HabitPeriodTestRouter: TodayRouter {
    var router: AnyRouter { fatalError("Routing is not used by habit period tests") }
    func showStarterActivityView(delegate: StarterActivityDelegate) { }
    func showDailyPlanView(delegate: DailyPlanDelegate) { }
    func showFocusView(delegate: FocusDelegate) { }
    func showStreakView(delegate: StreakDelegate) { }
    func showProjectManagementView(delegate: TodayProjectManagementDelegate) { }
    func showDevSettingsView() { }
}
