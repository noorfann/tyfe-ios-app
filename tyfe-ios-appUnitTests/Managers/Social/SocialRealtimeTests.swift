import Foundation
import Observation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SocialRealtimeTests {

    @Test func sendingAndFetchingCheers() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)

        try await manager.sendCheer(.heart, senderId: "u1", recipientId: "u2", localDate: today)
        try await manager.refreshCheers(localDate: today)

        #expect(manager.cheers.count == 1)
        #expect(manager.cheers.first?.kind == .heart)
        #expect(manager.cheers.first?.recipientId == "u2")
    }

    @Test func cheerStreamDeliversSentCheers() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)
        manager.startCheerDelivery(recipientId: "u1")

        try await manager.sendCheer(.fire, senderId: "u1", recipientId: "u2", localDate: today)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(manager.cheers.contains { $0.kind == .fire })
    }

    @Test func receivedCheersAreFetched() async throws {
        let service = makeService()
        let today = LocalDay(containing: .now, calendar: .current)
        service.seedCheer(CheerModel(
            cheerId: "seeded",
            senderId: "u2",
            recipientId: "u1",
            localDate: today.socialDateString,
            kind: .star,
            createdAt: .now
        ))
        let manager = SocialManager(service: service)

        try await manager.refreshCheers(localDate: today)

        #expect(manager.cheers.contains { $0.senderId == "u2" && $0.kind == .star })
    }

    @Test func cannotCheerNonMember() async {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)

        do {
            try await manager.sendCheer(.clap, senderId: "u1", recipientId: "stranger", localDate: today)
            Issue.record("Expected notPermitted")
        } catch let error as SocialServiceError {
            #expect(error == .notPermitted)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func focusStatusStreamTracksUpdates() async throws {
        let manager = SocialManager(service: makeService())
        manager.startFocusStatus(circleId: "c1")

        await manager.updateFocusStatus(.focusing, userId: "u2", circleId: "c1")
        try await Task.sleep(nanoseconds: 50_000_000)

        let entries = try #require(manager.focusStatusesByCircle["c1"])
        #expect(entries.contains { $0.userId == "u2" && $0.status == .focusing })
    }

    @Test func signOutStopsRealtimeAndClearsState() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)
        manager.startCheerDelivery(recipientId: "u1")
        manager.startFocusStatus(circleId: "c1")
        try await manager.sendCheer(.clap, senderId: "u1", recipientId: "u2", localDate: today)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(!manager.cheers.isEmpty)

        manager.signOut()

        #expect(manager.cheers.isEmpty)
        #expect(manager.focusStatusesByCircle.isEmpty)
        #expect(manager.activeFocusCircleIds.isEmpty)
    }

    @Test func setFocusCirclesStartsAndStopsChannels() async throws {
        let manager = SocialManager(service: makeService())

        manager.setFocusCircles(["c1"])
        #expect(manager.activeFocusCircleIds == ["c1"])

        await manager.updateFocusStatus(.focusing, userId: "u1", circleId: "c1")
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(manager.focusStatusesByCircle["c1"] != nil)

        manager.setFocusCircles([])
        #expect(manager.activeFocusCircleIds.isEmpty)
        #expect(manager.focusStatusesByCircle["c1"] == nil)
    }

    @Test func startRealtimeDeliversCheersAndTracksCircles() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)

        manager.startRealtime(circleIds: ["c1"], recipientId: "u1")
        try await manager.sendCheer(.star, senderId: "u1", recipientId: "u2", localDate: today)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(manager.activeFocusCircleIds == ["c1"])
        #expect(manager.cheers.contains { $0.kind == .star })
    }

    @Test func incomingCheersAreQueuedForTheRecipient() async throws {
        let service = makeService()
        let manager = SocialManager(service: service)
        manager.startCheerDelivery(recipientId: "u1")

        await seedCheerAndWait(
            CheerModel(
                cheerId: "incoming",
                senderId: "u2",
                recipientId: "u1",
                localDate: LocalDay(containing: .now, calendar: .current).socialDateString,
                kind: .heart,
                createdAt: .now
            ),
            service: service,
            manager: manager
        )

        #expect(manager.pendingReceivedCheers.map(\.kind) == [.heart])
    }

    @Test func outgoingCheersDoNotEnterTheReceivedQueue() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)
        manager.startCheerDelivery(recipientId: "u1")

        try await manager.sendCheer(.fire, senderId: "u1", recipientId: "u2", localDate: today)
        try await Task.sleep(for: .milliseconds(50))

        #expect(manager.cheers.contains { $0.kind == .fire })
        #expect(manager.pendingReceivedCheers.isEmpty)
    }

    @Test func consumingReceivedCheersReturnsTheBatchAndClearsIt() async throws {
        let service = makeService()
        let manager = SocialManager(service: service)
        manager.startCheerDelivery(recipientId: "u1")

        for (id, kind) in [("heart", CheerKind.heart), ("star", CheerKind.star)] {
            await seedCheerAndWait(
                CheerModel(
                    cheerId: id,
                    senderId: "u2",
                    recipientId: "u1",
                    localDate: LocalDay(containing: .now, calendar: .current).socialDateString,
                    kind: kind,
                    createdAt: .now
                ),
                service: service,
                manager: manager
            )
        }

        let batch = manager.consumePendingReceivedCheers()

        #expect(batch.map(\.kind) == [.heart, .star])
        #expect(manager.pendingReceivedCheers.isEmpty)
    }

    @Test func signOutClearsPendingReceivedCheers() async throws {
        let service = makeService()
        let manager = SocialManager(service: service)
        manager.startCheerDelivery(recipientId: "u1")
        await seedCheerAndWait(
            CheerModel(
                cheerId: "incoming",
                senderId: "u2",
                recipientId: "u1",
                localDate: LocalDay(containing: .now, calendar: .current).socialDateString,
                kind: .clap,
                createdAt: .now
            ),
            service: service,
            manager: manager
        )

        manager.signOut()

        #expect(manager.pendingReceivedCheers.isEmpty)
    }

    private func seedCheerAndWait(
        _ cheer: CheerModel,
        service: MockSocialService,
        manager: SocialManager
    ) async {
        await confirmation("Received cheer is queued") { confirmation in
            _ = withObservationTracking {
                manager.pendingReceivedCheers.count
            } onChange: {
                confirmation()
            }
            service.seedCheer(cheer)
            await Task.yield()
        }
    }

    private func makeService() -> MockSocialService {
        MockSocialService(
            currentUserId: "u1",
            circles: [CircleModel(circleId: "c1", name: "Circle", ownerId: "u1", createdAt: .now, updatedAt: .now)],
            memberships: [
                CircleMembershipModel(membershipId: "m1", circleId: "c1", userId: "u1", role: .owner, joinedAt: .now),
                CircleMembershipModel(membershipId: "m2", circleId: "c1", userId: "u2", role: .member, joinedAt: .now)
            ]
        )
    }
}
