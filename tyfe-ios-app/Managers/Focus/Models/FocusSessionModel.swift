import Foundation

enum FocusSessionState: String, Codable, CaseIterable, Hashable {
    case ready
    case running
    case completed
    case abandoned

    var displayName: String {
        switch self {
        case .ready: return "Ready"
        case .running: return "Focusing"
        case .completed: return "Complete"
        case .abandoned: return "Incomplete"
        }
    }

    var symbolName: String {
        switch self {
        case .ready: return "play.fill"
        case .running: return "timer"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "stop.circle.fill"
        }
    }
}

enum FocusRestState: String, Codable, CaseIterable, Hashable {
    case unavailable
    case pending
    case active
    case completed
    case skipped
}

struct FocusSessionModel: Identifiable, Codable, Hashable {
    static let durationMinutes = 25
    static let restDurationSeconds = 300

    let focusSessionId: String
    let activityId: String
    let state: FocusSessionState
    let startedAt: Date
    let localDay: LocalDay
    let dailyPlanIdAtStart: String?
    let completedAt: Date?
    let focusEndsAt: Date?
    let restState: FocusRestState
    let restEndsAt: Date?
    let isBonusSession: Bool

    private enum CodingKeys: String, CodingKey {
        case focusSessionId
        case activityId
        case state
        case startedAt
        case localDay = "local_day"
        case dailyPlanIdAtStart = "daily_plan_id_at_start"
        case completedAt
        case focusEndsAt
        case restState
        case restEndsAt
        case isBonusSession
    }

    var id: String {
        focusSessionId
    }

    var durationSeconds: Int {
        Self.durationMinutes * 60
    }

    var durationMinutes: Int {
        Self.durationMinutes
    }

    var isResting: Bool {
        state == .completed && restState == .active
    }

    var earnsCompletionAwards: Bool {
        state == .completed
    }

    func updated(
        state: FocusSessionState,
        completedAt: Date? = nil,
        focusEndsAt: Date? = nil,
        restState: FocusRestState? = nil,
        restEndsAt: Date?? = nil,
        isBonusSession: Bool? = nil
    ) -> Self {
        Self(
            focusSessionId: focusSessionId,
            activityId: activityId,
            state: state,
            startedAt: startedAt,
            localDay: localDay,
            dailyPlanIdAtStart: dailyPlanIdAtStart,
            completedAt: completedAt ?? self.completedAt,
            focusEndsAt: focusEndsAt ?? self.focusEndsAt,
            restState: restState ?? self.restState,
            restEndsAt: restEndsAt ?? self.restEndsAt,
            isBonusSession: isBonusSession ?? self.isBonusSession
        )
    }

    init(
        focusSessionId: String,
        activityId: String,
        state: FocusSessionState,
        startedAt: Date,
        localDay: LocalDay? = nil,
        dailyPlanIdAtStart: String? = nil,
        completedAt: Date? = nil,
        focusEndsAt: Date? = nil,
        restState: FocusRestState = .unavailable,
        restEndsAt: Date? = nil,
        isBonusSession: Bool = false
    ) {
        self.focusSessionId = focusSessionId
        self.activityId = activityId
        self.state = state
        self.startedAt = startedAt
        self.localDay = localDay ?? LocalDay(containing: startedAt, calendar: .current)
        self.dailyPlanIdAtStart = dailyPlanIdAtStart
        self.completedAt = completedAt
        self.focusEndsAt = focusEndsAt
        self.restState = restState
        self.restEndsAt = restEndsAt
        self.isBonusSession = isBonusSession
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.init(
            focusSessionId: try container.decode(String.self, forKey: .focusSessionId),
            activityId: try container.decode(String.self, forKey: .activityId),
            state: try container.decode(FocusSessionState.self, forKey: .state),
            startedAt: startedAt,
            localDay: try container.decodeIfPresent(LocalDay.self, forKey: .localDay)
                ?? LocalDay(containing: startedAt, calendar: .current),
            dailyPlanIdAtStart: try container.decodeIfPresent(String.self, forKey: .dailyPlanIdAtStart),
            completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt),
            focusEndsAt: try container.decodeIfPresent(Date.self, forKey: .focusEndsAt),
            restState: try container.decodeIfPresent(FocusRestState.self, forKey: .restState) ?? .unavailable,
            restEndsAt: try container.decodeIfPresent(Date.self, forKey: .restEndsAt),
            isBonusSession: try container.decodeIfPresent(Bool.self, forKey: .isBonusSession) ?? false
        )
    }

    var eventParameters: [String: Any] {
        [
            "focus_session_id": focusSessionId,
            "focus_session_activity_id": activityId,
            "focus_session_state": state.rawValue,
            "focus_session_started_at": startedAt,
            "focus_session_ends_at": focusEndsAt as Any,
            "focus_session_rest_state": restState.rawValue,
            "focus_session_rest_ends_at": restEndsAt as Any,
            "focus_session_is_bonus": isBonusSession
        ]
    }

    static var mock: Self {
        readyMock
    }

    static var readyMock: Self {
        Self(
            focusSessionId: "focus-session-ready",
            activityId: ActivityModel.mock.activityId,
            state: .ready,
            startedAt: fixtureDate
        )
    }

    static var runningMock: Self {
        Self(
            focusSessionId: "focus-session-running",
            activityId: ActivityModel.mock.activityId,
            state: .running,
            startedAt: fixtureDate
        )
    }

    static var completedMock: Self {
        Self(
            focusSessionId: "focus-session-completed",
            activityId: ActivityModel.mock.activityId,
            state: .completed,
            startedAt: fixtureDate,
            completedAt: fixtureDate.addingTimeInterval(25 * 60),
            restState: .skipped
        )
    }

    static var restingMock: Self {
        Self(
            focusSessionId: "focus-session-resting",
            activityId: ActivityModel.mock.activityId,
            state: .completed,
            startedAt: fixtureDate,
            completedAt: fixtureDate.addingTimeInterval(25 * 60),
            restState: .active,
            restEndsAt: fixtureDate.addingTimeInterval(30 * 60)
        )
    }

    static var abandonedMock: Self {
        Self(
            focusSessionId: "focus-session-abandoned",
            activityId: ActivityModel.mock.activityId,
            state: .abandoned,
            startedAt: fixtureDate
        )
    }

    private static let fixtureDate = Date(timeIntervalSince1970: 1_756_944_000)
}
