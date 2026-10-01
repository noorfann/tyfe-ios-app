import SwiftUI

@Observable
@MainActor
final class StreakPresenter {

    private let interactor: StreakInteractor
    private let router: StreakRouter
    private let calendar: Calendar
    private let now: () -> Date
    private(set) var selectedMonth: Date
    private(set) var isHistoryLoading = false
    private(set) var hasHistoryError = false
    private var hasLoadedHistory = false
    private var historyUserId: String?
    private var eventsByDay: [Date: [StreakEvent]] = [:]
    @ObservationIgnored private var historyTask: Task<Void, Never>?
    @ObservationIgnored private var historyRequestId = UUID()

    var currentStreakData: CurrentStreakData {
        interactor.currentStreakData
    }

    var freezeGuidance: String {
        StreakFreezePolicy.guidance
    }

    init(
        interactor: StreakInteractor,
        router: StreakRouter,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = { Date() }
    ) {
        self.interactor = interactor
        self.router = router
        self.calendar = calendar
        self.now = now
        self.selectedMonth = calendar.dateInterval(of: .month, for: now())?.start ?? now()
    }

    func onViewAppear(delegate: StreakDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        selectedMonth = currentMonth
        refreshHistory()
    }

    func onViewDisappear(delegate: StreakDelegate) {
        historyTask?.cancel()
        historyRequestId = UUID()
        isHistoryLoading = false
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    var calendarMonth: StreakCalendarMonth {
        StreakCalendarMonth(month: selectedMonth, today: now(), calendar: calendar, eventsByDay: eventsByDay)
    }

    private var currentMonth: Date {
        calendar.dateInterval(of: .month, for: now())?.start ?? now()
    }

    private var earliestMonth: Date {
        guard let earliestDay = eventsByDay.keys.min(),
              let month = calendar.dateInterval(of: .month, for: earliestDay)?.start else { return currentMonth }
        return min(month, currentMonth)
    }

    var canViewPreviousMonth: Bool { hasLoadedHistory && selectedMonth > earliestMonth }
    var canViewNextMonth: Bool { hasLoadedHistory && selectedMonth < currentMonth }
    var isViewingCurrentMonth: Bool { selectedMonth == currentMonth }

    func onPreviousMonthPressed() {
        guard canViewPreviousMonth else { return }
        moveMonth(by: -1)
        interactor.trackEvent(event: Event.previousMonth)
    }

    func onNextMonthPressed() {
        guard canViewNextMonth else { return }
        moveMonth(by: 1)
        interactor.trackEvent(event: Event.nextMonth)
    }

    func onTodayPressed() {
        selectedMonth = currentMonth
        interactor.trackEvent(event: Event.today)
    }

    @discardableResult
    func onRetryHistoryPressed() -> Task<Void, Never> {
        interactor.trackEvent(event: Event.retryHistory)
        return refreshHistory()
    }

    private func moveMonth(by value: Int) {
        guard let month = calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        selectedMonth = min(max(month, earliestMonth), currentMonth)
    }

    @discardableResult
    func refreshHistory() -> Task<Void, Never> {
        historyTask?.cancel()
        let requestId = UUID()
        historyRequestId = requestId
        let userId = currentStreakData.userId
        if historyUserId != userId {
            historyUserId = userId
            hasLoadedHistory = false
            selectedMonth = currentMonth
            eventsByDay = [:]
        }
        if !hasLoadedHistory {
            groupEvents(currentStreakData.recentEvents ?? [])
        }
        isHistoryLoading = true
        hasHistoryError = false
        let task = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            do {
                let events = try await interactor.getAllStreakEvents()
                guard !Task.isCancelled, historyRequestId == requestId,
                      currentStreakData.userId == userId else { return }
                groupEvents(events)
                hasLoadedHistory = true
                let month = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? currentMonth
                selectedMonth = min(max(month, earliestMonth), currentMonth)
            } catch {
                guard !Task.isCancelled, historyRequestId == requestId,
                      currentStreakData.userId == userId else { return }
                hasHistoryError = true
                interactor.trackEvent(eventName: "StreakView_HistoryLoad_Fail", parameters: nil, type: .severe)
            }
            guard historyRequestId == requestId else { return }
            isHistoryLoading = false
        }
        historyTask = task
        return task
    }

    private func groupEvents(_ events: [StreakEvent]) {
        eventsByDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.dateCreated) }
    }
}

// MARK: - Presentation state

extension StreakPresenter {

    var currentStreak: Int {
        currentStreakData.currentStreak ?? 0
    }

    var longestStreak: Int {
        currentStreakData.longestStreak ?? 0
    }

    var heroState: StreakHeroState {
        if currentStreak <= 0 { return .start }
        if currentStreakData.isGoalMet { return .secured }
        if currentStreakData.status.isBroken { return .rebuild }
        return .open
    }

    var freezeProgress: StreakFreezeProgress {
        return StreakFreezeProgress(
            available: currentStreakData.freezesAvailableCount ?? 0,
            maximum: StreakFreezePolicy.maximumAvailableFreezes
        )
    }

    var isMilestone: Bool {
        currentStreak > 0 && currentStreak % StreakFreezePolicy.milestoneInterval == 0
    }

    var recentDays: [StreakDay] {
        let calendar = self.calendar
        let today = calendar.startOfDay(for: now())
        let events = currentStreakData.recentEvents ?? []
        let weekdaySymbols = calendar.veryShortWeekdaySymbols

        return (0..<7).reversed().compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }

            let dayEvents = events.filter { calendar.isDate($0.dateCreated, inSameDayAs: date) }
            let isToday = daysAgo == 0
            let mark = Self.mark(for: dayEvents, isToday: isToday)

            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            let weekdayInitial = weekdaySymbols.indices.contains(weekdayIndex)
                ? weekdaySymbols[weekdayIndex]
                : ""

            return StreakDay(
                date: date,
                weekdayInitial: weekdayInitial,
                mark: mark,
                isToday: isToday,
                accessibilityLabel: Self.accessibilityLabel(for: date, mark: mark, isToday: isToday)
            )
        }
    }

    private static func mark(for events: [StreakEvent], isToday: Bool) -> StreakDayMark {
        if events.contains(where: { !$0.isFreeze }) { return .focus }
        if events.contains(where: { $0.isFreeze }) { return .freeze }
        return isToday ? .openToday : .empty
    }

    private static func accessibilityLabel(for date: Date, mark: StreakDayMark, isToday: Bool) -> String {
        let dayName = isToday ? "Today" : date.formatted(.dateTime.weekday(.wide))

        switch mark {
        case .focus: return "\(dayName), focus day"
        case .freeze: return "\(dayName), freeze day"
        case .openToday: return "\(dayName), still open"
        case .empty: return "\(dayName), no activity"
        }
    }
}

// MARK: - Presentation models

enum StreakHeroState: Equatable {
    case start
    case secured
    case open
    case rebuild

    var title: String {
        switch self {
        case .start: return "Start your streak"
        case .secured: return "Today is secured"
        case .open: return "Today is still open"
        case .rebuild: return "Begin again"
        }
    }

    var message: String {
        switch self {
        case .start:
            return "Ready when you are. Your first focus session lights the first tile."
        case .secured:
            return "Your streak is safe for today. Every completed focus session counts."
        case .open:
            return "One focus session keeps your run alive."
        case .rebuild:
            return "Missed days happen. Today is a good day to start a new run."
        }
    }
}

struct StreakFreezeProgress: Equatable {
    let available: Int
    let maximum: Int
}

enum StreakDayMark: Equatable {
    case focus
    case freeze
    case openToday
    case empty
}

struct StreakDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let weekdayInitial: String
    let mark: StreakDayMark
    let isToday: Bool
    let accessibilityLabel: String
}

extension StreakPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: StreakDelegate)
        case onDisappear(delegate: StreakDelegate)
        case previousMonth
        case nextMonth
        case today
        case retryHistory

        var eventName: String {
            switch self {
            case .onAppear: return "StreakView_Appear"
            case .onDisappear: return "StreakView_Disappear"
            case .previousMonth: return "StreakView_PreviousMonth"
            case .nextMonth: return "StreakView_NextMonth"
            case .today: return "StreakView_Today"
            case .retryHistory: return "StreakView_RetryHistory"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .previousMonth, .nextMonth, .today, .retryHistory: return nil
            }
        }

        var type: LogType { .analytic }
    }
}
