import Foundation

struct TodoScheduleRevision: Codable, Hashable, Sendable {
    let effectiveDay: LocalDay
    var schedule: RepeatSchedule?

    private enum CodingKeys: String, CodingKey {
        case effectiveDay = "effective_day"
        case schedule
    }
}
