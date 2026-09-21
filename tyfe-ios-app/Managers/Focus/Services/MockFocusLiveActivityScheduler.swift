import Foundation

@MainActor
final class MockFocusLiveActivityScheduler: FocusLiveActivityScheduling {
    private(set) var startedSessions: [FocusSessionModel] = []
    private(set) var endedSessions: [(session: FocusSessionModel, reason: FocusLiveActivityEndReason)] = []
    private(set) var reconciledSessions: [FocusSessionModel?] = []

    func start(for session: FocusSessionModel) {
        startedSessions.append(session)
    }

    func end(for session: FocusSessionModel, reason: FocusLiveActivityEndReason) {
        endedSessions.append((session, reason))
    }

    func reconcile(activeSession: FocusSessionModel?) {
        reconciledSessions.append(activeSession)
    }
}
