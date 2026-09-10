import Foundation

struct DailyPlanProgressModel: Codable, Equatable, Hashable, Sendable {
    let localDay: LocalDay
    let originalPlannedSessionCount: Int
    let finalPlannedSessionCount: Int
    let plannedCompletionCount: Int
    let bonusCompletionCount: Int

    var isSuccessful: Bool {
        plannedCompletionCount >= finalPlannedSessionCount
    }
}
