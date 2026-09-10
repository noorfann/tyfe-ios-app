import Foundation
import Testing
@testable import tyfe_ios_app

struct Phase1ModelsTests {

    @Test func rewardTiersExposeProductData() {
        #expect(RewardDurationTier.fifteenMinutes.durationMinutes == 15)
        #expect(RewardDurationTier.fifteenMinutes.creditCost == 1)
        #expect(RewardDurationTier.thirtyMinutes.durationMinutes == 30)
        #expect(RewardDurationTier.thirtyMinutes.creditCost == 2)
        #expect(RewardDurationTier.sixtyMinutes.durationMinutes == 60)
        #expect(RewardDurationTier.sixtyMinutes.creditCost == 4)
    }

    @Test func progressionCalculatesLevelBoundaries() {
        let inLevel = ProgressionSnapshotModel(totalXP: 40)
        #expect(inLevel.level == 1)
        #expect(inLevel.currentLevelXP == 40)
        #expect(inLevel.xpToNextLevel == 60)

        let levelBoundary = ProgressionSnapshotModel(totalXP: 100)
        #expect(levelBoundary.level == 2)
        #expect(levelBoundary.currentLevelXP == 0)
        #expect(levelBoundary.xpToNextLevel == 100)
    }

    @Test func cosmeticMilestoneUnlocksAtTwoHundredXP() {
        let progression = ProgressionSnapshotModel(totalXP: 200)
        #expect(progression.level == 3)
        #expect(progression.unlockedCosmeticIds.contains("cosmetic-200"))
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

    @Test func focusFixtureUsesFixedDurationAndStableIdentity() throws {
        let session = FocusSessionModel.mock
        #expect(session.id == session.focusSessionId)
        #expect(session.durationMinutes == 25)
        #expect(session.pauseAllowanceSeconds == 300)

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(FocusSessionModel.self, from: encoded)
        #expect(decoded == session)
    }

    @Test func abandonedFixtureDoesNotQualifyForAwards() {
        #expect(FocusSessionModel.abandonedMock.state == .abandoned)
        #expect(FocusSessionModel.abandonedMock.earnsCompletionAwards == false)
    }

    @Test func completedAndBonusAwardsUseTheSameTenXPContract() {
        #expect(ProgressionAwardModel.mock.points == 10)
        #expect(ProgressionAwardModel.mock.source == .focusSession)
        #expect(ProgressionAwardModel.bonusMock.points == 10)
        #expect(ProgressionAwardModel.bonusMock.source == .bonusSession)
    }
}
