#if !MOCK && canImport(Supabase)
import Foundation
import Supabase

@MainActor
final class SupabaseSocialService: SocialService {
    private let client: SupabaseClient
    private var presenceChannels: [String: RealtimeChannelV2] = [:]

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
            .update(ProfileUpdate(displayName: trimmed), returning: .minimal)
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
            .update(InviteRevoke(revokedAt: .now), returning: .minimal)
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
            .delete(returning: .minimal)
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    func removeMember(circleId: String, userId: String) async throws {
        try await client
            .from("circle_memberships")
            .delete(returning: .minimal)
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    func publishProgress(
        userId: String,
        localDay: LocalDay,
        plannedSessions: Int,
        completedSessions: Int
    ) async throws {
        try await client
            .from("shared_progress")
            .upsert(
                SharedProgressUpsert(
                    userId: userId,
                    localDate: localDay.socialDateString,
                    plannedSessions: max(plannedSessions, 0),
                    completedSessions: max(completedSessions, 0)
                ),
                onConflict: "user_id,local_date",
                returning: .minimal
            )
            .execute()
    }

    func fetchCircleProgress(circleId: String) async throws -> [CircleMemberProgressModel] {
        try await client
            .from("circle_member_progress")
            .select()
            .eq("circle_id", value: circleId)
            .execute()
            .value
    }

    func sendCheer(
        _ kind: CheerKind,
        senderId: String,
        recipientId: String,
        localDate: LocalDay
    ) async throws {
        try await client
            .from("cheers")
            .insert(CheerInsert(
                kind: kind.rawValue,
                senderId: senderId,
                recipientId: recipientId,
                localDate: localDate.socialDateString
            ))
            .execute()
    }

    func fetchCheers(localDate: LocalDay) async throws -> [CheerModel] {
        try await client
            .from("cheers")
            .select()
            .eq("local_date", value: localDate.socialDateString)
            .execute()
            .value
    }

    func cheerStream() -> AsyncStream<CheerModel> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("cheers-delivery")
            let changes = channel.postgresChange(InsertAction.self, schema: "public", table: "cheers")
            let changesTask = Task {
                for await action in changes {
                    if let cheer = try? action.decodeRecord(
                        as: CheerModel.self,
                        decoder: JSONDecoder.socialRealtime
                    ) {
                        continuation.yield(cheer)
                    }
                }
            }
            let subscribeTask = Task { try? await channel.subscribeWithError() }
            continuation.onTermination = { _ in
                changesTask.cancel()
                subscribeTask.cancel()
                Task { await self.client.realtimeV2.removeChannel(channel) }
            }
        }
    }

    func updateFocusStatus(_ status: CircleFocusStatus, userId: String, circleId: String) async {
        guard let channel = presenceChannels[circleId] else { return }
        try? await channel.track(CirclePresencePayload(userId: userId, status: status))
    }

    func focusStatusStream(circleId: String) -> AsyncStream<[CircleFocusStatusEntry]> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("circle-\(circleId)-presence")
            presenceChannels[circleId] = channel
            var statuses: [String: CircleFocusStatus] = [:]
            let changes = channel.presenceChange()
            let changesTask = Task {
                for await action in changes {
                    for payload in (try? action.decodeJoins(as: CirclePresencePayload.self)) ?? [] {
                        statuses[payload.userId] = payload.status
                    }
                    for payload in (try? action.decodeLeaves(as: CirclePresencePayload.self)) ?? [] {
                        statuses[payload.userId] = nil
                    }
                    continuation.yield(Self.sortedStatuses(statuses))
                }
            }
            let subscribeTask = Task { try? await channel.subscribeWithError() }
            continuation.onTermination = { _ in
                changesTask.cancel()
                subscribeTask.cancel()
                Task { await self.client.realtimeV2.removeChannel(channel) }
            }
        }
    }

    func stopFocusStatus(circleId: String) async {
        guard let channel = presenceChannels.removeValue(forKey: circleId) else { return }
        await channel.untrack()
        await client.realtimeV2.removeChannel(channel)
    }

    func blockUser(_ blockedId: String, blockerId: String) async throws {
        try await client
            .from("user_blocks")
            .insert(UserBlockInsert(blockerId: blockerId, blockedId: blockedId))
            .execute()
    }

    func unblockUser(_ blockedId: String, blockerId: String) async throws {
        try await client
            .from("user_blocks")
            .delete(returning: .minimal)
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: blockedId)
            .execute()
    }

    func fetchBlockedUserIds(userId: String) async throws -> [String] {
        let rows: [BlockedIdRow] = try await client
            .from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: userId)
            .execute()
            .value
        return rows.map(\.blockedId)
    }

    func setCircleSharingPaused(_ paused: Bool, circleId: String, userId: String) async throws {
        try await client
            .from("circle_memberships")
            .update(MembershipSharingUpdate(sharingPaused: paused), returning: .minimal)
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    func setGlobalSharingPaused(_ paused: Bool, userId: String) async throws {
        try await client
            .from("profiles")
            .update(ProfileSharingUpdate(sharingPaused: paused), returning: .minimal)
            .eq("id", value: userId)
            .execute()
    }

    private static func sortedStatuses(_ statuses: [String: CircleFocusStatus]) -> [CircleFocusStatusEntry] {
        statuses
            .map { CircleFocusStatusEntry(userId: $0.key, status: $0.value) }
            .sorted { $0.userId < $1.userId }
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

private struct SharedProgressUpsert: Encodable {
    let userId: String
    let localDate: String
    let plannedSessions: Int
    let completedSessions: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localDate = "local_date"
        case plannedSessions = "planned_sessions"
        case completedSessions = "completed_sessions"
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

private struct CheerInsert: Encodable {
    let kind: String
    let senderId: String
    let recipientId: String
    let localDate: String

    enum CodingKeys: String, CodingKey {
        case kind
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case localDate = "local_date"
    }
}

private struct UserBlockInsert: Encodable {
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

private struct BlockedIdRow: Decodable {
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
    }
}

private struct MembershipSharingUpdate: Encodable {
    let sharingPaused: Bool

    enum CodingKeys: String, CodingKey {
        case sharingPaused = "sharing_paused"
    }
}

private struct ProfileSharingUpdate: Encodable {
    let sharingPaused: Bool

    enum CodingKeys: String, CodingKey {
        case sharingPaused = "sharing_paused"
    }
}

private extension JSONDecoder {
    static var socialRealtime: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: string) {
                return date
            }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }
}
#endif
