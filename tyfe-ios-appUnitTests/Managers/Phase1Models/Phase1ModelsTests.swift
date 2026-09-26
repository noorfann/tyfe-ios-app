import Foundation
import Testing
@testable import tyfe_ios_app

struct Phase1ModelsTests {

    @Test func rewardTiersExposeProductData() {
        #expect(RewardDurationTier.allCases == [
            .tenMinutes,
            .twentyMinutes,
            .thirtyMinutes,
            .fortyMinutes,
            .fiftyMinutes,
            .sixtyMinutes
        ])
        #expect(RewardDurationTier.tenMinutes.durationMinutes == 10)
        #expect(RewardDurationTier.tenMinutes.creditCost == 1)
        #expect(RewardDurationTier.thirtyMinutes.durationMinutes == 30)
        #expect(RewardDurationTier.thirtyMinutes.creditCost == 3)
        #expect(RewardDurationTier.sixtyMinutes.durationMinutes == 60)
        #expect(RewardDurationTier.sixtyMinutes.creditCost == 6)
        #expect(RewardDurationTier.thirtyMinutes.creditLabel == "3 Credits")
    }

    @Test func dailyPlanKeepsTimeBlocksOptional() {
        #expect(DailyPlanModel.mock.timeBlocks == nil)
        #expect(DailyPlanModel.timedMock.timeBlocks?.count == 1)
        #expect(DailyPlanModel.timedMock.timeBlocks?.first?.durationMinutes == 25)
    }

    @Test func localDayCapturesDateAndTimezoneIdentity() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let beforeMidnight = Date(timeIntervalSince1970: 1_756_943_999)
        let afterMidnight = Date(timeIntervalSince1970: 1_756_944_000)

        let firstDay = LocalDay(containing: beforeMidnight, calendar: calendar)
        let secondDay = LocalDay(containing: afterMidnight, calendar: calendar)

        #expect(firstDay != secondDay)
        #expect(firstDay.timeZoneIdentifier == "GMT")
        #expect(firstDay.startDate < secondDay.startDate)
    }

    @Test func localDayOffsetsByCalendarDayAcrossDaylightSavingTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let dayBeforeDST = LocalDay(
            year: 2026,
            month: 3,
            day: 7,
            timeZoneIdentifier: calendar.timeZone.identifier
        )

        let dayAfterDST = dayBeforeDST.adding(days: 2)

        #expect(dayAfterDST.year == 2026)
        #expect(dayAfterDST.month == 3)
        #expect(dayAfterDST.day == 9)
        #expect(dayAfterDST.timeZoneIdentifier == calendar.timeZone.identifier)
        #expect(dayAfterDST.startDate.timeIntervalSince(dayBeforeDST.startDate) == 47 * 60 * 60)
    }

    @Test func focusFixtureUsesFixedDurationAndStableIdentity() throws {
        let session = FocusSessionModel.mock
        #expect(session.id == session.focusSessionId)
        #expect(session.durationMinutes == 25)
        #expect(FocusSessionModel.restDurationSeconds == 300)

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(FocusSessionModel.self, from: encoded)
        #expect(decoded == session)
    }

    @Test func abandonedFixtureDoesNotQualifyForAwards() {
        #expect(FocusSessionModel.abandonedMock.state == .abandoned)
        #expect(FocusSessionModel.abandonedMock.earnsCompletionAwards == false)
    }
}
