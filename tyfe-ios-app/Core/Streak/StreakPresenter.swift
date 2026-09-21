import SwiftUI

@Observable
@MainActor
final class StreakPresenter {

    private let interactor: StreakInteractor
    private let router: StreakRouter

    var currentStreakData: CurrentStreakData {
        interactor.currentStreakData
    }

    var freezeGuidance: String {
        StreakFreezePolicy.guidance
    }

    init(interactor: StreakInteractor, router: StreakRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: StreakDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: StreakDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
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

    var totalStreakDays: Int {
        currentStreakData.totalEvents ?? 0
    }

    var heroState: StreakHeroState {
        if currentStreak <= 0 { return .start }
        if currentStreakData.isGoalMet { return .secured }
        if currentStreakData.status.isBroken { return .rebuild }
        return .open
    }

    var freezeProgress: StreakFreezeProgress {
        let interval = StreakFreezePolicy.milestoneInterval
        let remainder = currentStreak % interval
        let daysUntilNextFreeze = remainder == 0 ? interval : interval - remainder

        return StreakFreezeProgress(
            available: currentStreakData.freezesAvailableCount ?? 0,
            maximum: StreakFreezePolicy.maximumAvailableFreezes,
            daysUntilNextFreeze: daysUntilNextFreeze
        )
    }

    var isMilestone: Bool {
        currentStreak > 0 && currentStreak % StreakFreezePolicy.milestoneInterval == 0
    }

    var bestChaseText: String? {
        guard longestStreak > 0 else { return nil }

        if currentStreak >= longestStreak {
            return "This is your longest run so far."
        }

        let remaining = longestStreak - currentStreak
        let dayWord = remaining == 1 ? "day" : "days"
        return "\(remaining) \(dayWord) from your best of \(longestStreak)."
    }

    var lastActiveText: String? {
        guard let dateLastEvent = currentStreakData.dateLastEvent else { return nil }
        return "Last active \(dateLastEvent.formatted(date: .abbreviated, time: .omitted))"
    }

    var recentDays: [StreakDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
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
            return "Your streak is safe for today. Bonus sessions still count."
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
    let daysUntilNextFreeze: Int

    var isAtCap: Bool {
        available >= maximum
    }

    var statusText: String {
        if isAtCap {
            return "Freeze bank full at \(maximum)."
        }
        return daysUntilNextFreeze == 1 ? "Next freeze in 1 day." : "Next freeze in \(daysUntilNextFreeze) days."
    }
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

        var eventName: String {
            switch self {
            case .onAppear: return "StreakView_Appear"
            case .onDisappear: return "StreakView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            }
        }

        var type: LogType { .analytic }
    }
}
