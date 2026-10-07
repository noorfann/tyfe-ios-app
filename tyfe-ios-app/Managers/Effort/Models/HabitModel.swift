import Foundation

struct HabitModel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var iconToken: String
    var colorToken: String
    var projectId: String?
    let createdAt: Date
    var revisions: [HabitRevision]

    func revision(on day: LocalDay) -> HabitRevision? {
        revisions.last { $0.effectiveDay.startDate <= day.startDate }
    }

    func isActive(on day: LocalDay) -> Bool {
        revision(on: day).map { !$0.isArchived } ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case iconToken = "icon_token"
        case colorToken = "color_token"
        case projectId = "project_id"
        case createdAt = "created_at"
        case revisions
    }
}
