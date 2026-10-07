import Foundation

struct TodoCompletionRecord: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let taskId: String
    let title: String
    var projectId: String?
    let completedAt: Date
    let localDay: LocalDay
    var undoneAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case title
        case projectId = "project_id"
        case completedAt = "completed_at"
        case localDay = "local_day"
        case undoneAt = "undone_at"
    }
}
