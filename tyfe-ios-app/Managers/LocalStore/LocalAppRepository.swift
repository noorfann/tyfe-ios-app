import Foundation

struct LocalAppSnapshot: Codable, Hashable {
    private static let currentSchemaVersion = 8

    var schemaVersion: Int
    var effort: EffortState
    var activities: [ActivityModel]
    var projects: [ProjectModel]
    var dailyPlans: [DailyPlanModel]
    var lastMaterializedLocalDay: LocalDay?
    var customRewards: [RewardModel]
    var rewardClaims: [RewardClaimModel]
    var focusSessions: [FocusSessionModel]
    var checklistItems: [ChecklistItemModel]
    var checklistItemCompletions: [ChecklistItemCompletionModel]
    var creditLedger: RewardCreditLedger
    var nextActivityNumber: Int
    var nextProjectNumber: Int
    var nextSessionNumber: Int
    var nextRewardNumber: Int
    var nextRewardClaimNumber: Int
    var nextChecklistItemNumber: Int

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case effort
        case activities
        case projects
        case dailyPlans
        case dailyPlan
        case lastMaterializedLocalDay
        case completedSessionCount
        case customRewards
        case rewardClaims
        case focusSessions
        case checklistItems
        case checklistItemCompletions
        case creditLedger
        case nextActivityNumber
        case nextProjectNumber
        case nextSessionNumber
        case nextRewardNumber
        case nextRewardClaimNumber
        case nextChecklistItemNumber
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
            projects: [],
            dailyPlans: [],
            focusSessions: [],
            nextActivityNumber: 2,
            nextProjectNumber: 1,
            nextSessionNumber: 1
        )
    }

    static var rewardFlowMock: Self {
        var snapshot = Self.mock
        snapshot.creditLedger = .openingBalance(amount: 1, recordedAt: Date())
        return snapshot
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
            focusSessions: [],
            nextActivityNumber: 2,
            nextSessionNumber: 1
        )
    }

    init(
        schemaVersion: Int = 8,
        activities: [ActivityModel],
        projects: [ProjectModel] = [],
        dailyPlan: DailyPlanModel? = nil,
        completedSessionCount: Int = 0,
        dailyPlans: [DailyPlanModel]? = nil,
        lastMaterializedLocalDay: LocalDay? = nil,
        customRewards: [RewardModel] = [],
        rewardClaims: [RewardClaimModel] = [],
        focusSessions: [FocusSessionModel],
        checklistItems: [ChecklistItemModel] = [],
        checklistItemCompletions: [ChecklistItemCompletionModel] = [],
        creditLedger: RewardCreditLedger = RewardCreditLedger(),
        nextActivityNumber: Int,
        nextProjectNumber: Int = 1,
        nextSessionNumber: Int,
        nextRewardNumber: Int = 1,
        nextRewardClaimNumber: Int = 1,
        nextChecklistItemNumber: Int = 1,
        effort: EffortState = EffortState()
    ) {
        self.schemaVersion = schemaVersion
        self.effort = effort
        self.activities = activities
        self.projects = projects
        self.dailyPlans = dailyPlans ?? dailyPlan.map { [$0] } ?? []
        self.lastMaterializedLocalDay = lastMaterializedLocalDay
        self.customRewards = customRewards
        self.rewardClaims = rewardClaims
        self.focusSessions = focusSessions
        self.checklistItems = checklistItems
        self.checklistItemCompletions = checklistItemCompletions
        self.creditLedger = creditLedger
        self.nextActivityNumber = nextActivityNumber
        self.nextProjectNumber = nextProjectNumber
        self.nextSessionNumber = nextSessionNumber
        self.nextRewardNumber = nextRewardNumber
        self.nextRewardClaimNumber = nextRewardClaimNumber
        self.nextChecklistItemNumber = nextChecklistItemNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard storedVersion <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported snapshot version")
        }
        self.init(
            schemaVersion: max(storedVersion, 7),
            activities: try container.decode([ActivityModel].self, forKey: .activities),
            projects: try container.decodeIfPresent([ProjectModel].self, forKey: .projects) ?? [],
            dailyPlan: try container.decodeIfPresent(DailyPlanModel.self, forKey: .dailyPlan),
            dailyPlans: try container.decodeIfPresent([DailyPlanModel].self, forKey: .dailyPlans),
            lastMaterializedLocalDay: try container.decodeIfPresent(
                LocalDay.self,
                forKey: .lastMaterializedLocalDay
            ),
            customRewards: try container.decodeIfPresent([RewardModel].self, forKey: .customRewards) ?? [],
            rewardClaims: try container.decodeIfPresent([RewardClaimModel].self, forKey: .rewardClaims) ?? [],
            focusSessions: try container.decode([PersistedFocusSession].self, forKey: .focusSessions)
                .map { try $0.migrated(at: Date()) },
            checklistItems: try container.decodeIfPresent([ChecklistItemModel].self, forKey: .checklistItems) ?? [],
            checklistItemCompletions: try container.decodeIfPresent(
                [ChecklistItemCompletionModel].self,
                forKey: .checklistItemCompletions
            ) ?? [],
            creditLedger: try container.decode(RewardCreditLedger.self, forKey: .creditLedger),
            nextActivityNumber: try container.decode(Int.self, forKey: .nextActivityNumber),
            nextProjectNumber: try container.decodeIfPresent(Int.self, forKey: .nextProjectNumber) ?? 1,
            nextSessionNumber: try container.decode(Int.self, forKey: .nextSessionNumber),
            nextRewardNumber: try container.decodeIfPresent(Int.self, forKey: .nextRewardNumber) ?? 1,
            nextRewardClaimNumber: try container.decodeIfPresent(Int.self, forKey: .nextRewardClaimNumber) ?? 1,
            nextChecklistItemNumber: try container.decodeIfPresent(
                Int.self,
                forKey: .nextChecklistItemNumber
            ) ?? 1,
            effort: try container.decodeIfPresent(EffortState.self, forKey: .effort) ?? EffortState()
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(effort.migrationDay == nil ? schemaVersion : Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(effort, forKey: .effort)
        try container.encode(activities, forKey: .activities)
        try container.encode(projects, forKey: .projects)
        try container.encode(dailyPlans, forKey: .dailyPlans)
        try container.encodeIfPresent(lastMaterializedLocalDay, forKey: .lastMaterializedLocalDay)
        try container.encode(customRewards, forKey: .customRewards)
        try container.encode(rewardClaims, forKey: .rewardClaims)
        try container.encode(focusSessions, forKey: .focusSessions)
        try container.encode(checklistItems, forKey: .checklistItems)
        try container.encode(checklistItemCompletions, forKey: .checklistItemCompletions)
        try container.encode(creditLedger, forKey: .creditLedger)
        try container.encode(nextActivityNumber, forKey: .nextActivityNumber)
        try container.encode(nextProjectNumber, forKey: .nextProjectNumber)
        try container.encode(nextSessionNumber, forKey: .nextSessionNumber)
        try container.encode(nextRewardNumber, forKey: .nextRewardNumber)
        try container.encode(nextRewardClaimNumber, forKey: .nextRewardClaimNumber)
        try container.encode(nextChecklistItemNumber, forKey: .nextChecklistItemNumber)
    }
}

@MainActor
protocol LocalAppRepository {
    var snapshot: LocalAppSnapshot { get }
    func retryLoad() throws

    func transaction(
        _ update: (inout LocalAppSnapshot) throws -> Void
    ) throws
}

extension LocalAppRepository {
    func retryLoad() throws { }
}

@MainActor
final class MockLocalAppRepository: LocalAppRepository {
    private(set) var snapshot: LocalAppSnapshot
    private(set) var transactionCount = 0

    init(snapshot: LocalAppSnapshot = .mock) {
        self.snapshot = snapshot
    }

    func transaction(
        _ update: (inout LocalAppSnapshot) throws -> Void
    ) throws {
        var nextSnapshot = snapshot
        try update(&nextSnapshot)
        snapshot = nextSnapshot
        transactionCount += 1
    }
}

@MainActor
protocol LocalAppRepositoryPersistence {
    func load() throws -> LocalAppSnapshot?
    func save(_ snapshot: LocalAppSnapshot) throws
}

@MainActor
struct LocalFileRepositoryPersistence: LocalAppRepositoryPersistence {
    private let fileURL: URL

    static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("local-app-snapshot-v1.txt")
    }

    init(fileURL: URL = LocalFileRepositoryPersistence.defaultFileURL) {
        self.fileURL = fileURL
    }

    func load() throws -> LocalAppSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(LocalAppSnapshot.self, from: data)
    }

    func save(_ snapshot: LocalAppSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        if snapshot.effort.migrationDay != nil, FileManager.default.fileExists(atPath: fileURL.path) {
            let backupURL = fileURL.appendingPathExtension("pre-phase2-backup")
            if !FileManager.default.fileExists(atPath: backupURL.path) {
                let previousData = try Data(contentsOf: fileURL)
                let previous = try JSONDecoder().decode(LocalAppSnapshot.self, from: previousData)
                if previous.effort.migrationDay == nil { try previousData.write(to: backupURL, options: .atomic) }
            }
        }
        try data.write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class LocalFileRepository: LocalAppRepository {
    private let persistence: LocalAppRepositoryPersistence
    private var loadFailed: Bool
    private(set) var snapshot: LocalAppSnapshot

    init(
        persistence: LocalAppRepositoryPersistence,
        fallback: LocalAppSnapshot = .mock
    ) {
        self.persistence = persistence
        let storedSnapshot: LocalAppSnapshot?
        do {
            storedSnapshot = try persistence.load()
            self.loadFailed = false
        } catch {
            storedSnapshot = nil
            self.loadFailed = true
        }
        self.snapshot = storedSnapshot ?? fallback
    }

    func retryLoad() throws {
        guard loadFailed else { return }
        do {
            if let loaded = try persistence.load() { snapshot = loaded }
            loadFailed = false
        } catch {
            throw FocusManagerError.persistenceFailed
        }
    }

    func transaction(
        _ update: (inout LocalAppSnapshot) throws -> Void
    ) throws {
        guard !loadFailed else { throw FocusManagerError.persistenceFailed }
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

private struct PersistedFocusSession: Decodable {
    let focusSessionId: String
    let activityId: String
    let state: String
    let startedAt: Date
    let localDay: LocalDay?
    let pausedAt: Date?
    let completedAt: Date?
    let focusEndsAt: Date?
    let restState: FocusRestState?
    let restEndsAt: Date?

    private enum CodingKeys: String, CodingKey {
        case focusSessionId
        case activityId
        case state
        case startedAt
        case localDay = "local_day"
        case pausedAt
        case completedAt
        case focusEndsAt
        case restState
        case restEndsAt
    }

    func migrated(at now: Date) throws -> FocusSessionModel {
        let migratedState: FocusSessionState
        let migratedFocusEndsAt: Date?

        if state == "paused" {
            let originalEnd = focusEndsAt
                ?? startedAt.addingTimeInterval(TimeInterval(FocusSessionModel.durationMinutes * 60))
            let pauseDate = pausedAt ?? startedAt
            let remainingSeconds = max(originalEnd.timeIntervalSince(pauseDate), 0)
            migratedState = .running
            migratedFocusEndsAt = now.addingTimeInterval(remainingSeconds)
        } else if let state = FocusSessionState(rawValue: state) {
            migratedState = state
            migratedFocusEndsAt = focusEndsAt
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unknown focus session state: \(state)")
            )
        }

        return FocusSessionModel(
            focusSessionId: focusSessionId,
            activityId: activityId,
            state: migratedState,
            startedAt: startedAt,
            localDay: localDay,
            completedAt: completedAt,
            focusEndsAt: migratedFocusEndsAt,
            restState: restState ?? .unavailable,
            restEndsAt: restEndsAt
        )
    }
}
