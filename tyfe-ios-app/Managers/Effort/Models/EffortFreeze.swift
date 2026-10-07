import Foundation

struct EffortFreeze: Codable, Hashable, Sendable {
    let id: String
    let earnedAt: Date?
    var usedAt: Date?
    let expiresAt: Date?
    var earningDay: LocalDay?
    var protectedDay: LocalDay?

    var model: StreakFreeze {
        StreakFreeze(id: id, dateEarned: earnedAt, dateUsed: usedAt, dateExpires: expiresAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case earnedAt = "earned_at"
        case usedAt = "used_at"
        case expiresAt = "expires_at"
        case earningDay = "earning_day"
        case protectedDay = "protected_day"
    }
}
