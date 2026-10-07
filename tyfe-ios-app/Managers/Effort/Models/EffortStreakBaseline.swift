import Foundation

struct EffortStreakBaseline: Codable, Hashable, Sendable {
    let userId: String
    let boundaryDay: LocalDay
    let current: Int
    let longest: Int
    let startedAt: Date?
    let lastEventAt: Date?
    let totalEvents: Int
    let grandfatheredToday: Bool
    var freezes: [EffortFreeze]
    var events: [EffortLegacyEvent]

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case boundaryDay = "boundary_day"
        case current
        case longest
        case startedAt = "started_at"
        case lastEventAt = "last_event_at"
        case totalEvents = "total_events"
        case grandfatheredToday = "grandfathered_today"
        case freezes
        case events
    }
}
