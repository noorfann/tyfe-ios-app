import Foundation
import SwiftfulGamification
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusStreakIntegrationTests {

#if MOCK
    @Test func completedFocusSessionRecordsStreakOnceAcrossRepeatedRefreshes() async throws {
        let context = try await makeContext()
        let session = try #require(
            context.interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try context.interactor.markFocusSessionCompleteForTesting(
            focusSessionId: session.focusSessionId
        )

        _ = try context.interactor.refreshFocusSession(focusSessionId: session.focusSessionId)
        #expect(await waitForEventCount(1, manager: context.streakManager))

        _ = try context.interactor.refreshFocusSession(focusSessionId: session.focusSessionId)
        try await context.interactor.recordFocusCompletionForStreak(
            session.updated(state: .completed, completedAt: Date())
        )
        let events = try await context.streakManager.getAllStreakEvents()
        #expect(events.count == 1)
        #expect(
            events.first?.metadata["focus_session_id"]
                == .string(session.focusSessionId)
        )
        #expect(context.streakManager.currentStreakData.currentStreak == 1)
    }
#endif

    @Test func differentCompletedSessionsOnSameDayRemainOneStreakDay() async throws {
        let context = try await makeContext()

        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "focus-session-one")
        )
        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "focus-session-two", isBonusSession: true)
        )

        let events = try await context.streakManager.getAllStreakEvents()
        let freezes = try await context.streakManager.getAllStreakFreezes()
        #expect(events.count == 2)
        #expect(context.streakManager.currentStreakData.currentStreak == 1)
        #expect(freezes.isEmpty)
    }

    @Test func seventhStreakDayAwardsOneFreezeOnce() async throws {
        let context = try await makeContext(consecutiveDaysBeforeToday: 6)

        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "seventh-day-session")
        )
        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "another-seventh-day-session")
        )

        let freezes = try await context.streakManager.getAllStreakFreezes()
        #expect(context.streakManager.currentStreakData.currentStreak == 7)
        #expect(freezes.count == 1)
        #expect(freezes.first?.dateExpires == nil)
    }

    @Test func fourteenthStreakDayAwardsNextFreeze() async throws {
        let context = try await makeContext(
            consecutiveDaysBeforeToday: 13,
            freezesAvailableCount: 1
        )

        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "fourteenth-day-session")
        )

        let freezes = try await context.streakManager.getAllStreakFreezes()
        #expect(context.streakManager.currentStreakData.currentStreak == 14)
        #expect(freezes.filter(\.isAvailable).count == 2)
    }

    @Test func twentyFirstStreakDayAwardsThirdFreeze() async throws {
        let context = try await makeContext(
            consecutiveDaysBeforeToday: 20,
            freezesAvailableCount: 2
        )

        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "twenty-first-day-session")
        )

        let freezes = try await context.streakManager.getAllStreakFreezes()
        #expect(context.streakManager.currentStreakData.currentStreak == 21)
        #expect(freezes.filter(\.isAvailable).count == 3)
    }

    @Test func milestoneDoesNotExceedThreeAvailableFreezes() async throws {
        let context = try await makeContext(
            consecutiveDaysBeforeToday: 27,
            freezesAvailableCount: 3
        )

        try await context.interactor.recordFocusCompletionForStreak(
            completedSession(id: "twenty-eighth-day-session")
        )

        let freezes = try await context.streakManager.getAllStreakFreezes()
        #expect(context.streakManager.currentStreakData.currentStreak == 28)
        #expect(freezes.filter(\.isAvailable).count == 3)
    }

    @Test func oneMissedDayConsumesFreezeAndPreservesStreak() throws {
        let now = Date()
        let previousActivity = StreakEvent.mock(
            date: try #require(Calendar.current.date(byAdding: .day, value: -2, to: now))
        )
        let olderFreeze = StreakFreeze(id: "older-gap-freeze", dateEarned: previousActivity.dateCreated)
        let newerFreeze = StreakFreeze(id: "newer-gap-freeze", dateEarned: now)

        let calculation = StreakCalculator.calculateStreak(
            events: [previousActivity],
            freezes: [newerFreeze, olderFreeze],
            configuration: Dependencies.streakConfiguration,
            currentDate: now
        )
        let consumption = try #require(calculation.freezeConsumptions.first)
        let freezeEvent = StreakEvent(
            dateCreated: consumption.date,
            isFreeze: true,
            freezeId: consumption.freezeId
        )
        let usedFreeze = StreakFreeze(
            id: olderFreeze.id,
            dateEarned: olderFreeze.dateEarned,
            dateUsed: now
        )
        let preserved = StreakCalculator.calculateStreak(
            events: [previousActivity, freezeEvent],
            freezes: [usedFreeze, newerFreeze],
            configuration: Dependencies.streakConfiguration,
            currentDate: now
        )

        #expect(calculation.freezeConsumptions.count == 1)
        #expect(consumption.freezeId == olderFreeze.id)
        #expect(preserved.streak.currentStreak == 1)
    }

    @Test func insufficientFreezesDoNotPartiallyCoverGap() throws {
        let now = Date()
        let previousActivity = StreakEvent.mock(
            date: try #require(Calendar.current.date(byAdding: .day, value: -3, to: now))
        )
        let freeze = StreakFreeze(id: "insufficient-freeze", dateEarned: previousActivity.dateCreated)

        let calculation = StreakCalculator.calculateStreak(
            events: [previousActivity],
            freezes: [freeze],
            configuration: Dependencies.streakConfiguration,
            currentDate: now
        )

        #expect(calculation.freezeConsumptions.isEmpty)
        #expect(calculation.streak.freezesAvailableCount == 1)
    }

    @Test func milestoneIdsDifferAcrossStreakCycles() {
        let firstStart = Date(timeIntervalSince1970: 1_000)
        let secondStart = Date(timeIntervalSince1970: 2_000)

        let firstId = StreakFreezePolicy.freezeId(streakStart: firstStart, milestone: 7)
        let secondId = StreakFreezePolicy.freezeId(streakStart: secondStart, milestone: 7)

        #expect(firstId != secondId)
        #expect(firstId == StreakFreezePolicy.freezeId(streakStart: firstStart, milestone: 7))
    }

    @Test func incompleteSessionsDoNotRecordStreakEvents() async throws {
        let context = try await makeContext()

        try await context.interactor.recordFocusCompletionForStreak(.runningMock)
        try await context.interactor.recordFocusCompletionForStreak(.abandonedMock)

        let events = try await context.streakManager.getAllStreakEvents()
        #expect(events.isEmpty)
    }

    private func makeContext(
        consecutiveDaysBeforeToday: Int = 0,
        freezesAvailableCount: Int = 0
    ) async throws -> StreakTestContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let consecutiveDays = consecutiveDaysBeforeToday > 0
            ? Array((1...consecutiveDaysBeforeToday).reversed())
            : []
        let events = consecutiveDays.map { StreakEvent.mock(daysAgo: $0) }
        let streakData = CurrentStreakData(
            streakKey: Dependencies.streakConfiguration.streakKey,
            userId: "focus-streak-test-user",
            currentStreak: events.count,
            longestStreak: events.count,
            dateLastEvent: events.last?.dateCreated,
            lastEventTimezone: TimeZone.current.identifier,
            dateStreakStart: events.first?.dateCreated,
            totalEvents: events.count,
            freezesAvailableCount: freezesAvailableCount,
            eventsRequiredPerDay: 1,
            todayEventCount: 0,
            recentEvents: events
        )
        let streakManager = StreakManager(
            services: MockStreakServices(streak: streakData),
            configuration: Dependencies.streakConfiguration
        )
        dependencies.container.register(
            StreakManager.self,
            key: Dependencies.streakConfiguration.streakKey,
            service: streakManager
        )
        try await streakManager.logIn(userId: "focus-streak-test-user")
        return StreakTestContext(
            interactor: CoreInteractor(container: dependencies.container),
            streakManager: streakManager
        )
    }

    private func completedSession(id: String, isBonusSession: Bool = false) -> FocusSessionModel {
        FocusSessionModel(
            focusSessionId: id,
            activityId: ActivityModel.mock.activityId,
            state: .completed,
            startedAt: Date(),
            completedAt: Date(),
            isBonusSession: isBonusSession
        )
    }

    private func waitForEventCount(_ count: Int, manager: StreakManager) async -> Bool {
        for _ in 0..<50 {
            if let events = try? await manager.getAllStreakEvents(), events.count == count {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}

@MainActor
private struct StreakTestContext {
    let interactor: CoreInteractor
    let streakManager: StreakManager
}
