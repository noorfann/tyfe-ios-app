import Foundation

struct LocalDay: Codable, Hashable, Sendable, Identifiable {
    let year: Int
    let month: Int
    let day: Int
    let timeZoneIdentifier: String

    private enum CodingKeys: String, CodingKey {
        case year
        case month
        case day
        case timeZoneIdentifier = "time_zone_identifier"
    }

    var id: String {
        "\(timeZoneIdentifier):\(year)-\(month)-\(day)"
    }

    var startDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    init(
        year: Int,
        month: Int,
        day: Int,
        timeZoneIdentifier: String
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    init(containing date: Date, calendar: Calendar) {
        self.init(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date),
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }
}
