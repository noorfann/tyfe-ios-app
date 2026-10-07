import Foundation

struct EffortLegacyEvent: Codable, Hashable, Sendable {
    let id: String
    let date: Date
    let timeZone: String
    let isFreeze: Bool
    let freezeId: String?

    var model: StreakEvent {
        StreakEvent(id: id, dateCreated: date, timezone: timeZone, isFreeze: isFreeze, freezeId: freezeId)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case timeZone = "time_zone"
        case isFreeze = "is_freeze"
        case freezeId = "freeze_id"
    }
}
