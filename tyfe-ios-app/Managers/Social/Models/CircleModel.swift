import Foundation

enum CircleMemberRole: String, Codable, CaseIterable, Hashable {
    case owner
    case member
}

struct CircleModel: Identifiable, Codable, Hashable {
    let circleId: String
    let name: String
    let ownerId: String
    let createdAt: Date
    let updatedAt: Date

    var id: String {
        circleId
    }

    enum CodingKeys: String, CodingKey {
        case circleId = "id"
        case name
        case ownerId = "owner_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SocialProfileModel: Identifiable, Codable, Hashable {
    let userId: String
    let displayName: String
    let avatarToken: String?

    var id: String {
        userId
    }

    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case displayName = "display_name"
        case avatarToken = "avatar_token"
    }
}
