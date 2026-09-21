import Foundation
import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct ModuleWrapperPresenterTests {

    @Test func matchingFocusDeepLinkPostsNavigationForTheActiveSession() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
        let session = try #require(
            focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try focusManager.beginFocusSession(focusSessionId: session.focusSessionId)

        let recorder = NotificationRecorder()
        NotificationCenter.default.addObserver(
            recorder,
            selector: #selector(NotificationRecorder.receive(_:)),
            name: .focusLiveActivityNavigation,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(recorder) }

        let presenter = ModuleWrapperPresenter(
            interactor: interactor,
            router: RecordingModuleWrapperRouter()
        )
        let url = try #require(
            URL(string: "tyfe://focus?sessionId=\(session.focusSessionId)")
        )

        presenter.handleDeepLink(
            url: url,
            delegate: ModuleWrapperDelegate(moduleId: Constants.tabbarModuleId)
        )

        #expect(recorder.sessionId == session.focusSessionId)
    }

    @Test func staleMissingAndNonActiveFocusDeepLinksAreIgnored() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
        let readySession = try #require(
            focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )

        let recorder = NotificationRecorder()
        NotificationCenter.default.addObserver(
            recorder,
            selector: #selector(NotificationRecorder.receive(_:)),
            name: .focusLiveActivityNavigation,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(recorder) }

        let presenter = ModuleWrapperPresenter(
            interactor: interactor,
            router: RecordingModuleWrapperRouter()
        )
        let delegate = ModuleWrapperDelegate(moduleId: Constants.tabbarModuleId)

        let nonActiveURL = try #require(
            URL(string: "tyfe://focus?sessionId=\(readySession.focusSessionId)")
        )
        presenter.handleDeepLink(url: nonActiveURL, delegate: delegate)

        _ = try focusManager.beginFocusSession(focusSessionId: readySession.focusSessionId)
        let staleURL = try #require(URL(string: "tyfe://focus?sessionId=missing"))
        presenter.handleDeepLink(url: staleURL, delegate: delegate)
        let missingSessionURL = try #require(URL(string: "tyfe://focus"))
        presenter.handleDeepLink(url: missingSessionURL, delegate: delegate)

        #expect(recorder.sessionId == nil)
    }
}

@MainActor
private final class RecordingModuleWrapperRouter: ModuleWrapperRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this test double") }
}

private final class NotificationRecorder: NSObject {
    private(set) var sessionId: String?

    @objc func receive(_ notification: Notification) {
        sessionId = notification.userInfo?["focusSessionId"] as? String
    }
}
