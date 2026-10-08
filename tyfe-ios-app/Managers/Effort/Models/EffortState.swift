import Foundation

struct EffortState: Codable, Hashable, Sendable {
    var updatedAt: Date?
    var migrationDay: LocalDay?
    var lastPreparedDay: LocalDay?
    var sessionRepeatRetiredDay: LocalDay?
    var tasks: [TodoTaskModel] = []
    var taskHistory: [TodoCompletionRecord] = []
    var habits: [HabitModel] = []
    var occurrences: [HabitOccurrence] = []
    var days: [EffortDayRecord] = []
    var streakBaselines: [EffortStreakBaseline] = []

    private enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case migrationDay = "migration_day"
        case lastPreparedDay = "last_prepared_day"
        case sessionRepeatRetiredDay = "session_repeat_retired_day"
        case tasks
        case taskHistory = "task_history"
        case habits
        case occurrences
        case days
        case streakBaselines = "streak_baselines"
    }
}
