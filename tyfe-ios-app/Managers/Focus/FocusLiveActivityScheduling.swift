import Foundation

enum FocusLiveActivityEndReason: Equatable {
    case completed
    case abandoned
}

@MainActor
protocol FocusLiveActivityScheduling: AnyObject {
    func start(for session: FocusSessionModel)
    func end(for session: FocusSessionModel, reason: FocusLiveActivityEndReason)
    func reconcile(activeSession: FocusSessionModel?)
}
