#if !MOCK && canImport(Supabase)
import Foundation
import Supabase

@MainActor
final class SupabaseSocialService: SocialService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchProfile(userId: String) async throws -> SocialProfileModel? {
        let profiles: [SocialProfileModel] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        return profiles.first
    }

    func updateDisplayName(_ name: String, userId: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialServiceError.invalidName }
        try await client
            .from("profiles")
            .update(ProfileUpdate(displayName: trimmed))
            .eq("id", value: userId)
            .execute()
    }

    func createCircle(name: String, ownerId: String) async throws -> CircleModel {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialServiceError.invalidName }

        let circle: CircleModel = try await client
            .from("circles")
            .insert(CircleInsert(name: trimmed, ownerId: ownerId))
            .select()
            .single()
            .execute()
            .value

        try await client
            .from("circle_memberships")
            .insert(MembershipInsert(
                circleId: circle.circleId,
                userId: ownerId,
                role: CircleMemberRole.owner.rawValue
            ))
            .execute()

        return circle
    }

    func fetchCircles(userId: String) async throws -> [CircleModel] {
        try await client.from("circles").select().execute().value
    }

    func fetchMembers(circleId: String) async throws -> [CircleMemberModel] {
        let rows: [MembershipMemberRow] = try await client
            .from("circle_memberships")
            .select("user_id, role, sharing_paused, joined_at, profiles(display_name, avatar_token)")
            .eq("circle_id", value: circleId)
            .execute()
            .value

        return rows.map { row in
            CircleMemberModel(
                userId: row.userId,
                displayName: row.profiles?.displayName ?? "Friend",
                avatarToken: row.profiles?.avatarToken,
                role: row.role,
                sharingPaused: row.sharingPaused,
                joinedAt: row.joinedAt
            )
        }
    }

    func createInvite(circleId: String, createdBy: String, expiresAt: Date) async throws -> CircleInviteModel {
        for attempt in 0..<3 {
            do {
                let invite: CircleInviteModel = try await client
                    .from("circle_invites")
                    .insert(InviteInsert(
                        circleId: circleId,
                        createdBy: createdBy,
                        code: Self.makeCode(),
                        expiresAt: expiresAt
                    ))
                    .select()
                    .single()
                    .execute()
                    .value
                return invite
            } catch {
                if attempt == 2 { throw error }
            }
        }
        throw SocialServiceError.persistenceFailed("Could not create an invite code.")
    }

    func revokeInvite(inviteId: String) async throws {
        try await client
            .from("circle_invites")
            .update(InviteRevoke(revokedAt: .now))
            .eq("id", value: inviteId)
            .execute()
    }

    func acceptInvite(code: String) async throws -> String {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let circleId: String = try await client
            .rpc("accept_circle_invite", params: ["p_code": normalized])
            .execute()
            .value
        return circleId
    }

    func leaveCircle(circleId: String, userId: String) async throws {
        try await client
            .from("circle_memberships")
            .delete()
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    func removeMember(circleId: String, userId: String) async throws {
        try await client
            .from("circle_memberships")
            .delete()
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    private static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement() ?? "A" })
    }
}

private struct CircleInsert: Encodable {
    let name: String
    let ownerId: String

    enum CodingKeys: String, CodingKey {
        case name
        case ownerId = "owner_id"
    }
}

private struct MembershipInsert: Encodable {
    let circleId: String
    let userId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case userId = "user_id"
        case role
    }
}

private struct ProfileUpdate: Encodable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private struct InviteInsert: Encodable {
    let circleId: String
    let createdBy: String
    let code: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case createdBy = "created_by"
        case code
        case expiresAt = "expires_at"
    }
}

private struct InviteRevoke: Encodable {
    let revokedAt: Date

    enum CodingKeys: String, CodingKey {
        case revokedAt = "revoked_at"
    }
}

private struct MembershipMemberRow: Decodable {
    let userId: String
    let role: CircleMemberRole
    let sharingPaused: Bool
    let joinedAt: Date
    let profiles: MembershipMemberProfile?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case sharingPaused = "sharing_paused"
        case joinedAt = "joined_at"
        case profiles
    }
}

private struct MembershipMemberProfile: Decodable {
    let displayName: String
    let avatarToken: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarToken = "avatar_token"
    }
}
#endif
