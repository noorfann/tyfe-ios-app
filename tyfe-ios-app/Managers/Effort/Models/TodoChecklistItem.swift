import Foundation

struct TodoChecklistItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var isCompleted: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted = "is_completed"
    }
}
