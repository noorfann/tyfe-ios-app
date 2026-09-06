import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusManagerTests {

    @Test func beginningAndPausingAFocusSessionUsesPersistedTime() throws {
        let clock = TestFocusClock()
        let repository = MockFocusRepository()
        let manager = FocusManager(repository: repository, clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))

        let running = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        #expect(running.state == .running)
        #expect(try manager.refreshFocusSession(focusSessionId: session.focusSessionId).remainingFocusSeconds == 1_500)

        clock.advance(by: 120)
        let paused = try manager.pauseFocusSession(focusSessionId: session.focusSessionId)
        #expect(paused.state == .paused)
        #expect(paused.pauseUsed)
        #expect(try manager.refreshFocusSession(focusSessionId: session.focusSessionId).remainingFocusSeconds == 1_380)
        #expect(throws: FocusManagerError.pauseAlreadyUsed) {
            try manager.pauseFocusSession(focusSessionId: session.focusSessionId)
        }
    }

    @Test func resumingShiftsTheDeadlineByTheTimeSpentPaused() throws {
        let clock = TestFocusClock()
        let manager = FocusManager(repository: MockFocusRepository(), clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: 1_200)
        _ = try manager.pauseFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 120)
        let resumed = try manager.resumeFocusSession(focusSessionId: session.focusSessionId)

        #expect(resumed.state == .running)
        #expect(resumed.pauseRemainingSeconds == 180)
        #expect(try manager.refreshFocusSession(focusSessionId: session.focusSessionId).remainingFocusSeconds == 180)
    }

    @Test func naturalCompletionAwardsCreditAndXPExactlyOnce() throws {
        let clock = TestFocusClock()
        let manager = FocusManager(repository: MockFocusRepository(), clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 1_500)
        let firstRefresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)
        let secondRefresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(firstRefresh.session.state == .completed)
        #expect(firstRefresh.completion?.rewardCreditsAwarded == 1)
        #expect(firstRefresh.completion?.xpAwarded == 10)
        #expect(secondRefresh.session.state == .completed)
        #expect(secondRefresh.completion?.rewardCreditsAwarded == 1)
        #expect(manager.rewardCredits == 3)
        #expect(manager.progression.totalXP == 50)
        #expect(manager.completedSessionCount == 1)
        #expect(manager.creditLedger.count == 1)
        #expect(manager.progressionAwards.count == 1)
    }

    @Test func abandoningAFocusSessionDoesNotAwardRewards() throws {
        let manager = FocusManager(repository: MockFocusRepository(), clock: TestFocusClock())
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        let abandoned = try manager.abandonFocusSession(focusSessionId: session.focusSessionId)

        #expect(abandoned.state == .abandoned)
        #expect(manager.rewardCredits == 2)
        #expect(manager.progression.totalXP == 40)
        #expect(manager.completedSessionCount == 0)
        #expect(manager.activeFocusSession == nil)
    }

    @Test func persistedActiveSessionIsRecoveredWithoutCreatingADuplicate() throws {
        let clock = TestFocusClock()
        let repository = MockFocusRepository()
        let firstManager = FocusManager(repository: repository, clock: clock)
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)

        let relaunchedManager = FocusManager(repository: repository, clock: clock)

        #expect(relaunchedManager.activeFocusSession?.focusSessionId == session.focusSessionId)
        #expect(relaunchedManager.focusSessions.count == 1)
        #expect(relaunchedManager.startFocusSession(activityId: ActivityModel.mock.activityId)?.focusSessionId == session.focusSessionId)
    }
}

@MainActor
final class TestFocusClock: FocusClock {
    var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_756_944_000)) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
