import Foundation

struct ChecklistItemDraft: Identifiable, Equatable {
    let id: String
    let itemId: String?
    var title: String
    var creditValue: ChecklistCreditValue

    init(
        id: String = UUID().uuidString,
        itemId: String? = nil,
        title: String = "",
        creditValue: ChecklistCreditValue = .halfCredit
    ) {
        self.id = id
        self.itemId = itemId
        self.title = title
        self.creditValue = creditValue
    }
}

struct ActivitySheetDraft {
    let name: String
    let category: ActivityCategory?
    let type: ActivityType
    let checklistItems: [ChecklistItemDraft]
    let sessionCount: Int
    let projectId: String?
}
