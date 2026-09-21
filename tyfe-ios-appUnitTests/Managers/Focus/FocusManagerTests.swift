import Foundation
import Observation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusManagerTests {

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func beginningAFocusSessionUsesPersistedTime() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let manager = FocusManager(repository: repository, clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))

        let running = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        #expect(running.state == .running)
        #expect(try manager.refreshFocusSession(focusSessionId: session.focusSessionId).remainingFocusSeconds == 1_500)
    }

    @Test func beginningAFocusSessionStartsOneLiveActivityAfterPersistence() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingFocusLiveActivityScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            liveActivityScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))

        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        #expect(scheduler.startedSessions.map(\.focusSessionId) == [session.focusSessionId])
    }

    @Test func completedFocusSessionOffersAndPersistsFiveMinuteRest() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingLocalTimerNotificationScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            notificationScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: TimeInterval(session.durationSeconds))
        let completed = try manager.refreshFocusSession(focusSessionId: session.focusSessionId).session
        #expect(completed.restState == .pending)

        let resting = try manager.startFocusRest(focusSessionId: session.focusSessionId)
        #expect(resting.isResting)
        #expect(resting.restEndsAt == clock.now.addingTimeInterval(300))
        #expect(manager.activeFocusSession?.focusSessionId == session.focusSessionId)
        #expect(scheduler.scheduledFocusRestSessions.map(\.focusSessionId) == [session.focusSessionId])

        clock.advance(by: 120)
        let duringRest = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)
        #expect(duringRest.remainingRestSeconds == 180)

        clock.advance(by: 180)
        let finished = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)
        #expect(finished.session.restState == .completed)
        #expect(finished.remainingRestSeconds == 0)
        #expect(manager.activeFocusSession == nil)
        #expect(scheduler.cancelledFocusRestSessionIds == [session.focusSessionId])
    }

    @Test func skippingRestStartsAnotherSession() throws {
        let clock = TestFocusClock()
        let manager = FocusManager(repository: MockLocalAppRepository(), clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        let nextSession = try manager.startAnotherFocusSession(activityId: session.activityId)

        #expect(nextSession.state == .ready)
        #expect(manager.focusSessions.first(where: { $0.focusSessionId == session.focusSessionId })?.restState == .skipped)
    }

    @Test func naturalCompletionAwardsCreditExactlyOnce() throws {
        let clock = TestFocusClock()
        let manager = FocusManager(repository: MockLocalAppRepository(), clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 1_500)
        let firstRefresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)
        let secondRefresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(firstRefresh.session.state == .completed)
        #expect(firstRefresh.completion?.rewardCreditsAwarded == 1)
        #expect(secondRefresh.session.state == .completed)
        #expect(secondRefresh.completion?.rewardCreditsAwarded == 1)
        #expect(manager.rewardCredits == 1)
        #expect(manager.rewardCredits == manager.creditLedger.reduce(0) { $0 + $1.amount })
        #expect(manager.completedSessionCount == 1)
        #expect(manager.creditLedger.count == 1)
    }

    @Test func naturalCompletionEndsTheLiveActivityAfterAwardingCredit() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingFocusLiveActivityScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            liveActivityScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(scheduler.endedSessions.count == 1)
        #expect(scheduler.endedSessions.first?.session.focusSessionId == session.focusSessionId)
        #expect(scheduler.endedSessions.first?.reason == .completed)
    }

    @Test func abandoningFocusEndsTheLiveActivityWithoutCompletion() throws {
        let scheduler = RecordingFocusLiveActivityScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            liveActivityScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        _ = try manager.abandonFocusSession(focusSessionId: session.focusSessionId)

        #expect(scheduler.endedSessions.count == 1)
        #expect(scheduler.endedSessions.first?.reason == .abandoned)
        #expect(manager.rewardCredits == 0)
    }

    @Test func runningSessionIsReconciledWhenFocusManagerIsRecreated() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let firstScheduler = RecordingFocusLiveActivityScheduler()
        let firstManager = FocusManager(
            repository: repository,
            clock: clock,
            liveActivityScheduler: firstScheduler
        )
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)

        let secondScheduler = RecordingFocusLiveActivityScheduler()
        _ = FocusManager(
            repository: repository,
            clock: clock,
            liveActivityScheduler: secondScheduler
        )

        #expect(
            secondScheduler.reconciledSessions.compactMap { $0 }.last?.focusSessionId
                == session.focusSessionId
        )
    }

    @Test func runningSessionIsReconciledWhenTheAppReturnsToTheForeground() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingFocusLiveActivityScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            liveActivityScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        manager.reconcileLiveActivity()

        let reconciledSession = try #require(scheduler.reconciledSessions.last ?? nil)
        #expect(reconciledSession.focusSessionId == session.focusSessionId)
    }

    @Test func expiredRunningSessionIsNotRecreatedWhenTheAppReturnsToTheForeground() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingFocusLiveActivityScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            liveActivityScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))

        manager.reconcileLiveActivity()

        #expect(scheduler.reconciledSessions.last == nil)
    }

    @Test func completionCrossingMidnightStaysOnTheStartDay() throws {
        let clock = TestFocusClock(now: Date(timeIntervalSince1970: 1_756_943_400))
        let calendar = utcCalendar()
        let repository = MockLocalAppRepository()
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

    @Test func completionAfterMidnightResetsTheDayBeforeAwardingCredit() throws {
        let clock = TestFocusClock(now: Date(timeIntervalSince1970: 1_756_943_400))
        let calendar = utcCalendar()
        var snapshot = LocalAppSnapshot.mock
        snapshot.creditLedger = .openingBalance(
            amount: 2,
            recordedAt: Date(timeIntervalSince1970: 1_756_942_800)
        )
        let repository = MockLocalAppRepository(snapshot: snapshot)
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let manager = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let activityId = ActivityModel.mock.activityId
        _ = today.addActivityToDailyPlan(activityId: activityId, sessionCount: 1)
        let session = try #require(manager.startFocusSession(activityId: activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: TimeInterval(session.durationSeconds))
        let refresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.state == .completed)
        #expect(refresh.completion?.rewardCreditsAwarded == 1)
        #expect(refresh.completion?.rewardCreditBalance == 1)
        #expect(repository.snapshot.creditLedger.entries.contains {
            $0.source == .dayReset && $0.amount == -2
        })
    }

    @Test func reducingPlanWhileRunningFinalizesExcessCompletionAsBonus() throws {
        let clock = TestFocusClock()
        let calendar = utcCalendar()
        let repository = MockLocalAppRepository()
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
        let repository = MockLocalAppRepository()
        let manager = FocusManager(repository: repository, clock: clock, calendar: calendar)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))

        let completed = try manager.refreshFocusSession(focusSessionId: session.focusSessionId).session

        #expect(completed.isBonusSession)
        #expect(manager.rewardCredits == 1)
    }

    @Test func abandoningAFocusSessionDoesNotAwardRewards() throws {
        let manager = FocusManager(repository: MockLocalAppRepository(), clock: TestFocusClock())
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        let abandoned = try manager.abandonFocusSession(focusSessionId: session.focusSessionId)

        #expect(abandoned.state == .abandoned)
        #expect(manager.rewardCredits == 0)
        #expect(manager.completedSessionCount == 0)
        #expect(manager.activeFocusSession == nil)
    }

    @Test func timerLifecycleSchedulesReschedulesAndCancelsCompletionNotification() throws {
        let clock = TestFocusClock()
        let scheduler = RecordingLocalTimerNotificationScheduler()
        let manager = FocusManager(
            repository: MockLocalAppRepository(),
            clock: clock,
            notificationScheduler: scheduler
        )
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))

        let running = try manager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: 60)
        _ = try manager.abandonFocusSession(focusSessionId: session.focusSessionId)

        #expect(scheduler.scheduledFocusSessions.map(\.focusEndsAt) == [running.focusEndsAt])
        #expect(scheduler.cancelledFocusSessionIds == [session.focusSessionId])
    }

    @Test func persistedActiveSessionIsRecoveredWithoutCreatingADuplicate() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository()
        let firstManager = FocusManager(repository: repository, clock: clock)
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)

        let relaunchedManager = FocusManager(repository: repository, clock: clock)

        #expect(relaunchedManager.activeFocusSession?.focusSessionId == session.focusSessionId)
        #expect(relaunchedManager.focusSessions.count == 1)
        #expect(relaunchedManager.startFocusSession(activityId: ActivityModel.mock.activityId)?.focusSessionId == session.focusSessionId)
    }

    @Test func focusSessionChangesInvalidateObserversAcrossTheLifecycle() throws {
        let manager = FocusManager(repository: MockLocalAppRepository(), clock: TestFocusClock())
        let recorder = FocusObservationRecorder()

        func observeActiveSession() {
            withObservationTracking {
                _ = manager.activeFocusSession
            } onChange: {
                recorder.count += 1
            }
        }

        observeActiveSession()
        let ready = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        #expect(recorder.count == 1)

        observeActiveSession()
        _ = try manager.beginFocusSession(focusSessionId: ready.focusSessionId)
        #expect(recorder.count == 2)

        observeActiveSession()
        _ = try manager.abandonFocusSession(focusSessionId: ready.focusSessionId)
        #expect(recorder.count == 3)
        #expect(manager.activeFocusSession == nil)
    }

    @Test func relaunchRestoresRunningSessionAndDerivesRemainingFromClock() throws {
        let clock = TestFocusClock()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFileRepositoryPersistence(fileURL: fileURL)
        let firstRepository = LocalFileRepository(persistence: persistence)
        let firstManager = FocusManager(repository: firstRepository, clock: clock)
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        let runningSession = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 90)

        let relaunchedRepository = LocalFileRepository(persistence: persistence)
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
        let manager = FocusManager(repository: MockLocalAppRepository(), clock: clock)
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try manager.beginFocusSession(focusSessionId: session.focusSessionId)

        clock.advance(by: 1_499)
        let refresh = try manager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.state == .running)
        #expect(refresh.remainingFocusSeconds == 1)
        #expect(manager.creditLedger.isEmpty)
    }

    @Test func relaunchAtDeadlineAwardsCompletionExactlyOnce() throws {
        let clock = TestFocusClock()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFileRepositoryPersistence(fileURL: fileURL)
        let firstRepository = LocalFileRepository(persistence: persistence)
        let firstManager = FocusManager(repository: firstRepository, clock: clock)
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))

        let relaunchedManager = FocusManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: clock
        )
        let firstRefresh = try relaunchedManager.refreshFocusSession(focusSessionId: session.focusSessionId)
        let recreatedRepository = LocalFileRepository(
            persistence: LocalFileRepositoryPersistence(fileURL: fileURL)
        )
        let recreatedManager = FocusManager(repository: recreatedRepository, clock: clock)
        let secondRefresh = try recreatedManager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(firstRefresh.session.state == .completed)
        #expect(secondRefresh.session.state == .completed)
        #expect(recreatedManager.creditLedger.count == 1)
        #expect(recreatedManager.completedSessionCount == 1)
        #expect(recreatedManager.rewardCredits == 1)
    }

    @Test func relaunchRestoresActiveRestAndDerivesRemainingFromClock() throws {
        let clock = TestFocusClock()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFileRepositoryPersistence(fileURL: fileURL)
        let firstManager = FocusManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: clock
        )
        let session = try #require(firstManager.startFocusSession(activityId: ActivityModel.mock.activityId))
        _ = try firstManager.beginFocusSession(focusSessionId: session.focusSessionId)
        clock.advance(by: TimeInterval(session.durationSeconds))
        _ = try firstManager.refreshFocusSession(focusSessionId: session.focusSessionId)
        _ = try firstManager.startFocusRest(focusSessionId: session.focusSessionId)

        clock.advance(by: 90)
        let relaunchedManager = FocusManager(
            repository: LocalFileRepository(persistence: persistence),
            clock: clock
        )
        let refresh = try relaunchedManager.refreshFocusSession(focusSessionId: session.focusSessionId)

        #expect(refresh.session.focusSessionId == session.focusSessionId)
        #expect(refresh.session.isResting)
        #expect(refresh.remainingRestSeconds == 210)
        #expect(relaunchedManager.activeFocusSession?.focusSessionId == session.focusSessionId)
        #expect(relaunchedManager.rewardCredits == 1)
    }

    @Test func terminalSessionsReportNoRemainingFocusTime() throws {
        let clock = TestFocusClock()
        let deadline = clock.now.addingTimeInterval(60)
        let snapshot = LocalAppSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: nil,
            completedSessionCount: 1,
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
            creditLedger: RewardCreditLedger(),
            nextActivityNumber: 2,
            nextSessionNumber: 3
        )
        let manager = FocusManager(
            repository: MockLocalAppRepository(snapshot: snapshot),
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

    @Test func legacyPausedSessionMigratesToRunningWithRemainingFocusTime() throws {
        let startedAt = Date(timeIntervalSince1970: 1_756_944_000)
        let snapshot = LocalAppSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: nil,
            completedSessionCount: 0,
            focusSessions: [FocusSessionModel.runningMock],
            creditLedger: RewardCreditLedger(),
            nextActivityNumber: 2,
            nextSessionNumber: 2
        )
        let data = try JSONEncoder().encode(snapshot)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var sessions = try #require(json["focusSessions"] as? [[String: Any]])
        sessions[0]["state"] = "paused"
        sessions[0]["startedAt"] = startedAt.timeIntervalSinceReferenceDate
        sessions[0]["pausedAt"] = startedAt.addingTimeInterval(21 * 60).timeIntervalSinceReferenceDate
        sessions[0]["focusEndsAt"] = startedAt.addingTimeInterval(25 * 60).timeIntervalSinceReferenceDate
        sessions[0]["pauseUsed"] = true
        sessions[0]["pauseRemainingSeconds"] = 300
        sessions[0].removeValue(forKey: "restState")
        sessions[0].removeValue(forKey: "restEndsAt")
        json["focusSessions"] = sessions

        let migratedData = try JSONSerialization.data(withJSONObject: json)
        let migrated = try JSONDecoder().decode(LocalAppSnapshot.self, from: migratedData)
        let session = try #require(migrated.focusSessions.first)
        let focusEndsAt = try #require(session.focusEndsAt)

        #expect(session.state == .running)
        #expect(session.restState == .unavailable)
        #expect(focusEndsAt > Date())
        #expect(focusEndsAt < Date().addingTimeInterval(5 * 60))
    }

#if MOCK
    @Test func mockCompletionFinishesAReadySessionAndAwardsTheSameRewards() throws {
        let manager = FocusManager(repository: MockLocalAppRepository(), clock: TestFocusClock())
        let session = try #require(manager.startFocusSession(activityId: ActivityModel.mock.activityId))

        let completed = try manager.markFocusSessionCompleteForTesting(
            focusSessionId: session.focusSessionId
        )

        #expect(completed.state == .completed)
        #expect(manager.rewardCredits == 1)
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

private final class FocusObservationRecorder: @unchecked Sendable {
    var count = 0
}
