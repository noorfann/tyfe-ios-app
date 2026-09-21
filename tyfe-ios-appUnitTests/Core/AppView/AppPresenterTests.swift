import Observation
import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct AppPresenterTests {

    @Test func pendingCheersBecomeOneMixedCelebration() async throws {
        let context = makeContext()
        context.presenter.onScenePhaseChanged(.active)
        context.manager.startCheerDelivery(recipientId: context.recipientId)
        await seedCheerAndWait(.heart, id: "heart", context: context)
        await seedCheerAndWait(.fire, id: "fire", context: context)

        context.presenter.presentPendingCheers()

        #expect(context.presenter.activeCheerKinds == [.heart, .fire])
        #expect(context.manager.pendingReceivedCheers.isEmpty)
        context.presenter.onViewDisappear()
    }

    @Test func completedCelebrationCanAdvanceToTheWaitingBatch() async throws {
        let context = makeContext()
        context.presenter.onScenePhaseChanged(.active)
        context.manager.startCheerDelivery(recipientId: context.recipientId)
        await seedCheerAndWait(.heart, id: "heart", context: context)
        context.presenter.presentPendingCheers()
        await seedCheerAndWait(.star, id: "star", context: context)

        context.presenter.onCheerCelebrationCompleted()
        context.presenter.presentPendingCheers()

        #expect(context.presenter.activeCheerKinds == [.star])
        context.presenter.onViewDisappear()
    }

    @Test func leavingTheForegroundDiscardsPendingAndActiveCheers() async throws {
        let context = makeContext()
        context.presenter.onScenePhaseChanged(.active)
        context.manager.startCheerDelivery(recipientId: context.recipientId)
        await seedCheerAndWait(.clap, id: "clap", context: context)
        context.presenter.presentPendingCheers()

        context.presenter.onScenePhaseChanged(.background)

        #expect(context.presenter.activeCheerKinds.isEmpty)
        #expect(context.manager.pendingReceivedCheers.isEmpty)
    }

    @Test func enteringTheForegroundReconcilesTheFocusLiveActivity() {
        let interactor = RecordingAppViewInteractor()
        let presenter = AppPresenter(interactor: interactor)

        presenter.onScenePhaseChanged(.active)
        presenter.onScenePhaseChanged(.background)
        presenter.onScenePhaseChanged(.active)

        #expect(interactor.focusLiveActivityReconciliationCount == 2)
    }

    private func makeContext() -> AppPresenterTestContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let service = MockSocialService(currentUserId: UserAuthInfo.mock().uid)
        let manager = SocialManager(service: service)
        dependencies.container.register(SocialManager.self, service: manager)
        let presenter = AppPresenter(interactor: CoreInteractor(container: dependencies.container))
        return AppPresenterTestContext(
            presenter: presenter,
            manager: manager,
            service: service,
            recipientId: UserAuthInfo.mock().uid
        )
    }

    private func seedCheerAndWait(
        _ kind: CheerKind,
        id: String,
        context: AppPresenterTestContext
    ) async {
        await confirmation("Received cheer is queued") { confirmation in
            _ = withObservationTracking {
                context.manager.pendingReceivedCheers.count
            } onChange: {
                confirmation()
            }
            context.service.seedCheer(CheerModel(
                cheerId: id,
                senderId: "other-user",
                recipientId: context.recipientId,
                localDate: LocalDay(containing: .now, calendar: .current).socialDateString,
                kind: kind,
                createdAt: .now
            ))
            await Task.yield()
        }
    }
}

@MainActor
private struct AppPresenterTestContext {
    let presenter: AppPresenter
    let manager: SocialManager
    let service: MockSocialService
    let recipientId: String
}

@MainActor
private final class RecordingAppViewInteractor: AppViewInteractor {
    let auth: UserAuthInfo? = nil
    let startingModuleId = Constants.tabbarModuleId
    let colorScheme: ColorScheme = .light
    let pendingReceivedCheerCount = 0
    private(set) var focusLiveActivityReconciliationCount = 0

    func toggleColorScheme() {}

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {}

    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        (UserAuthInfo.mock(), false)
    }

    func syncSocialRealtime() async {}

    func consumePendingReceivedCheers() -> [CheerModel] {
        []
    }

    func discardPendingReceivedCheers() {}

    func synchronizeRewardCreditDay() {}

    func reconcileFocusLiveActivity() {
        focusLiveActivityReconciliationCount += 1
    }

    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {}
    func trackEvent(event: AnyLoggableEvent) {}
    func trackEvent(event: LoggableEvent) {}
    func trackScreenEvent(event: LoggableEvent) {}
    func prepareHaptic(option: HapticOption) {}
    func prepareHaptics(options: [HapticOption]) {}
    func playHaptic(option: HapticOption) {}
    func playHaptics(options: [HapticOption]) {}
    func tearDownHaptic(option: HapticOption) {}
    func tearDownHaptics(options: [HapticOption]) {}
    func tearDownAllHaptics() {}
    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int) {}
    func playSoundEffect(sound: SoundEffectFile) {}
    func tearDownSoundEffect(sound: SoundEffectFile) {}
}
