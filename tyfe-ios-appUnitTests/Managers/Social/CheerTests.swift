import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct CheerTests {

    @Test func duplicateSameKindCheerIsIgnored() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)

        try await manager.sendCheer(.heart, senderId: "u1", recipientId: "u2", localDate: today)
        try await manager.sendCheer(.heart, senderId: "u1", recipientId: "u2", localDate: today)
        try await manager.refreshCheers(localDate: today)

        let hearts = manager.cheers.filter {
            $0.senderId == "u1" && $0.recipientId == "u2" && $0.kind == .heart
        }
        #expect(hearts.count == 1)
    }

    @Test func differentKindsAreAllowedOnTheSameDay() async throws {
        let manager = SocialManager(service: makeService())
        let today = LocalDay(containing: .now, calendar: .current)

        try await manager.sendCheer(.heart, senderId: "u1", recipientId: "u2", localDate: today)
        try await manager.sendCheer(.fire, senderId: "u1", recipientId: "u2", localDate: today)
        try await manager.refreshCheers(localDate: today)

        let kinds = Set(
            manager.cheers
                .filter { $0.senderId == "u1" && $0.recipientId == "u2" }
                .map(\.kind)
        )
        #expect(kinds == [.heart, .fire])
    }

    @Test func sentKindsMatchesRecipientAndIgnoresCase() {
        let cheers = [
            CheerModel(cheerId: "1", senderId: "U1", recipientId: "U2", localDate: "2026-09-17", kind: .heart, createdAt: .now),
            CheerModel(cheerId: "2", senderId: "u1", recipientId: "u2", localDate: "2026-09-17", kind: .fire, createdAt: .now),
            CheerModel(cheerId: "3", senderId: "u1", recipientId: "u3", localDate: "2026-09-17", kind: .star, createdAt: .now),
            CheerModel(cheerId: "4", senderId: "u2", recipientId: "u1", localDate: "2026-09-17", kind: .clap, createdAt: .now)
        ]

        #expect(CheerModel.sentKinds(in: cheers, from: "u1", to: "u2") == [.heart, .fire])
        #expect(CheerModel.sentKinds(in: cheers, from: "u1", to: "u3") == [.star])
        #expect(CheerModel.sentKinds(in: cheers, from: "u2", to: "u1") == [.clap])
        #expect(CheerModel.sentKinds(in: cheers, from: nil, to: "u2").isEmpty)
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
