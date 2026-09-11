import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SocialProgressTests {

    @Test func publishingThenReadingCircleProgress() async throws {
        let service = MockSocialService(
            currentUserId: "u1",
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)]
        )
        let manager = SocialManager(service: service)
        let today = LocalDay(containing: .now, calendar: .current)

        try await manager.publishProgress(
            userId: "u1",
            localDay: today,
            plannedSessions: 3,
            completedSessions: 2
        )

        let progress = try await manager.circleProgress(circleId: "c1")
        let mine = try #require(progress.first { $0.userId == "u1" })
        #expect(mine.todayPlanned == 3)
        #expect(mine.todayCompleted == 2)
        #expect(mine.sevenDayCompleted == 2)
        #expect(mine.completionPercentage == 2.0 / 3.0)
    }

    @Test func publishingIsIdempotentPerDay() async throws {
        let service = MockSocialService(
            currentUserId: "u1",
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)]
        )
        let manager = SocialManager(service: service)
        let today = LocalDay(containing: .now, calendar: .current)

        try await manager.publishProgress(userId: "u1", localDay: today, plannedSessions: 3, completedSessions: 1)
        try await manager.publishProgress(userId: "u1", localDay: today, plannedSessions: 3, completedSessions: 2)

        #expect(service.snapshotCount(userId: "u1") == 1)

        let progress = try await manager.circleProgress(circleId: "c1")
        #expect(progress.first { $0.userId == "u1" }?.todayCompleted == 2)
    }

    @Test func sevenDayAggregateSumsRecentDays() async throws {
        let service = MockSocialService(
            currentUserId: "u1",
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)]
        )
        let manager = SocialManager(service: service)
        let today = LocalDay(containing: .now, calendar: .current)
        let yesterday = LocalDay(containing: today.startDate.addingTimeInterval(-86_400), calendar: .current)

        try await manager.publishProgress(userId: "u1", localDay: today, plannedSessions: 3, completedSessions: 2)
        try await manager.publishProgress(userId: "u1", localDay: yesterday, plannedSessions: 3, completedSessions: 1)

        let progress = try await manager.circleProgress(circleId: "c1")
        let mine = try #require(progress.first { $0.userId == "u1" })
        #expect(mine.todayCompleted == 2)
        #expect(mine.sevenDayCompleted == 3)
    }

    @Test func signOutClearsCachedProgress() async throws {
        let service = MockSocialService(
            currentUserId: "u1",
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)]
        )
        let manager = SocialManager(service: service)
        _ = try await manager.circleProgress(circleId: "c1")
        #expect(!manager.progressByCircle.isEmpty)

        manager.signOut()

        #expect(manager.progressByCircle.isEmpty)
    }

    @Test func nonMemberCannotReadCircleProgress() async {
        let service = MockSocialService(
            currentUserId: "outsider",
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)]
        )
        let manager = SocialManager(service: service)

        do {
            _ = try await manager.circleProgress(circleId: "c1")
            Issue.record("Expected notPermitted")
        } catch let error as SocialServiceError {
            #expect(error == .notPermitted)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeCircle(id: String, ownerId: String) -> CircleModel {
        CircleModel(circleId: id, name: "Circle", ownerId: ownerId, createdAt: .now, updatedAt: .now)
    }

    private func makeMembership(
        id: String,
        circleId: String,
        userId: String,
        role: CircleMemberRole
    ) -> CircleMembershipModel {
        CircleMembershipModel(
            membershipId: id,
            circleId: circleId,
            userId: userId,
            role: role,
            sharingPaused: false,
            joinedAt: .now
        )
    }
}
