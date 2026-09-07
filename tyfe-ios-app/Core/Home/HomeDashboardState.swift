import Foundation

struct HomeDashboardState: Equatable {
    let nextActivity: ActivityModel?
    let plannedSessionCount: Int
    let completedSessionCount: Int
    let rewardCredits: Int
    let activeFocusSession: FocusSessionModel?
    let activeFocusActivity: ActivityModel?
}

extension HomeDashboardState {
    static let empty = Self(
        nextActivity: nil,
        plannedSessionCount: 0,
        completedSessionCount: 0,
        rewardCredits: 0,
        activeFocusSession: nil,
        activeFocusActivity: nil
    )
}
