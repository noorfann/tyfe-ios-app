import Foundation

struct CircleInviteModel: Identifiable, Codable, Hashable {
    let inviteId: String
    let circleId: String
    let createdBy: String
    let code: String
    let expiresAt: Date
    let acceptedBy: String?
    let acceptedAt: Date?
    let revokedAt: Date?
    let createdAt: Date

    var id: String {
        inviteId
    }

    var isRedeemable: Bool {
        acceptedBy == nil && revokedAt == nil && expiresAt > .now
    }

    enum CodingKeys: String, CodingKey {
        case inviteId = "id"
        case circleId = "circle_id"
        case createdBy = "created_by"
        case code
        case expiresAt = "expires_at"
        case acceptedBy = "accepted_by"
        case acceptedAt = "accepted_at"
        case revokedAt = "revoked_at"
        case createdAt = "created_at"
    }
}
