import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct StreakCalendarTests {
    @Test func fullHistoryBrowsesEmptyMonthsAndYearBoundaryWithoutChangingSummary() async throws {
        let context = try makeContext()
        let oldDate = try date(2025, 12, 31)
        context.interactor.events = [StreakEvent.mock(dateCreated: oldDate)]
        let summary = context.presenter.currentStreakData
        let trail = context.presenter.recentDays

        await context.presenter.refreshHistory().value
        for _ in 0..<9 { context.presenter.onPreviousMonthPressed() }
        #expect(context.presenter.selectedMonth == (try date(2026, 1, 1)))
        #expect(context.presenter.calendarMonth.days.filter(\.isSelectedMonth).allSatisfy { !$0.hasFocus && !$0.hasFreeze })
        context.presenter.onPreviousMonthPressed()
        #expect(context.presenter.selectedMonth == (try date(2025, 12, 1)))
        #expect(!context.presenter.canViewPreviousMonth)
        context.presenter.onPreviousMonthPressed()
        #expect(context.presenter.selectedMonth == (try date(2025, 12, 1)))
        let oldDay = try #require(context.presenter.calendarMonth.days.first { $0.date == oldDate })
        #expect(oldDay.hasFocus)
        context.presenter.onNextMonthPressed()
        #expect(context.presenter.selectedMonth == (try date(2026, 1, 1)))
        context.presenter.onTodayPressed()
        #expect(context.presenter.selectedMonth == (try date(2026, 10, 1)))
        #expect(!context.presenter.canViewNextMonth)
        context.presenter.onNextMonthPressed()
        #expect(context.presenter.isViewingCurrentMonth)
        #expect(context.presenter.currentStreakData == summary)
        #expect(context.presenter.recentDays == trail)
    }

    @Test func freshVisitReturnsToCurrentMonthAndRefreshRetainsSelection() async throws {
        let context = try makeContext()
        context.interactor.events = [StreakEvent.mock(dateCreated: try date(2026, 8, 1))]
        await context.presenter.refreshHistory().value
        context.presenter.onPreviousMonthPressed()
        await context.presenter.refreshHistory().value
        #expect(context.presenter.selectedMonth == (try date(2026, 9, 1)))
        context.presenter.onViewDisappear(delegate: StreakDelegate())
        context.presenter.onViewAppear(delegate: StreakDelegate())
        #expect(context.presenter.isViewingCurrentMonth)
        await context.presenter.refreshHistory().value
    }

    @Test func emptyHistoryAllowsOnlyCurrentMonth() async throws {
        let context = try makeContext()
        #expect(!context.presenter.canViewPreviousMonth)
        await context.presenter.refreshHistory().value
        #expect(!context.presenter.canViewPreviousMonth)
        #expect(!context.presenter.canViewNextMonth)
        #expect(context.presenter.calendarMonth.days.filter(\.isToday).count == 1)
    }

    @Test func monthRolloverRefreshExpandsBoundsWithoutResettingSelectedMonth() async throws {
        var today = try date(2026, 9, 30)
        let interactor = StreakHistoryTestInteractor(data: streakData())
        interactor.events = [StreakEvent.mock(dateCreated: today)]
        let presenter = StreakPresenter(interactor: interactor, router: StreakCalendarRouter(), calendar: try calendar(), now: { today })
        await presenter.refreshHistory().value
        #expect(!presenter.canViewNextMonth)
        today = try date(2026, 10, 1)
        await presenter.refreshHistory().value
        #expect(presenter.selectedMonth == (try date(2026, 9, 1)))
        #expect(presenter.canViewNextMonth)
        #expect(presenter.currentStreak == 7)
        presenter.onTodayPressed()
        #expect(presenter.selectedMonth == (try date(2026, 10, 1)))
    }

    @Test func initialFailureRetainsRecentMarksAndRetryLoadsOlderHistory() async throws {
        let context = try makeContext()
        let todayEvent = StreakEvent.mock(dateCreated: try date(2026, 10, 1))
        context.interactor.currentStreakData = streakData(recentEvents: [todayEvent])
        context.interactor.shouldFail = true
        await context.presenter.refreshHistory().value
        #expect(context.presenter.hasHistoryError)
        #expect(!context.presenter.isHistoryLoading)
        #expect(!context.presenter.canViewPreviousMonth)
        #expect(context.presenter.calendarMonth.days.contains { $0.isToday && $0.hasFocus })

        context.interactor.shouldFail = false
        context.interactor.events = [todayEvent, StreakEvent.mock(dateCreated: try date(2026, 6, 1))]
        await context.presenter.onRetryHistoryPressed().value
        #expect(!context.presenter.hasHistoryError)
        #expect(context.presenter.canViewPreviousMonth)
        #expect(context.interactor.trackedEvents.contains("StreakView_RetryHistory"))
    }

    @Test func failedRefreshRetainsLoadedHistoryAndNewEventsRefreshMarks() async throws {
        let context = try makeContext()
        let oldDate = try date(2026, 9, 1)
        context.interactor.events = [StreakEvent.mock(dateCreated: oldDate)]
        await context.presenter.refreshHistory().value
        context.presenter.onPreviousMonthPressed()
        context.interactor.shouldFail = true
        await context.presenter.refreshHistory().value
        #expect(context.presenter.hasHistoryError)
        #expect(context.presenter.selectedMonth == oldDate)
        #expect(context.presenter.calendarMonth.days.contains { $0.date == oldDate && $0.hasFocus })

        let newDate = try date(2026, 9, 2)
        context.interactor.shouldFail = false
        context.interactor.events.append(StreakEvent.mock(dateCreated: newDate, isFreeze: true))
        await context.presenter.refreshHistory().value
        #expect(context.presenter.selectedMonth == oldDate)
        #expect(context.presenter.calendarMonth.days.contains { $0.date == newDate && $0.hasFreeze })
    }

    @Test func supersededAndDisappearedLoadsCannotOverwriteCalendar() async throws {
        let context = try makeContext()
        let (starts, signal) = AsyncStream<Void>.makeStream()
        context.interactor.onSuspendedLoad = { signal.yield(()) }
        var started = starts.makeAsyncIterator()
        let first = context.presenter.refreshHistory()
        _ = await started.next()
        #expect(context.presenter.isHistoryLoading)
        let second = context.presenter.refreshHistory()
        _ = await started.next()
        let newEvent = StreakEvent.mock(dateCreated: try date(2026, 9, 1))
        context.interactor.pendingLoads[1].resume(returning: [newEvent])
        await second.value
        context.interactor.pendingLoads[0].resume(returning: [])
        await first.value
        #expect(context.presenter.canViewPreviousMonth)
        #expect(!context.presenter.isHistoryLoading)
        #expect(!context.presenter.hasHistoryError)

        let third = context.presenter.refreshHistory()
        _ = await started.next()
        context.presenter.onViewDisappear(delegate: StreakDelegate())
        context.interactor.pendingLoads[2].resume(throwing: HistoryTestError.unavailable)
        await third.value
        #expect(context.presenter.canViewPreviousMonth)
        #expect(!context.presenter.hasHistoryError)
        #expect(!context.presenter.isHistoryLoading)
        signal.finish()
    }

    @Test func accountChangeClearsOtherUsersHistory() async throws {
        let context = try makeContext()
        context.interactor.events = [StreakEvent.mock(dateCreated: try date(2025, 12, 1))]
        await context.presenter.refreshHistory().value
        context.presenter.onPreviousMonthPressed()
        context.interactor.currentStreakData = streakData(userId: "other-user")
        context.interactor.shouldFail = true
        await context.presenter.refreshHistory().value
        #expect(context.presenter.isViewingCurrentMonth)
        #expect(!context.presenter.canViewPreviousMonth)
        #expect(context.presenter.calendarMonth.days.allSatisfy { !$0.hasFocus && !$0.hasFreeze })
    }

    @Test func leapFebruaryAndMondayFirstHeadingsAlign() throws {
        var calendar = try calendar()
        calendar.firstWeekday = 2
        let month = StreakCalendarMonth(month: try date(2024, 2, 1), today: try date(2024, 2, 29), calendar: calendar, eventsByDay: [:])
        #expect(month.days.filter(\.isSelectedMonth).count == 29)
        #expect(calendar.component(.weekday, from: try #require(month.days.first).date) == 2)
        #expect(month.weekdaySymbols.first == calendar.veryShortWeekdaySymbols[1])
        #expect(month.weekdaySymbols.last == calendar.veryShortWeekdaySymbols[0])
        #expect(month.days.contains { $0.isToday && calendar.component(.day, from: $0.date) == 29 })
    }

    @Test func daylightSavingDayGroupsMultipleSessionsAndFreezeTogether() async throws {
        var calendar = try calendar()
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let localDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let interactor = StreakHistoryTestInteractor(data: streakData())
        interactor.events = [
            StreakEvent.mock(dateCreated: localDay.addingTimeInterval(3_600)),
            StreakEvent.mock(dateCreated: localDay.addingTimeInterval(21 * 3_600)),
            StreakEvent.mock(dateCreated: localDay.addingTimeInterval(2 * 3_600), isFreeze: true)
        ]
        let presenter = StreakPresenter(interactor: interactor, router: StreakCalendarRouter(), calendar: calendar, now: { localDay })
        await presenter.refreshHistory().value
        let markedDays = presenter.calendarMonth.days.filter { $0.hasFocus || $0.hasFreeze }
        #expect(markedDays.count == 1)
        #expect(markedDays.first?.date == localDay)
        #expect(markedDays.first?.hasFocus == true)
        #expect(markedDays.first?.hasFreeze == true)
        let dates = presenter.calendarMonth.days.map(\.date)
        #expect(Set(dates).count == dates.count)
        #expect(presenter.calendarMonth.days.filter(\.isSelectedMonth).count == 31)
    }

    private func makeContext() throws -> (presenter: StreakPresenter, interactor: StreakHistoryTestInteractor) {
        let today = try date(2026, 10, 1)
        let interactor = StreakHistoryTestInteractor(data: streakData())
        let presenter = StreakPresenter(interactor: interactor, router: StreakCalendarRouter(), calendar: try calendar(), now: { today })
        return (presenter, interactor)
    }

    private func calendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        let calendar = try calendar()
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func streakData(userId: String = "calendar-user", recentEvents: [StreakEvent] = []) -> CurrentStreakData {
        CurrentStreakData(streakKey: Constants.streakKey, userId: userId, currentStreak: 7, longestStreak: 14,
                          totalEvents: recentEvents.count, freezesAvailableCount: 1, eventsRequiredPerDay: 1,
                          todayEventCount: 0, recentEvents: recentEvents)
    }
}

private enum HistoryTestError: Error { case unavailable }

@MainActor
private final class StreakHistoryTestInteractor: StreakInteractor {
    var currentStreakData: CurrentStreakData
    var events: [StreakEvent] = []
    var shouldFail = false
    var onSuspendedLoad: (() -> Void)?
    var pendingLoads: [CheckedContinuation<[StreakEvent], Error>] = []
    var trackedEvents: [String] = []

    init(data: CurrentStreakData) { currentStreakData = data }

    func getAllStreakEvents() async throws -> [StreakEvent] {
        if onSuspendedLoad != nil {
            return try await withCheckedThrowingContinuation { continuation in
                pendingLoads.append(continuation)
                onSuspendedLoad?()
            }
        }
        if shouldFail { throw HistoryTestError.unavailable }
        return events
    }

    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) { trackedEvents.append(eventName) }
    func trackEvent(event: AnyLoggableEvent) { }
    func trackEvent(event: LoggableEvent) { trackedEvents.append(event.eventName) }
    func trackScreenEvent(event: LoggableEvent) { }
    func prepareHaptic(option: HapticOption) { }
    func prepareHaptics(options: [HapticOption]) { }
    func playHaptic(option: HapticOption) { }
    func playHaptics(options: [HapticOption]) { }
    func tearDownHaptic(option: HapticOption) { }
    func tearDownHaptics(options: [HapticOption]) { }
    func tearDownAllHaptics() { }
    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int) { }
    func playSoundEffect(sound: SoundEffectFile) { }
    func tearDownSoundEffect(sound: SoundEffectFile) { }
}

@MainActor
private final class StreakCalendarRouter: StreakRouter {
    var router: AnyRouter { fatalError("Router storage is unused by calendar tests") }
}
