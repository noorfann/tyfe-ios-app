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
    var scheduleRevisions: [TodoScheduleRevision] = []
    var isCompleted: Bool { completedAt != nil }

    func schedule(on day: LocalDay) -> RepeatSchedule? {
        scheduleRevisions.last { $0.effectiveDay.startDate <= day.startDate }?.schedule
    }

    func pendingSchedule(after day: LocalDay) -> TodoScheduleRevision? {
        scheduleRevisions.last { $0.effectiveDay.startDate > day.startDate }
    }

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
        case scheduleRevisions = "schedule_revisions"
    }

    init(
        id: String, title: String, projectId: String?, items: [TodoChecklistItem],
        creditValue: ChecklistCreditValue, createdAt: Date, completedAt: Date? = nil,
        hasEarnedAward: Bool = false, awardDay: LocalDay? = nil, awardAmount: Decimal = 0,
        scheduleRevisions: [TodoScheduleRevision] = []
    ) {
        self.id = id
        self.title = title
        self.projectId = projectId
        self.items = items
        self.creditValue = creditValue
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.hasEarnedAward = hasEarnedAward
        self.awardDay = awardDay
        self.awardAmount = awardAmount
        self.scheduleRevisions = scheduleRevisions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            title: try values.decode(String.self, forKey: .title),
            projectId: try values.decodeIfPresent(String.self, forKey: .projectId),
            items: try values.decode([TodoChecklistItem].self, forKey: .items),
            creditValue: try values.decode(ChecklistCreditValue.self, forKey: .creditValue),
            createdAt: try values.decode(Date.self, forKey: .createdAt),
            completedAt: try values.decodeIfPresent(Date.self, forKey: .completedAt),
            hasEarnedAward: try values.decodeIfPresent(Bool.self, forKey: .hasEarnedAward) ?? false,
            awardDay: try values.decodeIfPresent(LocalDay.self, forKey: .awardDay),
            awardAmount: try values.decodeIfPresent(Decimal.self, forKey: .awardAmount) ?? 0,
            scheduleRevisions: try values.decodeIfPresent([TodoScheduleRevision].self, forKey: .scheduleRevisions) ?? []
        )
    }
}
