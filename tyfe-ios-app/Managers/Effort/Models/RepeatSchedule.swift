import Foundation

enum RepeatScheduleKind: String, Codable, CaseIterable, Hashable, Sendable {
    case daily
    case weekly
}

struct RepeatSchedule: Codable, Hashable, Sendable {
    var kind: RepeatScheduleKind
    var weekdays: [Int]

    private static let weekdayShortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    init(
        kind: RepeatScheduleKind,
        weekdays: [Int] = []
    ) {
        self.kind = kind
        self.weekdays = Self.normalizedWeekdays(weekdays, kind: kind)
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case weekdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decodeIfPresent(RepeatScheduleKind.self, forKey: .kind) ?? .daily
        self.init(
            kind: kind,
            weekdays: try container.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(weekdays, forKey: .weekdays)
    }

    func isDue(on localDay: LocalDay) -> Bool {
        switch kind {
        case .daily:
            return true
        case .weekly:
            guard let isoWeekday = Self.isoWeekday(for: localDay) else { return false }
            return weekdays.contains(isoWeekday)
        }
    }

    var displaySummary: String {
        switch kind {
        case .daily:
            return "Every day"
        case .weekly:
            guard !weekdays.isEmpty else { return "No days" }
            guard weekdays.count < 7 else { return "Every day" }
            return weekdays
                .map { Self.weekdayShortName(forISO: $0) }
                .joined(separator: ", ")
        }
    }

    static func isoWeekday(for localDay: LocalDay) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: localDay.timeZoneIdentifier) ?? .current
        return isoWeekday(fromCalendarWeekday: calendar.component(.weekday, from: localDay.startDate))
    }

    static func isoWeekday(fromCalendarWeekday weekday: Int) -> Int {
        ((weekday + 5) % 7) + 1
    }

    static func weekdayShortName(forISO weekday: Int) -> String {
        guard weekdayShortNames.indices.contains(weekday - 1) else { return "" }
        return weekdayShortNames[weekday - 1]
    }

    private static func normalizedWeekdays(
        _ weekdays: [Int],
        kind: RepeatScheduleKind
    ) -> [Int] {
        guard kind == .weekly else { return [] }
        return Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }
}
