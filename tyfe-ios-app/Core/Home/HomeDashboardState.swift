import Foundation

struct HomeDashboardState: Equatable {
    let nextActivity: ActivityModel?
    let plannedSessionCount: Int
    let completedSessionCount: Int
    let plannedChecklistItemCount: Int
    let completedChecklistItemCount: Int
    let activeFocusSession: FocusSessionModel?
    let activeFocusActivity: ActivityModel?
}

extension HomeDashboardState {
    static let empty = Self(
        nextActivity: nil,
        plannedSessionCount: 0,
        completedSessionCount: 0,
        plannedChecklistItemCount: 0,
        completedChecklistItemCount: 0,
        activeFocusSession: nil,
        activeFocusActivity: nil
    )
}
