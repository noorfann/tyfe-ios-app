import Foundation

struct DailyPlanProgressModel: Codable, Equatable, Hashable, Sendable {
    let localDay: LocalDay
    let originalPlannedSessionCount: Int
    let finalPlannedSessionCount: Int
    let completedUnitCount: Int

    var isSuccessful: Bool {
        completedUnitCount >= finalPlannedSessionCount
    }
}
