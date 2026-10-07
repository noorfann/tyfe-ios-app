import Foundation

struct TodoTaskModel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var projectId: String?
    var items: [TodoChecklistItem]
    var creditValue: ChecklistCreditValue
    let createdAt: Date
    var completedAt: Date?
    var hasEarnedAward: Bool = false
    var awardDay: LocalDay?
    var awardAmount: Decimal = 0
    var isCompleted: Bool { completedAt != nil }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case projectId = "project_id"
        case items
        case creditValue = "credit_value"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case hasEarnedAward = "has_earned_award"
        case awardDay = "award_day"
        case awardAmount = "award_amount"
    }
}
