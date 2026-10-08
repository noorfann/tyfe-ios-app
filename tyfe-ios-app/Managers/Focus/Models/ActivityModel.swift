import Foundation

enum ActivityType: String, Codable, CaseIterable, Hashable {
    case session
    case checklist

    var displayName: String {
        switch self {
        case .session: return "Session"
        case .checklist: return "Checklist"
        }
    }
}

enum ActivityCategory: String, Codable, CaseIterable, Hashable {
    case study
    case work
    case home
    case personal

    var displayName: String {
        rawValue.capitalized
    }
}

struct ActivityModel: Identifiable, Codable, Hashable {
    let activityId: String
    let name: String
    let type: ActivityType
    let category: ActivityCategory?
    let iconToken: String?
    let colorToken: String?
    var projectId: String?
    var legacyRecurrence: LegacyActivityRecurrence?
    let isArchived: Bool
    let createdAt: Date

    var id: String {
        activityId
    }

    private enum CodingKeys: String, CodingKey {
        case activityId
        case name
        case type
        case category
        case iconToken
        case colorToken
        case projectId
        case recurrence
        case isArchived
        case createdAt
    }

    init(
        activityId: String,
        name: String,
        type: ActivityType = .session,
        category: ActivityCategory? = nil,
        iconToken: String? = nil,
        colorToken: String? = nil,
        projectId: String? = nil,
        isArchived: Bool = false,
        createdAt: Date
    ) {
        self.activityId = activityId
        self.name = name
        self.type = type
        self.category = category
        self.iconToken = iconToken
        self.colorToken = colorToken
        self.projectId = projectId
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            activityId: try container.decode(String.self, forKey: .activityId),
            name: try container.decode(String.self, forKey: .name),
            type: try container.decodeIfPresent(ActivityType.self, forKey: .type) ?? .session,
            category: try container.decodeIfPresent(ActivityCategory.self, forKey: .category),
            iconToken: try container.decodeIfPresent(String.self, forKey: .iconToken),
            colorToken: try container.decodeIfPresent(String.self, forKey: .colorToken),
            projectId: try container.decodeIfPresent(String.self, forKey: .projectId),
            isArchived: try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false,
            createdAt: try container.decode(Date.self, forKey: .createdAt)
        )
        legacyRecurrence = try container.decodeIfPresent(LegacyActivityRecurrence.self, forKey: .recurrence)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activityId, forKey: .activityId)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(iconToken, forKey: .iconToken)
        try container.encodeIfPresent(colorToken, forKey: .colorToken)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encodeIfPresent(legacyRecurrence, forKey: .recurrence)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(createdAt, forKey: .createdAt)
    }

    var eventParameters: [String: Any] {
        [
            "activity_id": activityId,
            "activity_name": name,
            "activity_type": type.rawValue,
            "activity_category": category?.rawValue as Any,
            "activity_icon_token": iconToken as Any,
            "activity_color_token": colorToken as Any,
            "activity_is_archived": isArchived,
            "activity_created_at": createdAt
        ]
    }

    static var mock: Self {
        mocks[0]
    }

    static var checklistMock: Self {
        ActivityModel(
            activityId: "activity-checklist-reset-kitchen",
            name: "Reset kitchen",
            type: .checklist,
            iconToken: "sparkles",
            colorToken: "saffron",
            createdAt: Date(timeIntervalSince1970: 1_725_600_000)
        )
    }

    static var mocks: [Self] {
        let createdAt = Date(timeIntervalSince1970: 1_725_600_000)
        return [
            ActivityModel(
                activityId: "activity-study-swift",
                name: "Study Swift",
                category: .study,
                iconToken: "book.closed.fill",
                colorToken: "teal",
                createdAt: createdAt
            ),
            ActivityModel(
                activityId: "activity-write-report",
                name: "Write report",
                category: .work,
                iconToken: "doc.text.fill",
                colorToken: "slateBlue",
                createdAt: createdAt.addingTimeInterval(86_400)
            ),
            ActivityModel(
                activityId: "activity-reset-kitchen",
                name: "Reset kitchen",
                category: .home,
                iconToken: "sparkles",
                colorToken: "saffron",
                createdAt: createdAt.addingTimeInterval(172_800)
            )
        ]
    }
}
