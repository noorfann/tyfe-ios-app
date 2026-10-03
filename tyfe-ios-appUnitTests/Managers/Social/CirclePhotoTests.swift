import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct CirclePhotoTests {
    @Test func photoResolutionKeepsIdentityAndRenewsBeforeExpiration() async throws {
        let clock = CirclePhotoClock()
        let profile = CirclePhotoService()
        let manager = makeManager(profile: profile, clock: clock)
        let member = try #require(try await manager.members(for: "circle").first)
        #expect(member.displayName == "Ada Lovelace")
        #expect(member.avatarToken == "🌻")
        #expect(member.avatarPath == "owner/photo.jpg")
        #expect(manager.photoURL(for: member) == URL(string: "https://example.test/photo/1"))

        clock.date.addTimeInterval(239)
        _ = try await manager.members(for: "circle")
        #expect(manager.photoURL(for: member) == URL(string: "https://example.test/photo/1"))
        clock.date.addTimeInterval(1)
        _ = try await manager.members(for: "circle")
        #expect(manager.photoURL(for: member) == URL(string: "https://example.test/photo/2"))
        clock.date.addTimeInterval(300)
        #expect(manager.photoURL(for: member) == nil)
    }

    @Test func failedResolutionKeepsMemberAndTokenFallback() async throws {
        let profile = CirclePhotoService()
        profile.shouldFail = true
        let manager = makeManager(profile: profile)
        let member = try #require(try await manager.members(for: "circle").first)
        #expect(manager.photoURL(for: member) == nil)
        #expect(member.displayName == "Ada Lovelace")
        #expect(member.avatarFallbackText == "🌻")
    }

    @Test func missingPhotosUseInitialsWithoutAResolver() async throws {
        let manager = makeManager(path: nil, token: nil)
        let member = try #require(try await manager.members(for: "circle").first)
        #expect(manager.photoURL(for: member) == nil)
        #expect(member.avatarFallbackText == "AL")
        let unknown = CircleMemberModel(userId: "other", displayName: " \n ", avatarToken: " ", role: .member, joinedAt: .distantPast)
        #expect(unknown.avatarFallbackText == "?")
    }

    @Test func completedPhotoResolutionCannotRepublishAfterLogout() async throws {
        let profile = CirclePhotoService()
        profile.suspendResolution = true
        let manager = makeManager(profile: profile)
        let request = Task { try await manager.members(for: "circle") }
        await profile.waitUntilResolving()
        manager.signOut()
        profile.finishResolution()
        await #expect(throws: CancellationError.self) { _ = try await request.value }
        #expect(manager.membersByCircle.isEmpty)
        let member = CircleMemberModel(userId: "owner", displayName: "Ada", avatarToken: nil, role: .owner, joinedAt: .distantPast, avatarPath: "owner/photo.jpg")
        #expect(manager.photoURL(for: member) == nil)
    }

    @Test func accountReplacementInvalidatesInFlightPhotosAndCachedIdentities() async throws {
        let profile = CirclePhotoService()
        profile.suspendResolution = true
        let manager = makeManager(profile: profile)
        manager.prepareAccount(userId: "owner")
        let request = Task { try await manager.members(for: "circle") }
        await profile.waitUntilResolving()
        manager.prepareAccount(userId: "new-account")
        profile.finishResolution()
        await #expect(throws: CancellationError.self) { _ = try await request.value }
        #expect(manager.membersByCircle.isEmpty)
        #expect(manager.progressByCircle.isEmpty)
        #expect(manager.circles.isEmpty)
    }

    @Test func cancelledResolutionDoesNotPublishItsURL() async throws {
        let profile = CirclePhotoService()
        profile.suspendResolution = true
        let manager = makeManager(profile: profile)
        let request = Task { try await manager.members(for: "circle") }
        await profile.waitUntilResolving()
        request.cancel()
        profile.finishResolution()
        await #expect(throws: CancellationError.self) { _ = try await request.value }
        let member = try #require(manager.membersByCircle["circle"]?.first)
        #expect(manager.photoURL(for: member) == nil)
    }

    @Test func sharedMockIdentityRefreshReplacesNameAndPhotoReference() async throws {
        let profile = CirclePhotoService()
        let service = makeSocialService(profile: profile)
        let manager = SocialManager(service: service, profileService: profile)
        profile.identity = ProfileIdentity(userId: "owner", displayName: "Updated Name", avatarToken: nil, avatarPath: "owner/new.jpg")
        let updated = try #require(try await manager.members(for: "circle").first)
        #expect(updated.displayName == "Updated Name")
        #expect(updated.avatarPath == "owner/new.jpg")
        #expect(updated.avatarFallbackText == "UN")
        #expect(manager.photoURL(for: updated) == URL(string: "https://example.test/photo/1"))
        profile.identity = ProfileIdentity(userId: "owner", displayName: "Latest Name", avatarToken: nil, avatarPath: nil)
        let removed = try #require(try await manager.members(for: "circle").first)
        #expect(removed.displayName == "Latest Name")
        #expect(manager.photoURL(for: removed) == nil)
        #expect(manager.photoURL(for: updated) == nil)
    }

    private func makeManager(profile: CirclePhotoService? = nil, clock: CirclePhotoClock = CirclePhotoClock(), path: String? = "owner/photo.jpg", token: String? = "🌻") -> SocialManager {
        SocialManager(service: makeSocialService(path: path, token: token), profileService: profile, now: { clock.date })
    }

    private func makeSocialService(profile: CirclePhotoService? = nil, path: String? = "owner/photo.jpg", token: String? = "🌻") -> MockSocialService {
        MockSocialService(
            currentUserId: "owner",
            profiles: ["owner": SocialProfileModel(userId: "owner", displayName: "Ada Lovelace", avatarToken: token, avatarPath: path)],
            memberships: [CircleMembershipModel(membershipId: "membership", circleId: "circle", userId: "owner", role: .owner, joinedAt: .distantPast)],
            profileService: profile
        )
    }
}

@MainActor
private final class CirclePhotoClock {
    var date = Date(timeIntervalSince1970: 1_000)
}

@MainActor
private final class CirclePhotoService: ProfileServicing {
    var identity = ProfileIdentity(userId: "owner", displayName: "Ada Lovelace", avatarToken: "🌻", avatarPath: "owner/photo.jpg")
    var shouldFail = false
    var suspendResolution = false
    private var resolutionCount = 0
    private var resolution: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    func fetchProfile(userId: String) async throws -> ProfileIdentity { identity }
    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity { throw PhotoTestError.unsupported }
    func uploadPhoto(userId: String, jpeg: Data) async throws -> String { throw PhotoTestError.unsupported }
    func removePhoto(path: String) async throws { throw PhotoTestError.unsupported }
    func removeAllPhotos(userId: String) async throws { throw PhotoTestError.unsupported }

    func resolvePhotoURL(path: String) async throws -> URL {
        resolutionCount += 1
        if suspendResolution {
            await withCheckedContinuation { continuation in
                resolution = continuation
                waiter?.resume()
                waiter = nil
            }
        }
        if shouldFail { throw PhotoTestError.denied }
        return URL(string: "https://example.test/photo/\(resolutionCount)")!
    }

    func waitUntilResolving() async {
        if resolution != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finishResolution() {
        resolution?.resume()
        resolution = nil
    }
}

private enum PhotoTestError: Error { case denied, unsupported }
