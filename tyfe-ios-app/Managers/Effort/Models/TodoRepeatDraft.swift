import Foundation

enum TodoRepeatChoice: Hashable {
    case never
    case everyDay
    case certainDays
}

struct TodoRepeatDraft: Equatable {
    var choice: TodoRepeatChoice
    var weekdays: Set<Int>

    init(recurrence: RepeatSchedule?) {
        guard let recurrence else {
            choice = .never
            weekdays = []
            return
        }
        switch recurrence.kind {
        case .daily:
            choice = .everyDay
            weekdays = []
        case .weekly:
            choice = .certainDays
            weekdays = Set(recurrence.weekdays)
        }
    }

    var isValid: Bool {
        choice != .certainDays || weekdays.contains { (1...7).contains($0) }
    }

    func recurrence() -> RepeatSchedule? {
        switch choice {
        case .never:
            return nil
        case .everyDay:
            return RepeatSchedule(
                kind: .daily
            )
        case .certainDays:
            guard isValid else { return nil }
            return RepeatSchedule(
                kind: .weekly,
                weekdays: weekdays.sorted()
            )
        }
    }
}
