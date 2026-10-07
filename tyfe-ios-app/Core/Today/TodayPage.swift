import Foundation

enum TodayPage: String, CaseIterable, Identifiable, Sendable {
    case session = "Session"
    case todo = "To Do"
    case habit = "Habit"
    var id: String { rawValue }
}
