import Foundation

struct CircleMembershipModel: Identifiable, Codable, Hashable {
    let membershipId: String
    let circleId: String
    let userId: String
    let role: CircleMemberRole
    let sharingPaused: Bool
    let joinedAt: Date

    var id: String {
        membershipId
    }

    enum CodingKeys: String, CodingKey {
        case membershipId = "id"
        case circleId = "circle_id"
        case userId = "user_id"
        case role
        case sharingPaused = "sharing_paused"
        case joinedAt = "joined_at"
    }
}

struct CircleMemberModel: Identifiable, Hashable {
    let userId: String
    let displayName: String
    let avatarToken: String?
    let role: CircleMemberRole
    let sharingPaused: Bool
    let joinedAt: Date

    var id: String {
        userId
    }
}
