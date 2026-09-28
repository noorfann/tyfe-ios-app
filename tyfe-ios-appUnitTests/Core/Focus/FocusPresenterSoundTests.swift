import SwiftUI
import SwiftfulRouting
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusPresenterSoundTests {

    @Test func soundFilesAreInTheAppBundle() {
        #expect(Bundle.main.url(forResource: SoundEffectFile.start.fileName, withExtension: nil) != nil)
        #expect(Bundle.main.url(forResource: SoundEffectFile.finish.fileName, withExtension: nil) != nil)
    }

    @Test func confirmedStartPlaysOnlyAfterSuccess() {
        let interactor = RecordingFocusSoundInteractor()
        let presenter = makePresenter(interactor: interactor)
        let delegate = FocusDelegate(activity: .mock, session: interactor.session)
        presenter.onViewAppear(delegate: delegate)

        presenter.onPrimaryActionPressed()
        #expect(interactor.playedSounds.isEmpty)

        presenter.beginFocusAfterConfirmation()
        #expect(interactor.playedSounds == [.start])
        presenter.onViewDisappear(delegate: delegate)
        #expect(interactor.preparedSounds == [.start, .finish])
        #expect(interactor.tornDownSounds == [.start, .finish])
    }

    @Test func failedStartStaysSilent() {
        let interactor = RecordingFocusSoundInteractor()
        interactor.beginError = .persistenceFailed
        let presenter = makePresenter(interactor: interactor)

        presenter.beginFocusAfterConfirmation()

        #expect(interactor.playedSounds.isEmpty)
        #expect(presenter.session.state == .ready)
    }

    @Test func timerCompletionPlaysOnceWhileActive() {
        let interactor = RecordingFocusSoundInteractor()
        interactor.session = interactor.session.updated(state: .running)
        let presenter = makePresenter(interactor: interactor)
        let delegate = FocusDelegate(activity: .mock, session: interactor.session)
        presenter.onViewAppear(delegate: delegate)

        interactor.session = interactor.session.updated(state: .completed)
        presenter.onTimerTick()
        presenter.onTimerTick()

        #expect(interactor.playedSounds == [.finish])
        presenter.onViewDisappear(delegate: delegate)
    }

    @Test func backgroundCompletionDoesNotReplayOnResume() {
        let interactor = RecordingFocusSoundInteractor()
        interactor.session = interactor.session.updated(state: .running)
        let presenter = makePresenter(interactor: interactor)
        let delegate = FocusDelegate(activity: .mock, session: interactor.session)
        presenter.onViewAppear(delegate: delegate)

        presenter.onSceneBecameInactive()
        interactor.session = interactor.session.updated(state: .completed)
        presenter.onSceneBecameActive()
        presenter.onTimerTick()

        #expect(interactor.playedSounds.isEmpty)
        presenter.onViewDisappear(delegate: delegate)
    }

#if MOCK
    @Test func mockCompletionPlaysOnce() {
        let interactor = RecordingFocusSoundInteractor()
        interactor.session = interactor.session.updated(state: .running)
        let presenter = makePresenter(interactor: interactor)
        let delegate = FocusDelegate(activity: .mock, session: interactor.session)
        presenter.onViewAppear(delegate: delegate)

        presenter.onMarkCompletePressed()
        presenter.onMarkCompletePressed()

        #expect(interactor.playedSounds == [.finish])
        presenter.onViewDisappear(delegate: delegate)
    }
#endif

    private func makePresenter(interactor: RecordingFocusSoundInteractor) -> FocusPresenter {
        FocusPresenter(
            interactor: interactor,
            router: RecordingFocusSoundRouter(),
            session: interactor.session
        )
    }
}

@MainActor
private struct RecordingFocusSoundRouter: FocusRouter {
    let router = RouterEnvironmentKey.defaultValue
}

@MainActor
private final class RecordingFocusSoundInteractor: FocusInteractor {
    var session = FocusSessionModel.readyMock
    var beginError: FocusManagerError?
    private(set) var preparedSounds: [SoundEffectFile] = []
    private(set) var playedSounds: [SoundEffectFile] = []
    private(set) var tornDownSounds: [SoundEffectFile] = []

    var activeFocusSession: FocusSessionModel? { session }

    func setFocusScreenVisible(_ isVisible: Bool) { }
    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh {
        FocusSessionRefresh(
            session: session,
            remainingFocusSeconds: session.durationSeconds,
            remainingRestSeconds: 0,
            completion: nil
        )
    }
    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        if let beginError { throw beginError }
        session = session.updated(state: .running)
        return session
    }
    func startFocusRest(focusSessionId: String) throws -> FocusSessionModel { session }
    func completeFocusRest(focusSessionId: String) throws -> FocusSessionModel { session }
    func skipFocusRest(focusSessionId: String) throws -> FocusSessionModel { session }
    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel { session }
    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel { session }
#if MOCK
    func markFocusSessionCompleteForTesting(focusSessionId: String) throws -> FocusSessionModel {
        session = session.updated(state: .completed)
        return session
    }
#endif

    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) { }
    func trackEvent(event: AnyLoggableEvent) { }
    func trackEvent(event: LoggableEvent) { }
    func trackScreenEvent(event: LoggableEvent) { }
    func prepareHaptic(option: HapticOption) { }
    func prepareHaptics(options: [HapticOption]) { }
    func playHaptic(option: HapticOption) { }
    func playHaptics(options: [HapticOption]) { }
    func tearDownHaptic(option: HapticOption) { }
    func tearDownHaptics(options: [HapticOption]) { }
    func tearDownAllHaptics() { }
    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int) {
        preparedSounds.append(sound)
    }
    func playSoundEffect(sound: SoundEffectFile) {
        playedSounds.append(sound)
    }
    func tearDownSoundEffect(sound: SoundEffectFile) {
        tornDownSounds.append(sound)
    }
}
