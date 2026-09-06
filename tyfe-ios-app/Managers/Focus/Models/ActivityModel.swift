import Foundation

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
    let category: ActivityCategory?
    let iconToken: String?
    let colorToken: String?
    let isArchived: Bool
    let createdAt: Date

    var id: String {
        activityId
    }

    init(
        activityId: String,
        name: String,
        category: ActivityCategory? = nil,
        iconToken: String? = nil,
        colorToken: String? = nil,
        isArchived: Bool = false,
        createdAt: Date
    ) {
        self.activityId = activityId
        self.name = name
        self.category = category
        self.iconToken = iconToken
        self.colorToken = colorToken
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    var eventParameters: [String: Any] {
        [
            "activity_id": activityId,
            "activity_name": name,
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
