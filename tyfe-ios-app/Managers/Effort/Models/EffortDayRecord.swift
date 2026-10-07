import Foundation

struct EffortDayRecord: Identifiable, Codable, Hashable, Sendable {
    let localDay: LocalDay
    var plannedSessions: Int
    var completedSessions: Int
    var outcome: EffortDayOutcome
    var id: String { localDay.id }

    private enum CodingKeys: String, CodingKey {
        case localDay = "local_day"
        case plannedSessions = "planned_sessions"
        case completedSessions = "completed_sessions"
        case outcome
    }
}
