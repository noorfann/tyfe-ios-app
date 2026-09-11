import SwiftUI

@MainActor
protocol FocusInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }

    func setFocusScreenVisible(_ isVisible: Bool)
    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh
    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func pauseFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func resumeFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel
#if MOCK
    func markFocusSessionCompleteForTesting(focusSessionId: String) throws -> FocusSessionModel
#endif
}

extension CoreInteractor: FocusInteractor {
    var activeFocusSession: FocusSessionModel? {
        focusManager.activeFocusSession
    }

    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh {
        let refresh = try focusManager.refreshFocusSession(focusSessionId: focusSessionId)
        if refresh.completion != nil {
            scheduleSharedProgressSync(for: refresh.session.localDay)
            Task { await updateSocialFocusStatus(.available) }
        }
        return refresh
    }

    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try focusManager.beginFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.focusing) }
        return session
    }

    func pauseFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try focusManager.pauseFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.available) }
        return session
    }

    func resumeFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try focusManager.resumeFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.focusing) }
        return session
    }

    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try focusManager.abandonFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.available) }
        return session
    }

    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel {
        try focusManager.startAnotherFocusSession(activityId: activityId)
    }

#if MOCK
    func markFocusSessionCompleteForTesting(focusSessionId: String) throws -> FocusSessionModel {
        try focusManager.markFocusSessionCompleteForTesting(focusSessionId: focusSessionId)
    }
#endif
}
