import Foundation

struct PlanTimeBlockModel: Identifiable, Codable, Hashable {
    let timeBlockId: String
    let activityId: String
    let plannedStart: Date?
    let durationMinutes: Int

    var id: String {
        timeBlockId
    }

    init(
        timeBlockId: String,
        activityId: String,
        plannedStart: Date? = nil,
        durationMinutes: Int = FocusSessionModel.durationMinutes
    ) {
        self.timeBlockId = timeBlockId
        self.activityId = activityId
        self.plannedStart = plannedStart
        self.durationMinutes = durationMinutes
    }

    var eventParameters: [String: Any] {
        [
            "time_block_id": timeBlockId,
            "time_block_activity_id": activityId,
            "time_block_planned_start": plannedStart as Any,
            "time_block_duration_minutes": durationMinutes
        ]
    }
}

struct DailyPlanItemModel: Identifiable, Codable, Hashable {
    let planItemId: String
    let activityId: String
    let plannedSessionCount: Int

    var id: String {
        planItemId
    }

    init(
        planItemId: String,
        activityId: String,
        plannedSessionCount: Int
    ) {
        self.planItemId = planItemId
        self.activityId = activityId
        self.plannedSessionCount = max(plannedSessionCount, 1)
    }
}

struct DailyPlanModel: Identifiable, Codable, Hashable {
    let dailyPlanId: String
    let localDay: LocalDay
    let intendedSessionCount: Int
    let originalIntendedSessionCount: Int
    let activityIds: [String]
    let planItems: [DailyPlanItemModel]
    let timeBlocks: [PlanTimeBlockModel]?
    let isRevised: Bool

    var id: String {
        dailyPlanId
    }

    private enum CodingKeys: String, CodingKey {
        case dailyPlanId
        case localDay = "local_day"
        case localDate = "local_date"
        case intendedSessionCount
        case originalIntendedSessionCount
        case activityIds
        case planItems
        case timeBlocks
        case isRevised
    }

    init(
        dailyPlanId: String,
        localDate: Date,
        localDay: LocalDay? = nil,
        intendedSessionCount: Int,
        originalIntendedSessionCount: Int,
        activityIds: [String],
        planItems: [DailyPlanItemModel]? = nil,
        timeBlocks: [PlanTimeBlockModel]? = nil,
        isRevised: Bool = false
    ) {
        self.dailyPlanId = dailyPlanId
        self.localDay = localDay ?? LocalDay(containing: localDate, calendar: .current)
        self.intendedSessionCount = intendedSessionCount
        self.originalIntendedSessionCount = originalIntendedSessionCount
        let normalizedItems = planItems?.filter { activityIds.contains($0.activityId) }
            ?? Self.makePlanItems(activityIds: activityIds, sessionCount: intendedSessionCount)
        self.planItems = normalizedItems
        self.activityIds = normalizedItems.map(\.activityId)
        self.timeBlocks = timeBlocks
        self.isRevised = isRevised
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dailyPlanId = try container.decode(String.self, forKey: .dailyPlanId)
        let localDate = try container.decodeIfPresent(Date.self, forKey: .localDate)
        let localDay = try container.decodeIfPresent(LocalDay.self, forKey: .localDay)
            ?? LocalDay(containing: localDate ?? Date(), calendar: .current)
        let intendedSessionCount = try container.decode(Int.self, forKey: .intendedSessionCount)
        let originalIntendedSessionCount = try container.decode(Int.self, forKey: .originalIntendedSessionCount)
        let activityIds = try container.decode([String].self, forKey: .activityIds)
        let planItems = try container.decodeIfPresent([DailyPlanItemModel].self, forKey: .planItems)
        let timeBlocks = try container.decodeIfPresent([PlanTimeBlockModel].self, forKey: .timeBlocks)
        let isRevised = try container.decodeIfPresent(Bool.self, forKey: .isRevised) ?? false

        self.init(
            dailyPlanId: dailyPlanId,
            localDate: localDate ?? localDay.startDate,
            localDay: localDay,
            intendedSessionCount: intendedSessionCount,
            originalIntendedSessionCount: originalIntendedSessionCount,
            activityIds: activityIds,
            planItems: planItems,
            timeBlocks: timeBlocks,
            isRevised: isRevised
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dailyPlanId, forKey: .dailyPlanId)
        try container.encode(localDay, forKey: .localDay)
        try container.encode(localDate, forKey: .localDate)
        try container.encode(intendedSessionCount, forKey: .intendedSessionCount)
        try container.encode(originalIntendedSessionCount, forKey: .originalIntendedSessionCount)
        try container.encode(activityIds, forKey: .activityIds)
        try container.encode(planItems, forKey: .planItems)
        try container.encodeIfPresent(timeBlocks, forKey: .timeBlocks)
        try container.encode(isRevised, forKey: .isRevised)
    }

    var eventParameters: [String: Any] {
        [
            "daily_plan_id": dailyPlanId,
            "daily_plan_local_date": localDate,
            "daily_plan_intended_session_count": intendedSessionCount,
            "daily_plan_original_intended_session_count": originalIntendedSessionCount,
            "daily_plan_activity_count": activityIds.count,
            "daily_plan_item_count": planItems.count,
            "daily_plan_time_block_count": timeBlocks?.count ?? 0,
            "daily_plan_is_revised": isRevised
        ]
    }

    var localDate: Date {
        localDay.startDate
    }

    static var mock: Self {
        DailyPlanModel(
            dailyPlanId: "daily-plan-today",
            localDate: Date(timeIntervalSince1970: 1_756_944_000),
            intendedSessionCount: 3,
            originalIntendedSessionCount: 3,
            activityIds: [ActivityModel.mock.activityId],
            planItems: [
                DailyPlanItemModel(
                    planItemId: "plan-item-mock",
                    activityId: ActivityModel.mock.activityId,
                    plannedSessionCount: 3
                )
            ],
            timeBlocks: nil
        )
    }

    static var timedMock: Self {
        let start = Date(timeIntervalSince1970: 1_756_944_000 + 32_400)
        return DailyPlanModel(
            dailyPlanId: "daily-plan-timed",
            localDate: Date(timeIntervalSince1970: 1_756_944_000),
            intendedSessionCount: 3,
            originalIntendedSessionCount: 3,
            activityIds: [ActivityModel.mock.activityId],
            planItems: [
                DailyPlanItemModel(
                    planItemId: "plan-item-timed",
                    activityId: ActivityModel.mock.activityId,
                    plannedSessionCount: 3
                )
            ],
            timeBlocks: [
                PlanTimeBlockModel(
                    timeBlockId: "time-block-first",
                    activityId: ActivityModel.mock.activityId,
                    plannedStart: start
                )
            ]
        )
    }

    static var emptyMock: Self {
        DailyPlanModel(
            dailyPlanId: "daily-plan-empty",
            localDate: Date(timeIntervalSince1970: 1_756_944_000),
            intendedSessionCount: 0,
            originalIntendedSessionCount: 0,
            activityIds: [],
            planItems: [],
            timeBlocks: nil
        )
    }

    private static func makePlanItems(
        activityIds: [String],
        sessionCount: Int
    ) -> [DailyPlanItemModel] {
        guard !activityIds.isEmpty else { return [] }

        var remainingSessions = max(sessionCount, activityIds.count)
        return activityIds.enumerated().map { index, activityId in
            let itemCount = index == 0
                ? remainingSessions - max(activityIds.count - 1, 0)
                : 1
            remainingSessions -= itemCount
            return DailyPlanItemModel(
                planItemId: "plan-item-\(activityId)",
                activityId: activityId,
                plannedSessionCount: itemCount
            )
        }
    }
}
