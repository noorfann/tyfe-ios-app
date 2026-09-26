import Foundation

@MainActor
final class MockFocusLiveActivityScheduler: FocusLiveActivityScheduling {
    private(set) var startedSessions: [FocusSessionModel] = []
    private(set) var startedActivityTitles: [String] = []
    private(set) var endedSessions: [(session: FocusSessionModel, reason: FocusLiveActivityEndReason)] = []
    private(set) var reconciledSessions: [FocusSessionModel?] = []
    private(set) var reconciledActivityTitles: [String?] = []

    func start(for session: FocusSessionModel, activityTitle: String) {
        startedSessions.append(session)
        startedActivityTitles.append(activityTitle)
    }

    func end(for session: FocusSessionModel, reason: FocusLiveActivityEndReason) {
        endedSessions.append((session, reason))
    }

    func reconcile(activeSession: FocusSessionModel?, activityTitle: String?) {
        reconciledSessions.append(activeSession)
        reconciledActivityTitles.append(activityTitle)
    }
}
