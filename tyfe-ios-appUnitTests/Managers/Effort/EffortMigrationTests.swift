import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct EffortMigrationTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return value
    }

    private func legacySnapshot(clock: TestFocusClock) throws -> LocalAppSnapshot {
        let repository = MockLocalAppRepository()
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let activity = try #require(today.createActivity(name: "Kitchen", category: nil, colorToken: nil, type: .checklist))
        _ = today.setActivityRecurrence(activityId: activity.id, recurrence: ActivityRecurrenceModel(kind: .daily))
        let first = try #require(today.addChecklistItem(activityId: activity.id, title: "Dishes", creditValue: .oneCredit))
        _ = today.addChecklistItem(activityId: activity.id, title: "Counter", creditValue: .twoCredits)
        _ = today.completeChecklistItem(itemId: first.id)
        var snapshot = repository.snapshot
        snapshot.schemaVersion = 7
        return snapshot
    }

    @Test func migrationPreservesPartialTicksLedgerAndPlansWithoutDuplicateAwards() throws {
        let clock = TestFocusClock()
        let original = try legacySnapshot(clock: clock)
        let repository = MockLocalAppRepository(snapshot: original)
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try todo.prepare()
        let task = try #require(todo.tasks.first)
        #expect(repository.snapshot.schemaVersion == 8)
        #expect(task.title == "Kitchen")
        #expect(task.items[0].isCompleted)
        #expect(!task.items[1].isCompleted)
        #expect(repository.snapshot.creditLedger == original.creditLedger)
        #expect(repository.snapshot.dailyPlans == original.dailyPlans)
        #expect(repository.snapshot.activities.filter { $0.type == .checklist }.allSatisfy { $0.isArchived && $0.recurrence == nil })
        try todo.toggleItem(taskId: task.id, itemId: task.items[1].id)
        #expect(todo.tasks[0].isCompleted)
        #expect(repository.snapshot.creditLedger.balance == 1)
        let migrated = repository.snapshot
        try todo.prepare()
        #expect(repository.snapshot == migrated)
        let restored = try JSONDecoder().decode(LocalAppSnapshot.self, from: JSONEncoder().encode(migrated))
        let relaunched = MockLocalAppRepository(snapshot: restored)
        try TodoManager(repository: relaunched, clock: clock, calendar: calendar).prepare()
        #expect(relaunched.snapshot.effort.tasks.count == 1)
        #expect(relaunched.snapshot.effort.taskHistory.count == 1)
    }

    @Test func fullyCheckedMigrationIsCompletedAndUntouchedMigrationEarnsHalfCredit() throws {
        let clock = TestFocusClock()
        let repository = MockLocalAppRepository(snapshot: try legacySnapshot(clock: clock))
        let today = TodayManager(repository: repository, clock: clock, calendar: calendar)
        let second = try #require(repository.snapshot.checklistItems.first { $0.title == "Counter" })
        _ = today.completeChecklistItem(itemId: second.id)
        let untouched = try #require(today.createActivity(name: "Read book", category: nil, colorToken: nil, type: .checklist))
        _ = today.addChecklistItem(activityId: untouched.id, title: "Chapter one", creditValue: .twoCredits)
        let balance = repository.snapshot.creditLedger.balance
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try todo.prepare()
        let completed = try #require(todo.tasks.first { $0.title == "Kitchen" })
        let open = try #require(todo.tasks.first { $0.title == "Read book" })
        #expect(completed.isCompleted)
        #expect(completed.hasEarnedAward)
        #expect(open.creditValue == .halfCredit)
        #expect(!open.hasEarnedAward)
        #expect(repository.snapshot.creditLedger.balance == balance)
        try todo.toggleItem(taskId: open.id, itemId: open.items[0].id)
        #expect(repository.snapshot.creditLedger.balance == balance + Decimal(0.5))
    }

    @Test func failedSaveDoesNotPublishMigrationAndRetryRunsOnce() throws {
        let clock = TestFocusClock()
        let original = try legacySnapshot(clock: clock)
        let persistence = EffortTestPersistence(snapshot: original)
        let repository = LocalFileRepository(persistence: persistence)
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        persistence.failsSaving = true
        #expect(throws: FocusManagerError.persistenceFailed) { try todo.prepare() }
        #expect(repository.snapshot == original)
        #expect(todo.preparationFailed)
        persistence.failsSaving = false
        try todo.prepare()
        #expect(!todo.preparationFailed)
        #expect(todo.tasks.count == 1)
        #expect(persistence.snapshot?.schemaVersion == 8)
    }

    @Test func failedLoadCannotOverwriteStoredWorkAndCanBeRetried() throws {
        let clock = TestFocusClock()
        let original = try legacySnapshot(clock: clock)
        let persistence = EffortTestPersistence(snapshot: original)
        persistence.failsLoading = true
        let repository = LocalFileRepository(persistence: persistence)
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        #expect(throws: FocusManagerError.persistenceFailed) { try todo.prepare() }
        #expect(persistence.saves == 0)
        #expect(persistence.snapshot == original)
        persistence.failsLoading = false
        try todo.prepare()
        #expect(todo.tasks[0].title == "Kitchen")
        #expect(repository.snapshot.creditLedger == original.creditLedger)
    }

    @Test func legacyFileIsBackedUpBeforeMigration() throws {
        let clock = TestFocusClock()
        let original = try legacySnapshot(clock: clock)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("effort-\(UUID().uuidString).json")
        let backup = file.appendingPathExtension("pre-phase2-backup")
        defer {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: backup)
        }
        let originalData = try JSONEncoder().encode(original)
        try originalData.write(to: file)
        let repository = LocalFileRepository(persistence: LocalFileRepositoryPersistence(fileURL: file))
        let todo = TodoManager(repository: repository, clock: clock, calendar: calendar)
        try todo.prepare()
        #expect(try Data(contentsOf: backup) == originalData)
        let saved = try JSONDecoder().decode(LocalAppSnapshot.self, from: Data(contentsOf: file))
        #expect(saved.effort.tasks.count == 1)
        try todo.prepare()
        #expect(try Data(contentsOf: backup) == originalData)
    }

    @Test func futureSnapshotVersionIsRejected() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(LocalAppSnapshot.mock)) as? [String: Any])
        object["schemaVersion"] = 99
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(LocalAppSnapshot.self, from: data) }
    }
}

@MainActor
private final class EffortTestPersistence: LocalAppRepositoryPersistence {
    var snapshot: LocalAppSnapshot?
    var failsSaving = false
    var failsLoading = false
    var saves = 0

    init(snapshot: LocalAppSnapshot) { self.snapshot = snapshot }
    func load() throws -> LocalAppSnapshot? {
        if failsLoading { throw FocusManagerError.persistenceFailed }
        return snapshot
    }
    func save(_ snapshot: LocalAppSnapshot) throws {
        if failsSaving { throw FocusManagerError.persistenceFailed }
        self.snapshot = snapshot
        saves += 1
    }
}
