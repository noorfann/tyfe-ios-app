import Foundation

struct LocalAppSnapshot: Codable, Hashable {
    private static let currentSchemaVersion = 4

    var schemaVersion: Int
    var activities: [ActivityModel]
    var dailyPlans: [DailyPlanModel]
    var customRewards: [RewardModel]
    var rewardClaims: [RewardClaimModel]
    var focusSessions: [FocusSessionModel]
    var creditLedger: RewardCreditLedger
    var nextActivityNumber: Int
    var nextSessionNumber: Int
    var nextRewardNumber: Int
    var nextRewardClaimNumber: Int

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case activities
        case dailyPlans
        case dailyPlan
        case completedSessionCount
        case customRewards
        case rewardClaims
        case focusSessions
        case creditLedger
        case nextActivityNumber
        case nextSessionNumber
        case nextRewardNumber
        case nextRewardClaimNumber
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
            focusSessions: [],
            nextActivityNumber: 2,
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
        schemaVersion: Int = 4,
        activities: [ActivityModel],
        dailyPlan: DailyPlanModel? = nil,
        completedSessionCount: Int = 0,
        dailyPlans: [DailyPlanModel]? = nil,
        customRewards: [RewardModel] = [],
        rewardClaims: [RewardClaimModel] = [],
        focusSessions: [FocusSessionModel],
        creditLedger: RewardCreditLedger = RewardCreditLedger(),
        nextActivityNumber: Int,
        nextSessionNumber: Int,
        nextRewardNumber: Int = 1,
        nextRewardClaimNumber: Int = 1
    ) {
        self.schemaVersion = schemaVersion
        self.activities = activities
        self.dailyPlans = dailyPlans ?? dailyPlan.map { [$0] } ?? []
        self.customRewards = customRewards
        self.rewardClaims = rewardClaims
        self.focusSessions = focusSessions
        self.creditLedger = creditLedger
        self.nextActivityNumber = nextActivityNumber
        self.nextSessionNumber = nextSessionNumber
        self.nextRewardNumber = nextRewardNumber
        self.nextRewardClaimNumber = nextRewardClaimNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: Self.currentSchemaVersion,
            activities: try container.decode([ActivityModel].self, forKey: .activities),
            dailyPlan: try container.decodeIfPresent(DailyPlanModel.self, forKey: .dailyPlan),
            dailyPlans: try container.decodeIfPresent([DailyPlanModel].self, forKey: .dailyPlans),
            customRewards: try container.decodeIfPresent([RewardModel].self, forKey: .customRewards) ?? [],
            rewardClaims: try container.decodeIfPresent([RewardClaimModel].self, forKey: .rewardClaims) ?? [],
            focusSessions: try container.decode([PersistedFocusSession].self, forKey: .focusSessions)
                .map { try $0.migrated(at: Date()) },
            creditLedger: try container.decode(RewardCreditLedger.self, forKey: .creditLedger),
            nextActivityNumber: try container.decode(Int.self, forKey: .nextActivityNumber),
            nextSessionNumber: try container.decode(Int.self, forKey: .nextSessionNumber),
            nextRewardNumber: try container.decodeIfPresent(Int.self, forKey: .nextRewardNumber) ?? 1,
            nextRewardClaimNumber: try container.decodeIfPresent(Int.self, forKey: .nextRewardClaimNumber) ?? 1
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(activities, forKey: .activities)
        try container.encode(dailyPlans, forKey: .dailyPlans)
        try container.encode(customRewards, forKey: .customRewards)
        try container.encode(rewardClaims, forKey: .rewardClaims)
        try container.encode(focusSessions, forKey: .focusSessions)
        try container.encode(creditLedger, forKey: .creditLedger)
        try container.encode(nextActivityNumber, forKey: .nextActivityNumber)
        try container.encode(nextSessionNumber, forKey: .nextSessionNumber)
        try container.encode(nextRewardNumber, forKey: .nextRewardNumber)
        try container.encode(nextRewardClaimNumber, forKey: .nextRewardClaimNumber)
    }
}

@MainActor
protocol LocalAppRepository {
    var snapshot: LocalAppSnapshot { get }

    func transaction(
        _ update: (inout LocalAppSnapshot) throws -> Void
    ) throws
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
        try data.write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class LocalFileRepository: LocalAppRepository {
    private let persistence: LocalAppRepositoryPersistence
    private(set) var snapshot: LocalAppSnapshot

    init(
        persistence: LocalAppRepositoryPersistence,
        fallback: LocalAppSnapshot = .mock
    ) {
        self.persistence = persistence
        let storedSnapshot: LocalAppSnapshot?
        do {
            storedSnapshot = try persistence.load()
        } catch {
            storedSnapshot = nil
        }
        self.snapshot = storedSnapshot ?? fallback
    }

    func transaction(
        _ update: (inout LocalAppSnapshot) throws -> Void
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

private struct PersistedFocusSession: Decodable {
    let focusSessionId: String
    let activityId: String
    let state: String
    let startedAt: Date
    let localDay: LocalDay?
    let dailyPlanIdAtStart: String?
    let pausedAt: Date?
    let completedAt: Date?
    let focusEndsAt: Date?
    let restState: FocusRestState?
    let restEndsAt: Date?
    let isBonusSession: Bool?

    private enum CodingKeys: String, CodingKey {
        case focusSessionId
        case activityId
        case state
        case startedAt
        case localDay = "local_day"
        case dailyPlanIdAtStart = "daily_plan_id_at_start"
        case pausedAt
        case completedAt
        case focusEndsAt
        case restState
        case restEndsAt
        case isBonusSession
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
            dailyPlanIdAtStart: dailyPlanIdAtStart,
            completedAt: completedAt,
            focusEndsAt: migratedFocusEndsAt,
            restState: restState ?? .unavailable,
            restEndsAt: restEndsAt,
            isBonusSession: isBonusSession ?? false
        )
    }
}
