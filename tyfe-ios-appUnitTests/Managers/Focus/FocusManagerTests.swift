import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusManagerTests {

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

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

    @Test func completionCrossingMidnightStaysOnTheStartDay() throws {
        let clock = TestFocusClock(now: Date(timeIntervalSince1970: 1_756_943_400))
        let calendar = utcCalendar()
        let repository = MockFocusRepository()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let manager = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let activityId = ActivityModel.mock.activityId
        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 1)
        let startDay = manager.currentLocalDay
        let session = try #require(manager.startFocusSession(activityId: activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: TimeInterval(session.durationSeconds))
        let refresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.state == .completed)
        #expect(refresh.session.localDay == startDay)
        #expect(today.completedSessionCount(on: startDay) == 1)
        #expect(today.completedSessionCount(on: today.currentLocalDay) == 0)
    }

    @Test func reducingPlanWhileRunningFinalizesExcessCompletionAsBonus() throws {
        let clock = TestFocusClock()
        let calendar = utcCalendar()
        let repository = MockFocusRepository()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let manager = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let activityId = ActivityModel.mock.activityId
        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 2)

        let first = try #require(manager.startFocusSession(activityId: activityId))
        _ = try manager.beginFocusSession(focusSessionId: first.focusSessionId)
        clock.advance(by: TimeInterval(first.durationSeconds))
        _ = try manager.refreshFocusSession(focusSessionId: first.focusSessionId)

        let second = try #require(manager.startFocusSession(activityId: activityId))
        _ = today.updateDailyPlanItemCount(activityId: activityId, sessionCount: 1)
        _ = try manager.beginFocusSession(focusSessionId: second.focusSessionId)
        clock.advance(by: TimeInterval(second.durationSeconds))
        let refresh = try manager.refreshFocusSession(focusSessionId: second.focusSessionId)

        #expect(refresh.session.isBonusSession)
        #expect(today.progress(for: today.currentLocalDay)?.plannedCompletionCount == 1)
        #expect(today.progress(for: today.currentLocalDay)?.bonusCompletionCount == 1)
    }

    @Test func unplannedCompletionRemainsBonus() throws {
        let clock = TestFocusClock()
        let calendar = utcCalendar()
        let repository = MockFocusRepository()
        let manager = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))

        let completed = try manager.refreshFocusSession(focusSessionId: session.focusSessionId).session

        #expect(completed.isBonusSession)
        #expect(manager.rewardCredits == 3)
        #expect(manager.progression.totalXP == 50)
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

    @Test func relaunchRestoresRunningSessionAndDerivesRemainingFromClock() throws {
        let clock = TestFocusClock()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFocusRepositoryPersistence(fileURL: fileURL)
        let firstRepository = LocalFocusRepository(persistence: persistence)
        let firstManager = FocusManager(repository: firstRepository, clock: clock)
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        let runningSession = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 90)

        let relaunchedRepository = LocalFocusRepository(persistence: persistence)
        let reloadedSession = try #require(
            relaunchedRepository.snapshot.focusSessions.first {
                $0.focusSessionId == session.focusSessionId
            }
        )
        #expect(reloadedSession.focusEndsAt != nil)
        #expect(reloadedSession.focusEndsAt == runningSession.focusEndsAt)

        let relaunchedManager = FocusManager(repository: relaunchedRepository, clock: clock)
        let refresh = try relaunchedManager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.focusSessionId == session.focusSessionId)
        #expect(refresh.session.state == .running)
        #expect(refresh.remainingFocusSeconds == 1_410)
        #expect(relaunchedManager.activeFocusSession?.focusSessionId == session.focusSessionId)
    }

    @Test func refreshBeforeDeadlineDoesNotCompleteSession() throws {
        let clock = TestFocusClock()
        let manager = FocusManager(repository: MockFocusRepository(), clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 1_499)
        let refresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.state == .running)
        #expect(refresh.remainingFocusSeconds == 1)
        #expect(manager.creditLedger.isEmpty)
        #expect(manager.progressionAwards.isEmpty)
    }

    @Test func relaunchAtDeadlineAwardsCompletionExactlyOnce() throws {
        let clock = TestFocusClock()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFocusRepositoryPersistence(fileURL: fileURL)
        let firstRepository = LocalFocusRepository(persistence: persistence)
        let firstManager = FocusManager(repository: firstRepository, clock: clock)
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))

        let relaunchedManager = FocusManager(
            repository: LocalFocusRepository(persistence: persistence),
            clock: clock
        )
        let firstRefresh = try relaunchedManager.refreshFocusSession(focusSessionId: session.focusSessionId)
        let recreatedRepository = LocalFocusRepository(
            persistence: LocalFocusRepositoryPersistence(fileURL: fileURL)
        )
        let recreatedManager = FocusManager(repository: recreatedRepository, clock: clock)
        let secondRefresh = try recreatedManager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(firstRefresh.session.state == .completed)
        #expect(secondRefresh.session.state == .completed)
        #expect(recreatedManager.creditLedger.count == 1)
        #expect(recreatedManager.progressionAwards.count == 1)
        #expect(recreatedManager.completedSessionCount == 1)
        #expect(recreatedManager.rewardCredits == 3)
        #expect(recreatedManager.progression.totalXP == 50)
    }

    @Test func relaunchRestoresPausedSessionWithoutAwards() throws {
        let clock = TestFocusClock()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFocusRepositoryPersistence(fileURL: fileURL)
        let firstManager = FocusManager(
            repository: LocalFocusRepository(persistence: persistence),
            clock: clock
        )
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: 60)
        _ = try firstManager.pauseFocusSession(focusSessionId: session.focusSessionId)

        let relaunchedManager = FocusManager(
            repository: LocalFocusRepository(persistence: persistence),
            clock: clock
        )
        let refresh = try relaunchedManager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.focusSessionId == session.focusSessionId)
        #expect(refresh.session.state == .paused)
        #expect(refresh.completion == nil)
        #expect(relaunchedManager.rewardCredits == 2)
        #expect(relaunchedManager.progression.totalXP == 40)
    }

    @Test func terminalSessionsReportNoRemainingFocusTime() throws {
        let clock = TestFocusClock()
        let deadline = clock.now.addingTimeInterval(60)
        let snapshot = FocusManagerSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: nil,
            completedSessionCount: 1,
            rewardCredits: 2,
            progression: .mock,
            focusSessions: [
                FocusSessionModel.completedMock.updated(
                    state: .completed,
                    focusEndsAt: deadline
                ),
                FocusSessionModel.abandonedMock.updated(
                    state: .abandoned,
                    focusEndsAt: deadline
                )
            ],
            creditLedger: [],
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 3
        )
        let manager = FocusManager(
            repository: MockFocusRepository(snapshot: snapshot),
            clock: clock
        )

        let completedRefresh = try manager.refreshFocusSession(
            focusSessionId: FocusSessionModel.completedMock.focusSessionId
        )
        let abandonedRefresh = try manager.refreshFocusSession(
            focusSessionId: FocusSessionModel.abandonedMock.focusSessionId
        )

        #expect(completedRefresh.remainingFocusSeconds == 0)
        #expect(abandonedRefresh.remainingFocusSeconds == 0)
    }

    @Test func legacyPausedSessionUsesStartedAtFallbackForRemainingTime() throws {
        let clock = TestFocusClock()
        clock.advance(by: 60)
        let session = FocusSessionModel(
            focusSessionId: "focus-session-paused-legacy",
            activityId: ActivityModel.mock.activityId,
            state: .paused,
            startedAt: clock.now.addingTimeInterval(-60),
            pausedAt: clock.now.addingTimeInterval(-10),
            focusEndsAt: nil,
            pauseUsed: true,
            pauseRemainingSeconds: 290
        )
        let snapshot = FocusManagerSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: nil,
            completedSessionCount: 0,
            rewardCredits: 2,
            progression: .mock,
            focusSessions: [session],
            creditLedger: [],
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 2
        )
        let manager = FocusManager(
            repository: MockFocusRepository(snapshot: snapshot),
            clock: clock
        )

        let refresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.state == .paused)
        #expect(refresh.session.focusEndsAt == nil)
        #expect(refresh.remainingFocusSeconds == session.durationSeconds - 60)
        #expect(refresh.completion == nil)
    }

#if MOCK
    @Test func mockCompletionFinishesAReadySessionAndAwardsTheSameRewards() throws {
        let manager = FocusManager(repository: MockFocusRepository(), clock: TestFocusClock())
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))

        let completed = try manager.markFocusSessionCompleteForTesting(
            focusSessionId: session.focusSessionId
        )

        #expect(completed.state == .completed)
        #expect(manager.rewardCredits == 3)
        #expect(manager.progression.totalXP == 50)
        #expect(manager.completedSessionCount == 1)
    }
#endif
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
