import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct RepeatScheduleTests {

    private func localDay(year: Int, month: Int, day: Int) -> LocalDay {
        LocalDay(year: year, month: month, day: day, timeZoneIdentifier: "GMT")
    }

    @Test func dailyRecurrenceIsDueEveryDay() {
        let recurrence = RepeatSchedule(kind: .daily)

        #expect(recurrence.isDue(on: localDay(year: 2026, month: 3, day: 2)))
        #expect(recurrence.isDue(on: localDay(year: 2026, month: 3, day: 8)))
    }

    @Test func weeklyRecurrenceIsDueOnlyOnSelectedWeekdays() {
        let recurrence = RepeatSchedule(kind: .weekly, weekdays: [1, 3, 5])

        #expect(recurrence.isDue(on: localDay(year: 2026, month: 3, day: 2)))
        #expect(recurrence.isDue(on: localDay(year: 2026, month: 3, day: 4)))
        #expect(recurrence.isDue(on: localDay(year: 2026, month: 3, day: 6)))
        #expect(!recurrence.isDue(on: localDay(year: 2026, month: 3, day: 3)))
        #expect(!recurrence.isDue(on: localDay(year: 2026, month: 3, day: 8)))
    }

    @Test func isoWeekdayMappingFollowsGregorianDays() {
        #expect(RepeatSchedule.isoWeekday(for: localDay(year: 2026, month: 3, day: 2)) == 1)
        #expect(RepeatSchedule.isoWeekday(for: localDay(year: 2026, month: 3, day: 8)) == 7)
        #expect(RepeatSchedule.isoWeekday(fromCalendarWeekday: 1) == 7)
        #expect(RepeatSchedule.isoWeekday(fromCalendarWeekday: 2) == 1)
        #expect(RepeatSchedule.isoWeekday(fromCalendarWeekday: 7) == 6)
    }

    @Test func emptyWeeklySelectionIsNeverDue() {
        let recurrence = RepeatSchedule(kind: .weekly, weekdays: [])

        #expect(!recurrence.isDue(on: localDay(year: 2026, month: 3, day: 2)))
    }

    @Test func dailyRecurrenceDropsWeekdays() {
        let recurrence = RepeatSchedule(
            kind: .daily,
            weekdays: [3, 9]
        )

        #expect(recurrence.weekdays.isEmpty)
    }

    @Test func weeklyRecurrenceSortsAndDropsInvalidWeekdays() {
        let recurrence = RepeatSchedule(kind: .weekly, weekdays: [5, 1, 1, 9, 0, 3])

        #expect(recurrence.weekdays == [1, 3, 5])
    }

    @Test func displaySummaryNamesSelectedWeekdays() {
        #expect(RepeatSchedule(kind: .daily).displaySummary == "Every day")
        #expect(
            RepeatSchedule(kind: .weekly, weekdays: [5, 1, 3]).displaySummary == "Mon, Wed, Fri"
        )
        #expect(
            RepeatSchedule(kind: .weekly, weekdays: [1, 2, 3, 4, 5, 6, 7]).displaySummary == "Every day"
        )
    }

    @Test func recurrenceRoundTripsThroughJSON() throws {
        let recurrence = RepeatSchedule(kind: .weekly, weekdays: [2, 4])

        let restored = try JSONDecoder().decode(
            RepeatSchedule.self,
            from: JSONEncoder().encode(recurrence)
        )

        #expect(restored == recurrence)
    }

    @Test func legacyActivityJSONDecodesWithoutRecurrence() throws {
        let data = Data(#"{"activityId":"activity-legacy","name":"Study","createdAt":0}"#.utf8)

        let activity = try JSONDecoder().decode(ActivityModel.self, from: data)

        #expect(activity.legacyRecurrence == nil)
        #expect(activity.type == .session)
    }
}
