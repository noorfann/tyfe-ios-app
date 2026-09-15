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
