import Foundation

struct HabitGridDay: Identifiable {
    let day: LocalDay
    let status: HabitDayStatus
    let isToday: Bool
    var isInMonth = true
    var id: String { day.id }
    var accessibilityLabel: String {
        "\(day.year)-\(day.month)-\(day.day), \(status.label)\(isToday ? ", today" : "")"
    }
}
