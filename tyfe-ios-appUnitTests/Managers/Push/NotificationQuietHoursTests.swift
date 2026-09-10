import Foundation
import Testing
@testable import tyfe_ios_app

struct NotificationQuietHoursTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test func overnightQuietHoursDelayLateNotificationUntilMorning() throws {
        let quietHours = NotificationQuietHours(
            startMinuteOfDay: 22 * 60,
            endMinuteOfDay: 7 * 60
        )
        let requestedDate = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 10,
            hour: 23,
            minute: 30
        )))
        let expectedDate = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 11,
            hour: 7
        )))

        #expect(quietHours.nextAllowedDate(for: requestedDate, calendar: calendar) == expectedDate)
    }

    @Test func notificationOutsideQuietHoursKeepsItsRequestedDate() throws {
        let quietHours = NotificationQuietHours(
            startMinuteOfDay: 22 * 60,
            endMinuteOfDay: 7 * 60
        )
        let requestedDate = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 10,
            hour: 14
        )))

        #expect(quietHours.nextAllowedDate(for: requestedDate, calendar: calendar) == requestedDate)
    }
}
