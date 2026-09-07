import SwiftUI

@MainActor
protocol FocusInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }

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
        try focusManager.refreshFocusSession(focusSessionId: focusSessionId)
    }

    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        try focusManager.beginFocusSession(focusSessionId: focusSessionId)
    }

    func pauseFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        try focusManager.pauseFocusSession(focusSessionId: focusSessionId)
    }

    func resumeFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        try focusManager.resumeFocusSession(focusSessionId: focusSessionId)
    }

    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        try focusManager.abandonFocusSession(focusSessionId: focusSessionId)
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
