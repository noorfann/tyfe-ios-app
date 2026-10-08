import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SessionRepeatRetirementTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "GMT") ?? .current
        return value
    }

    private func legacySnapshot() -> LocalAppSnapshot {
        let monday = LocalDay(year: 2026, month: 3, day: 2, timeZoneIdentifier: "GMT")
        var snapshot = LocalAppSnapshot.mock
        snapshot.schemaVersion = 8
        snapshot.activities[0].legacyRecurrence = LegacyActivityRecurrence(kind: .daily, defaultSessionCount: 2)
        snapshot.effort.migrationDay = monday
        snapshot.effort.lastPreparedDay = monday.adding(days: 1)
        snapshot.effort.days = [EffortDayRecord(localDay: monday, plannedSessions: 7, completedSessions: 0, outcome: .missed)]
        return snapshot
    }

    @Test func retirementPreservesHistoryAndStopsFutureGeneration() throws {
        let original = legacySnapshot()
        let thursday = LocalDay(year: 2026, month: 3, day: 5, timeZoneIdentifier: "GMT")
        let clock = TestFocusClock(now: thursday.startDate.addingTimeInterval(3_600))
        let repository = MockLocalAppRepository(snapshot: original)
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try manager.prepare()
        #expect(repository.snapshot.schemaVersion == 9)
        #expect(repository.snapshot.activities[0].legacyRecurrence == nil)
        #expect(repository.snapshot.effort.days.first == original.effort.days.first)
        #expect(repository.snapshot.effort.days.first { $0.localDay == thursday.adding(days: -1) }?.plannedSessions == 2)
        #expect(repository.snapshot.dailyPlans == original.dailyPlans)
        #expect(repository.snapshot.focusSessions == original.focusSessions)
        #expect(repository.snapshot.creditLedger == original.creditLedger)
        clock.advance(by: 86_400)
        try manager.prepare()
        #expect(repository.snapshot.dailyPlans.isEmpty)
        #expect(repository.snapshot.effort.days.last?.plannedSessions == 0)
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        #expect(today.addActivityToDailyPlan(activityId: original.activities[0].id, sessionCount: 2) != nil)
    }

    @Test func retirementMakesExactBackupAndDoesNotReplaceItOnSubsequentSaves() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("snapshot.json")
        let original = try JSONEncoder().encode(legacySnapshot())
        try original.write(to: file)
        let persistence = LocalFileRepositoryPersistence(fileURL: file)
        let repository = LocalFileRepository(persistence: persistence)
        let clock = TestFocusClock(now: LocalDay(year: 2026, month: 3, day: 5, timeZoneIdentifier: "GMT").startDate)
        let manager = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try manager.prepare()
        let backup = file.appendingPathExtension("pre-v9-backup")
        #expect(try Data(contentsOf: backup) == original)
        var draft = TodoDraft()
        draft.title = "New task"
        try manager.save(draft)
        #expect(try Data(contentsOf: backup) == original)
        let restored = try JSONDecoder().decode(LocalAppSnapshot.self, from: Data(contentsOf: file))
        #expect(restored.schemaVersion == 9 && restored.effort.tasks.count == 1)
        #expect(restored.activities[0].legacyRecurrence == nil)
    }

    @Test func legacyHabitScheduleIgnoresSessionCount() throws {
        let data = Data(#"{"kind":"weekly","weekdays":[1,3,5],"defaultSessionCount":4}"#.utf8)
        let schedule = try JSONDecoder().decode(RepeatSchedule.self, from: data)
        #expect(schedule.weekdays == [1, 3, 5])
        #expect(schedule.isDue(on: LocalDay(year: 2026, month: 3, day: 2, timeZoneIdentifier: "GMT")))
    }
}
