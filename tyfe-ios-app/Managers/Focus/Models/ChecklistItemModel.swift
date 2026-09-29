import Foundation

enum ChecklistCreditValue: String, Codable, CaseIterable, Hashable, Sendable {
    case halfCredit
    case oneCredit
    case oneAndHalfCredits
    case twoCredits

    var creditValue: Decimal {
        switch self {
        case .halfCredit: return Decimal(string: "0.5") ?? 0.5
        case .oneCredit: return 1
        case .oneAndHalfCredits: return Decimal(string: "1.5") ?? 1.5
        case .twoCredits: return 2
        }
    }

    var displayName: String {
        switch self {
        case .halfCredit: return "0.5"
        case .oneCredit: return "1"
        case .oneAndHalfCredits: return "1.5"
        case .twoCredits: return "2"
        }
    }

    var creditLabel: String {
        creditValue == 1 ? "1 Credit" : "\(displayName) Credits"
    }
}

struct ChecklistItemModel: Identifiable, Codable, Hashable {
    let itemId: String
    let activityId: String
    let title: String
    let creditValue: ChecklistCreditValue
    let createdAt: Date

    var id: String {
        itemId
    }

    init(
        itemId: String,
        activityId: String,
        title: String,
        creditValue: ChecklistCreditValue = .halfCredit,
        createdAt: Date
    ) {
        self.itemId = itemId
        self.activityId = activityId
        self.title = title
        self.creditValue = creditValue
        self.createdAt = createdAt
    }

    var eventParameters: [String: Any] {
        [
            "checklist_item_id": itemId,
            "checklist_item_activity_id": activityId,
            "checklist_item_title": title,
            "checklist_item_credit_value": creditValue.rawValue
        ]
    }
}

struct ChecklistItemCompletionModel: Identifiable, Codable, Hashable {
    let completionId: String
    let itemId: String
    let activityId: String
    let localDay: LocalDay
    let itemTitleSnapshot: String
    let creditValueSnapshot: ChecklistCreditValue
    let completedAt: Date

    var id: String {
        completionId
    }

    init(
        completionId: String,
        itemId: String,
        activityId: String,
        localDay: LocalDay,
        itemTitleSnapshot: String,
        creditValueSnapshot: ChecklistCreditValue,
        completedAt: Date
    ) {
        self.completionId = completionId
        self.itemId = itemId
        self.activityId = activityId
        self.localDay = localDay
        self.itemTitleSnapshot = itemTitleSnapshot
        self.creditValueSnapshot = creditValueSnapshot
        self.completedAt = completedAt
    }
}
