import Foundation

struct HabitRevision: Codable, Hashable, Sendable {
    let effectiveDay: LocalDay
    var schedule: ActivityRecurrenceModel
    var creditValue: ChecklistCreditValue
    var isArchived: Bool = false

    private enum CodingKeys: String, CodingKey {
        case effectiveDay = "effective_day"
        case schedule
        case creditValue = "credit_value"
        case isArchived = "is_archived"
    }
}
