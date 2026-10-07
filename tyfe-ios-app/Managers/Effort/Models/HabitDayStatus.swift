import Foundation

enum HabitDayStatus: String, Codable, Hashable, Sendable {
    case pending, completed, skipped, missed, unscheduled, future
    var label: String { rawValue.capitalized }
}
