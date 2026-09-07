import Foundation

@MainActor
protocol FocusClock {
    var now: Date { get }
}

@MainActor
struct SystemFocusClock: FocusClock {
    var now: Date { Date() }
}

struct RewardCreditLedgerEntry: Identifiable, Codable, Hashable {
    let ledgerEntryId: String
    let focusSessionId: String
    let amount: Int
    let awardedAt: Date
    let idempotencyKey: String

    var id: String { ledgerEntryId }
}

struct FocusManagerSnapshot: Codable, Hashable {
    var schemaVersion: Int
    var activities: [ActivityModel]
    var dailyPlan: DailyPlanModel?
    var completedSessionCount: Int
    var rewardCredits: Int
    var progression: ProgressionSnapshotModel
    var focusSessions: [FocusSessionModel]
    var creditLedger: [RewardCreditLedgerEntry]
    var progressionAwards: [ProgressionAwardModel]
    var nextActivityNumber: Int
    var nextSessionNumber: Int

    static var mock: Self {
        Self(
            activities: [ActivityModel.mock],
            dailyPlan: nil,
            completedSessionCount: 0,
            rewardCredits: 2,
            progression: .mock,
            focusSessions: [],
            creditLedger: [],
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 1
        )
    }

    static var homeFlowMock: Self {
        let activity = ActivityModel.mock
        let plan = DailyPlanModel(
            dailyPlanId: "daily-plan-home-flow",
            localDate: activity.createdAt,
            intendedSessionCount: 2,
            originalIntendedSessionCount: 2,
            activityIds: [activity.activityId],
            planItems: [
                DailyPlanItemModel(
                    planItemId: "plan-item-home-flow",
                    activityId: activity.activityId,
                    plannedSessionCount: 2
                )
            ],
            timeBlocks: nil
        )

        return Self(
            activities: [activity],
            dailyPlan: plan,
            completedSessionCount: 0,
            rewardCredits: 2,
            progression: .mock,
            focusSessions: [],
            creditLedger: [],
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 1
        )
    }

    init(
        schemaVersion: Int = 1,
        activities: [ActivityModel],
        dailyPlan: DailyPlanModel?,
        completedSessionCount: Int,
        rewardCredits: Int,
        progression: ProgressionSnapshotModel,
        focusSessions: [FocusSessionModel],
        creditLedger: [RewardCreditLedgerEntry],
        progressionAwards: [ProgressionAwardModel],
        nextActivityNumber: Int,
        nextSessionNumber: Int
    ) {
        self.schemaVersion = schemaVersion
        self.activities = activities
        self.dailyPlan = dailyPlan
        self.completedSessionCount = completedSessionCount
        self.rewardCredits = rewardCredits
        self.progression = progression
        self.focusSessions = focusSessions
        self.creditLedger = creditLedger
        self.progressionAwards = progressionAwards
        self.nextActivityNumber = nextActivityNumber
        self.nextSessionNumber = nextSessionNumber
    }
}

@MainActor
protocol FocusRepository {
    var snapshot: FocusManagerSnapshot { get }

    func transaction(
        _ update: (inout FocusManagerSnapshot) -> Void
    ) throws
}

@MainActor
final class MockFocusRepository: FocusRepository {
    private(set) var snapshot: FocusManagerSnapshot
    private(set) var transactionCount = 0

    init(snapshot: FocusManagerSnapshot = .mock) {
        self.snapshot = snapshot
    }

    func transaction(
        _ update: (inout FocusManagerSnapshot) -> Void
    ) throws {
        var nextSnapshot = snapshot
        update(&nextSnapshot)
        snapshot = nextSnapshot
        transactionCount += 1
    }
}

@MainActor
protocol FocusRepositoryPersistence {
    func load() throws -> FocusManagerSnapshot?
    func save(_ snapshot: FocusManagerSnapshot) throws
}

@MainActor
struct LocalFocusRepositoryPersistence: FocusRepositoryPersistence {
    private let key = "focus-manager-snapshot-v1"

    func load() throws -> FocusManagerSnapshot? {
        try FileManager.getDocument(key: key)
    }

    func save(_ snapshot: FocusManagerSnapshot) throws {
        try FileManager.saveDocument(key: key, value: snapshot)
    }
}

@MainActor
final class LocalFocusRepository: FocusRepository {
    private let persistence: FocusRepositoryPersistence
    private(set) var snapshot: FocusManagerSnapshot

    init(
        persistence: FocusRepositoryPersistence,
        fallback: FocusManagerSnapshot = .mock
    ) {
        self.persistence = persistence
        let storedSnapshot: FocusManagerSnapshot?
        do {
            storedSnapshot = try persistence.load()
        } catch {
            storedSnapshot = nil
        }
        self.snapshot = storedSnapshot ?? fallback
    }

    func transaction(
        _ update: (inout FocusManagerSnapshot) -> Void
    ) throws {
        var nextSnapshot = snapshot
        update(&nextSnapshot)
        do {
            try persistence.save(nextSnapshot)
        } catch {
            throw FocusManagerError.persistenceFailed
        }
        snapshot = nextSnapshot
    }
}

struct FocusCompletionResult: Equatable, Codable {
    let focusSessionId: String
    let rewardCreditsAwarded: Int
    let xpAwarded: Int
    let rewardCreditBalance: Int
    let progression: ProgressionSnapshotModel
}

struct FocusSessionRefresh: Equatable {
    let session: FocusSessionModel
    let remainingFocusSeconds: Int
    let remainingPauseSeconds: Int
    let completion: FocusCompletionResult?
}

enum FocusManagerError: Error, Equatable {
    case sessionNotFound
    case invalidState
    case pauseAlreadyUsed
    case activeSessionExists
    case persistenceFailed
}
