import Foundation

@MainActor
protocol FocusClock {
    var now: Date { get }
}

@MainActor
struct SystemFocusClock: FocusClock {
    var now: Date { Date() }
}

struct FocusManagerSnapshot: Codable, Hashable {
    var schemaVersion: Int
    var activities: [ActivityModel]
    var dailyPlans: [DailyPlanModel]
    var progression: ProgressionSnapshotModel
    var focusSessions: [FocusSessionModel]
    var creditLedger: RewardCreditLedger
    var progressionAwards: [ProgressionAwardModel]
    var nextActivityNumber: Int
    var nextSessionNumber: Int

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case activities
        case dailyPlans
        case dailyPlan
        case completedSessionCount
        case progression
        case focusSessions
        case creditLedger
        case progressionAwards
        case nextActivityNumber
        case nextSessionNumber
    }

    var dailyPlan: DailyPlanModel? {
        get { dailyPlans.last }
        set { dailyPlans = newValue.map { [$0] } ?? [] }
    }

    var completedSessionCount: Int {
        focusSessions.filter { $0.state == .completed }.count
    }

    static var mock: Self {
        Self(
            activities: [ActivityModel.mock],
            dailyPlans: [],
            progression: .mock,
            focusSessions: [],
            creditLedger: .openingBalance(amount: 2),
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 1
        )
    }

    static var homeFlowMock: Self {
        let activity = ActivityModel.mock
        let localDate = Date()
        let plan = DailyPlanModel(
            dailyPlanId: "daily-plan-home-flow",
            localDate: localDate,
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
            dailyPlans: [plan],
            progression: .mock,
            focusSessions: [],
            creditLedger: .openingBalance(amount: 2),
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 1
        )
    }

    init(
        schemaVersion: Int = 2,
        activities: [ActivityModel],
        dailyPlan: DailyPlanModel? = nil,
        completedSessionCount: Int = 0,
        dailyPlans: [DailyPlanModel]? = nil,
        progression: ProgressionSnapshotModel,
        focusSessions: [FocusSessionModel],
        creditLedger: RewardCreditLedger = RewardCreditLedger(),
        progressionAwards: [ProgressionAwardModel],
        nextActivityNumber: Int,
        nextSessionNumber: Int
    ) {
        self.schemaVersion = schemaVersion
        self.activities = activities
        self.dailyPlans = dailyPlans ?? dailyPlan.map { [$0] } ?? []
        self.progression = progression
        self.focusSessions = focusSessions
        self.creditLedger = creditLedger
        self.progressionAwards = progressionAwards
        self.nextActivityNumber = nextActivityNumber
        self.nextSessionNumber = nextSessionNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: 2,
            activities: try container.decode([ActivityModel].self, forKey: .activities),
            dailyPlan: try container.decodeIfPresent(DailyPlanModel.self, forKey: .dailyPlan),
            dailyPlans: try container.decodeIfPresent([DailyPlanModel].self, forKey: .dailyPlans),
            progression: try container.decode(ProgressionSnapshotModel.self, forKey: .progression),
            focusSessions: try container.decode([FocusSessionModel].self, forKey: .focusSessions),
            creditLedger: try container.decode(RewardCreditLedger.self, forKey: .creditLedger),
            progressionAwards: try container.decode([ProgressionAwardModel].self, forKey: .progressionAwards),
            nextActivityNumber: try container.decode(Int.self, forKey: .nextActivityNumber),
            nextSessionNumber: try container.decode(Int.self, forKey: .nextSessionNumber)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(2, forKey: .schemaVersion)
        try container.encode(activities, forKey: .activities)
        try container.encode(dailyPlans, forKey: .dailyPlans)
        try container.encode(progression, forKey: .progression)
        try container.encode(focusSessions, forKey: .focusSessions)
        try container.encode(creditLedger, forKey: .creditLedger)
        try container.encode(progressionAwards, forKey: .progressionAwards)
        try container.encode(nextActivityNumber, forKey: .nextActivityNumber)
        try container.encode(nextSessionNumber, forKey: .nextSessionNumber)
    }
}

@MainActor
protocol FocusRepository {
    var snapshot: FocusManagerSnapshot { get }

    func transaction(
        _ update: (inout FocusManagerSnapshot) throws -> Void
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
        _ update: (inout FocusManagerSnapshot) throws -> Void
    ) throws {
        var nextSnapshot = snapshot
        try update(&nextSnapshot)
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
    private let fileURL: URL

    static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("focus-manager-snapshot-v1.txt")
    }

    init(fileURL: URL = LocalFocusRepositoryPersistence.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> FocusManagerSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(FocusManagerSnapshot.self, from: data)
    }

    func save(_ snapshot: FocusManagerSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
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
        _ update: (inout FocusManagerSnapshot) throws -> Void
    ) throws {
        var nextSnapshot = snapshot
        try update(&nextSnapshot)
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
