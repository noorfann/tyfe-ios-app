import Foundation

/// Compatibility data used only to preserve historical effort during the version 9 migration.
struct LegacyActivityRecurrence: Codable, Hashable {
    var kind: RepeatScheduleKind
    var weekdays: [Int] = []
    var defaultSessionCount: Int = 1

    init(kind: RepeatScheduleKind, weekdays: [Int] = [], defaultSessionCount: Int = 1) {
        self.kind = kind
        self.weekdays = weekdays
        self.defaultSessionCount = max(defaultSessionCount, 1)
    }

    private enum CodingKeys: String, CodingKey {
        case kind, weekdays, defaultSessionCount
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try values.decodeIfPresent(RepeatScheduleKind.self, forKey: .kind) ?? .daily,
            weekdays: try values.decodeIfPresent([Int].self, forKey: .weekdays) ?? [],
            defaultSessionCount: try values.decodeIfPresent(Int.self, forKey: .defaultSessionCount) ?? 1
        )
    }

    func isDue(on day: LocalDay) -> Bool {
        RepeatSchedule(kind: kind, weekdays: weekdays).isDue(on: day)
    }
}
