import Foundation

enum HabitViewPeriod: String, CaseIterable, Codable, Identifiable, Sendable {
    case week, month, year

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
