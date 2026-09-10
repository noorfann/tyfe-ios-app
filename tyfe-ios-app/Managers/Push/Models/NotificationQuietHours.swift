import Foundation

struct NotificationQuietHours: Codable, Equatable, Sendable {
    let startMinuteOfDay: Int
    let endMinuteOfDay: Int

    init(startMinuteOfDay: Int, endMinuteOfDay: Int) {
        self.startMinuteOfDay = min(max(startMinuteOfDay, 0), 1_439)
        self.endMinuteOfDay = min(max(endMinuteOfDay, 0), 1_439)
    }

    func nextAllowedDate(for date: Date, calendar: Calendar) -> Date {
        guard startMinuteOfDay != endMinuteOfDay else { return date }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let isQuiet: Bool
        let endIsTomorrow: Bool

        if startMinuteOfDay < endMinuteOfDay {
            isQuiet = minuteOfDay >= startMinuteOfDay && minuteOfDay < endMinuteOfDay
            endIsTomorrow = false
        } else {
            isQuiet = minuteOfDay >= startMinuteOfDay || minuteOfDay < endMinuteOfDay
            endIsTomorrow = minuteOfDay >= startMinuteOfDay
        }

        guard isQuiet else { return date }

        let endHour = endMinuteOfDay / 60
        let endMinute = endMinuteOfDay % 60
        let baseDate = endIsTomorrow
            ? calendar.date(byAdding: .day, value: 1, to: date) ?? date
            : date
        return calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: baseDate
        ) ?? date
    }
}
