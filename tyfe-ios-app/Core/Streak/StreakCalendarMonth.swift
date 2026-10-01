import Foundation

struct StreakCalendarMonth {
    let month: Date
    let today: Date
    let calendar: Calendar
    let eventsByDay: [Date: [StreakEvent]]

    var title: String {
        var format = Date.FormatStyle().month(.wide).year()
        format.calendar = calendar
        format.timeZone = calendar.timeZone
        return month.formatted(format)
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }

    var days: [StreakCalendarDay] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let week = calendar.dateInterval(of: .weekOfMonth, for: interval.start) else { return [] }
        var days: [StreakCalendarDay] = []
        var date = week.start
        while date < interval.end {
            let events = eventsByDay[calendar.startOfDay(for: date)] ?? []
            days.append(StreakCalendarDay(
                date: date,
                isSelectedMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                isToday: calendar.isDate(date, inSameDayAs: today),
                hasFocus: events.contains { !$0.isFreeze },
                hasFreeze: events.contains { $0.isFreeze }
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }
}

struct StreakCalendarDay: Identifiable {
    var id: Date { date }
    let date: Date
    let isSelectedMonth: Bool
    let isToday: Bool
    let hasFocus: Bool
    let hasFreeze: Bool
}
