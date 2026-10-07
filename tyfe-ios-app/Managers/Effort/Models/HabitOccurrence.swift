import Foundation

struct HabitOccurrence: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let habitId: String
    let localDay: LocalDay
    let title: String
    var projectId: String?
    let creditValue: ChecklistCreditValue
    var status: HabitDayStatus = .pending
    var completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case localDay = "local_day"
        case title
        case projectId = "project_id"
        case creditValue = "credit_value"
        case status
        case completedAt = "completed_at"
    }
}
