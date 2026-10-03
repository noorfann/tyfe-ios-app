#if !MOCK && canImport(Supabase)
import Foundation
import Supabase

@MainActor
final class SupabaseProfileService: ProfileServicing {
    private let client: SupabaseClient
    private static let bucket = "profile-photos"

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchProfile(userId: String) async throws -> ProfileIdentity {
        try await client.from("profiles")
            .select("id, display_name, avatar_token, avatar_path")
            .eq("id", value: userId).single().execute().value
    }

    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity {
        guard ProfileValidation.isValidName(name) else { throw ProfileServiceError.invalidName }
        try requireOwner(userId)
        if let avatarPath {
            try validatePath(avatarPath)
            guard avatarPath.hasPrefix("\(userId.lowercased())/") else { throw ProfileServiceError.invalidPath }
        }
        // Explicit null clears the reference; avatar_token is deliberately not in this partial update.
        return try await client.from("profiles")
            .update(ProfileUpdate(displayName: ProfileValidation.trimmedName(name), avatarPath: avatarPath))
            .eq("id", value: userId)
            .select("id, display_name, avatar_token, avatar_path")
            .single().execute().value
    }

    func uploadPhoto(userId: String, jpeg: Data) async throws -> String {
        try requireOwner(userId)
        try ProfileValidation.validateJPEG(jpeg)
        guard let owner = UUID(uuidString: userId) else { throw ProfileServiceError.invalidPath }
        let path = "\(owner.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await client.storage.from(Self.bucket).upload(
            path, data: jpeg,
            options: FileOptions(cacheControl: "300", contentType: "image/jpeg", upsert: false)
        )
        return path
    }

    func removePhoto(path: String) async throws {
        try validatePath(path)
        let components = path.split(separator: "/")
        let owner = String(components[0])
        try requireOwner(owner)
        let storage = client.storage.from(Self.bucket)
        let removed = try await storage.remove(paths: [path])
        try requireOwner(owner)
        if removed.isEmpty {
            // Already-absent objects are idempotent; RLS-denied deletes remain retryable.
            let remaining = try await storage.list(
                path: owner, options: SearchOptions(limit: 100, offset: 0, search: String(components[1]))
            )
            try requireOwner(owner)
            guard !remaining.contains(where: { $0.name == String(components[1]) }) else {
                throw ProfileServiceError.accountChanged
            }
        }
    }

    func resolvePhotoURL(path: String) async throws -> URL {
        try validatePath(path)
        return try await client.storage.from(Self.bucket).createSignedURL(path: path, expiresIn: 300)
    }

    func removeAllPhotos(userId: String) async throws {
        try requireOwner(userId)
        guard let owner = UUID(uuidString: userId) else { throw ProfileServiceError.invalidPath }
        let prefix = owner.uuidString.lowercased()
        let storage = client.storage.from(Self.bucket)
        // Always drain the first page: advancing offsets while deleting skips surviving objects.
        while true {
            try requireOwner(userId)
            let files = try await storage.list(path: prefix, options: SearchOptions(limit: 100, offset: 0))
            try requireOwner(userId)
            guard !files.isEmpty else { return }
            let paths = try files.map { file in
                let path = "\(prefix)/\(file.name)"
                try validatePath(path)
                return path
            }
            try requireOwner(userId)
            let removed = try await storage.remove(paths: paths)
            try requireOwner(userId)
            // Storage can return success with no deletions under RLS. Never spin or claim cleanup.
            guard removed.count == paths.count else { throw ProfileServiceError.accountChanged }
        }
    }

    private func requireOwner(_ userId: String) throws {
        guard client.auth.currentUser?.id.uuidString.lowercased() == userId.lowercased() else {
            throw ProfileServiceError.accountChanged
        }
    }

    private func validatePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, UUID(uuidString: String(components[0])) != nil,
              components[1].hasSuffix(".jpg"), UUID(uuidString: String(components[1].dropLast(4))) != nil else {
            throw ProfileServiceError.invalidPath
        }
    }

    private struct ProfileUpdate: Encodable {
        let displayName: String
        let avatarPath: String?

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: ProfileUpdateKeys.self)
            try container.encode(displayName, forKey: .displayName)
            if let avatarPath {
                try container.encode(avatarPath, forKey: .avatarPath)
            } else {
                try container.encodeNil(forKey: .avatarPath)
            }
        }
    }

    private enum ProfileUpdateKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }
}
#endif
