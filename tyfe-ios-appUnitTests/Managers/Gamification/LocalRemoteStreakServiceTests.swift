import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct LocalRemoteStreakServiceTests {
    @Test func stateSurvivesServiceRecreation() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let original = LocalRemoteStreakService(fileURL: fileURL)
        let streak = makeStreak(userId: "user-one", count: 7)
        let event = StreakEvent.mock(id: "persisted-event")
        let freeze = StreakFreeze(id: "persisted-freeze", dateEarned: Date())

        try await original.addEvent(userId: "user-one", streakKey: "focus", event: event)
        try await original.addStreakFreeze(userId: "user-one", streakKey: "focus", freeze: freeze)
        try await original.updateCurrentStreak(userId: "user-one", streakKey: "focus", streak: streak)

        let restored = LocalRemoteStreakService(fileURL: fileURL)
        let events = try await restored.getAllEvents(userId: "user-one", streakKey: "focus")
        let freezes = try await restored.getAllStreakFreezes(userId: "user-one", streakKey: "focus")
        var streaks = restored.streamCurrentStreak(userId: "user-one", streakKey: "focus").makeAsyncIterator()
        let restoredStreak = try await streaks.next()

        #expect(events == [event])
        #expect(freezes == [freeze])
        #expect(restoredStreak == streak)
    }

    @Test func recordsRemainIsolatedByUserAndStreakKey() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let service = LocalRemoteStreakService(fileURL: fileURL)
        let firstEvent = StreakEvent.mock(id: "first-user-event")
        let secondEvent = StreakEvent.mock(id: "second-user-event")

        try await service.addEvent(userId: "user-one", streakKey: "focus", event: firstEvent)
        try await service.addEvent(userId: "user-two", streakKey: "focus", event: secondEvent)

        let firstUserEvents = try await service.getAllEvents(userId: "user-one", streakKey: "focus")
        let secondUserEvents = try await service.getAllEvents(userId: "user-two", streakKey: "focus")
        let otherStreakEvents = try await service.getAllEvents(userId: "user-one", streakKey: "reading")

        #expect(firstUserEvents == [firstEvent])
        #expect(secondUserEvents == [secondEvent])
        #expect(otherStreakEvents.isEmpty)
    }

    @Test func duplicateIdsAreStoredOnceAndFreezeUsePersists() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let service = LocalRemoteStreakService(fileURL: fileURL)
        let event = StreakEvent.mock(id: "duplicate-event")
        let freeze = StreakFreeze(id: "duplicate-freeze", dateEarned: Date())

        try await service.addEvent(userId: "user", streakKey: "focus", event: event)
        try await service.addEvent(userId: "user", streakKey: "focus", event: event)
        try await service.addStreakFreeze(userId: "user", streakKey: "focus", freeze: freeze)
        try await service.addStreakFreeze(userId: "user", streakKey: "focus", freeze: freeze)
        try await service.useStreakFreeze(userId: "user", streakKey: "focus", freezeId: freeze.id)

        let restored = LocalRemoteStreakService(fileURL: fileURL)
        let events = try await restored.getAllEvents(userId: "user", streakKey: "focus")
        let freezes = try await restored.getAllStreakFreezes(userId: "user", streakKey: "focus")

        #expect(events.count == 1)
        #expect(freezes.count == 1)
        #expect(freezes.first?.isUsed == true)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("streak-store-\(UUID().uuidString).json")
    }

    private func makeStreak(userId: String, count: Int) -> CurrentStreakData {
        CurrentStreakData(
            streakKey: "focus",
            userId: userId,
            currentStreak: count,
            longestStreak: count,
            totalEvents: count,
            freezesAvailableCount: 1,
            eventsRequiredPerDay: 1,
            todayEventCount: 1
        )
    }
}
