import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SocialLaunchSyncTests {

    @Test func launchSyncStartsRealtimeWithoutPriorCirclesLoad() async {
        let context = makeContext()

        await context.interactor.syncSocialRealtime()

        #expect(context.manager.activeFocusCircleIds == ["c1"])
    }

    @Test func launchSyncPublishesAvailableWhenNoSessionIsRunning() async throws {
        let context = makeContext()

        await context.interactor.syncSocialRealtime()
        try await Task.sleep(for: .milliseconds(50))

        let entries = context.manager.focusStatusesByCircle["c1"] ?? []
        #expect(entries.contains {
            $0.userId == context.userId.lowercased() && $0.status == .available
        })
    }

    @Test func launchSyncPublishesFocusingForRunningSession() async throws {
        let context = makeContext()
        let session = try #require(
            context.interactor.focusManager.startFocusSession(activityId: ActivityModel.mock.activityId)
        )
        _ = try context.interactor.focusManager.beginFocusSession(focusSessionId: session.focusSessionId)

        await context.interactor.syncSocialRealtime()
        try await Task.sleep(for: .milliseconds(50))

        let entries = context.manager.focusStatusesByCircle["c1"] ?? []
        #expect(entries.contains {
            $0.userId == context.userId.lowercased() && $0.status == .focusing
        })
    }

    private func makeContext() -> SocialLaunchSyncTestContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let userId = UserAuthInfo.mock().uid
        let service = MockSocialService(
            currentUserId: userId,
            circles: [
                CircleModel(
                    circleId: "c1",
                    name: "Circle",
                    ownerId: userId,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            memberships: [
                CircleMembershipModel(
                    membershipId: "m1",
                    circleId: "c1",
                    userId: userId,
                    role: .owner,
                    joinedAt: .now
                )
            ]
        )
        let manager = SocialManager(service: service)
        dependencies.container.register(SocialManager.self, service: manager)
        let interactor = CoreInteractor(container: dependencies.container)
        return SocialLaunchSyncTestContext(interactor: interactor, manager: manager, userId: userId)
    }
}

@MainActor
private struct SocialLaunchSyncTestContext {
    let interactor: CoreInteractor
    let manager: SocialManager
    let userId: String
}
