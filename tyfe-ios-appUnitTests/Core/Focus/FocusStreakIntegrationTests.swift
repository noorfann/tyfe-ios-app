import Foundation
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
        #expect(events.count == 2)
        #expect(context.streakManager.currentStreakData.currentStreak == 1)
    }

    @Test func incompleteSessionsDoNotRecordStreakEvents() async throws {
        let context = try await makeContext()

        try await context.interactor.recordFocusCompletionForStreak(.runningMock)
        try await context.interactor.recordFocusCompletionForStreak(.abandonedMock)

        let events = try await context.streakManager.getAllStreakEvents()
        #expect(events.isEmpty)
    }

    private func makeContext() async throws -> StreakTestContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let streakManager = try #require(
            dependencies.container.resolve(
                StreakManager.self,
                key: Dependencies.streakConfiguration.streakKey
            )
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
