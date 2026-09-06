import Foundation

enum FocusSessionState: String, Codable, CaseIterable, Hashable {
    case ready
    case running
    case paused
    case completed
    case abandoned

    var displayName: String {
        switch self {
        case .ready: return "Ready"
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .completed: return "Complete"
        case .abandoned: return "Incomplete"
        }
    }

    var symbolName: String {
        switch self {
        case .ready: return "play.fill"
        case .running: return "timer"
        case .paused: return "pause.fill"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "stop.circle.fill"
        }
    }
}

struct FocusSessionModel: Identifiable, Codable, Hashable {
    static let durationMinutes = 25
    static let pauseAllowanceSeconds = 300

    let focusSessionId: String
    let activityId: String
    let state: FocusSessionState
    let startedAt: Date
    let pausedAt: Date?
    let completedAt: Date?
    let focusEndsAt: Date?
    let pauseUsed: Bool
    let pauseRemainingSeconds: Int
    let isBonusSession: Bool

    private enum CodingKeys: String, CodingKey {
        case focusSessionId
        case activityId
        case state
        case startedAt
        case pausedAt
        case completedAt
        case focusEndsAt
        case pauseUsed
        case pauseRemainingSeconds
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

    var pauseAllowanceSeconds: Int {
        Self.pauseAllowanceSeconds
    }

    var earnsCompletionAwards: Bool {
        state == .completed
    }

    func updated(
        state: FocusSessionState,
        pausedAt: Date? = nil,
        completedAt: Date? = nil,
        focusEndsAt: Date? = nil,
        pauseUsed: Bool? = nil,
        pauseRemainingSeconds: Int? = nil
    ) -> Self {
        Self(
            focusSessionId: focusSessionId,
            activityId: activityId,
            state: state,
            startedAt: startedAt,
            pausedAt: pausedAt ?? self.pausedAt,
            completedAt: completedAt ?? self.completedAt,
            focusEndsAt: focusEndsAt ?? self.focusEndsAt,
            pauseUsed: pauseUsed ?? self.pauseUsed,
            pauseRemainingSeconds: pauseRemainingSeconds ?? self.pauseRemainingSeconds,
            isBonusSession: isBonusSession
        )
    }

    init(
        focusSessionId: String,
        activityId: String,
        state: FocusSessionState,
        startedAt: Date,
        pausedAt: Date? = nil,
        completedAt: Date? = nil,
        focusEndsAt: Date? = nil,
        pauseUsed: Bool = false,
        pauseRemainingSeconds: Int = FocusSessionModel.pauseAllowanceSeconds,
        isBonusSession: Bool = false
    ) {
        self.focusSessionId = focusSessionId
        self.activityId = activityId
        self.state = state
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.completedAt = completedAt
        self.focusEndsAt = focusEndsAt
        self.pauseUsed = pauseUsed
        self.pauseRemainingSeconds = min(max(pauseRemainingSeconds, 0), Self.pauseAllowanceSeconds)
        self.isBonusSession = isBonusSession
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            focusSessionId: try container.decode(String.self, forKey: .focusSessionId),
            activityId: try container.decode(String.self, forKey: .activityId),
            state: try container.decode(FocusSessionState.self, forKey: .state),
            startedAt: try container.decode(Date.self, forKey: .startedAt),
            pausedAt: try container.decodeIfPresent(Date.self, forKey: .pausedAt),
            completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt),
            focusEndsAt: try container.decodeIfPresent(Date.self, forKey: .focusEndsAt),
            pauseUsed: try container.decodeIfPresent(Bool.self, forKey: .pauseUsed) ?? false,
            pauseRemainingSeconds: try container.decodeIfPresent(Int.self, forKey: .pauseRemainingSeconds) ?? Self.pauseAllowanceSeconds,
            isBonusSession: try container.decodeIfPresent(Bool.self, forKey: .isBonusSession) ?? false
        )
    }

    var eventParameters: [String: Any] {
        [
            "focus_session_id": focusSessionId,
            "focus_session_activity_id": activityId,
            "focus_session_state": state.rawValue,
            "focus_session_started_at": startedAt,
            "focus_session_pause_used": pauseUsed,
            "focus_session_pause_remaining_seconds": pauseRemainingSeconds,
            "focus_session_ends_at": focusEndsAt as Any,
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

    static var pausedMock: Self {
        Self(
            focusSessionId: "focus-session-paused",
            activityId: ActivityModel.mock.activityId,
            state: .paused,
            startedAt: fixtureDate,
            pausedAt: fixtureDate.addingTimeInterval(21 * 60),
            pauseUsed: true,
            pauseRemainingSeconds: 240
        )
    }

    static var completedMock: Self {
        Self(
            focusSessionId: "focus-session-completed",
            activityId: ActivityModel.mock.activityId,
            state: .completed,
            startedAt: fixtureDate,
            completedAt: fixtureDate.addingTimeInterval(25 * 60)
        )
    }

    static var abandonedMock: Self {
        Self(
            focusSessionId: "focus-session-abandoned",
            activityId: ActivityModel.mock.activityId,
            state: .abandoned,
            startedAt: fixtureDate,
            pauseUsed: true,
            pauseRemainingSeconds: 0
        )
    }

    private static let fixtureDate = Date(timeIntervalSince1970: 1_756_944_000)
}
