import Foundation

struct CircleMemberProgressModel: Identifiable, Codable, Hashable {
    let circleId: String
    let userId: String
    let displayName: String
    let avatarToken: String?
    let isOwner: Bool
    let latestDate: String?
    let todayPlanned: Int
    let todayCompleted: Int
    let sevenDayCompleted: Int
    let cheersToday: Int
    let progressUpdatedAt: Date?

    var id: String {
        userId
    }

    var completionPercentage: Double {
        guard todayPlanned > 0 else { return 0 }
        return min(Double(todayCompleted) / Double(todayPlanned), 1)
    }

    enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case userId = "user_id"
        case displayName = "display_name"
        case avatarToken = "avatar_token"
        case isOwner = "is_owner"
        case latestDate = "latest_date"
        case todayPlanned = "today_planned"
        case todayCompleted = "today_completed"
        case sevenDayCompleted = "seven_day_completed"
        case cheersToday = "cheers_today"
        case progressUpdatedAt = "progress_updated_at"
    }
}

extension LocalDay {
    var socialDateString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
