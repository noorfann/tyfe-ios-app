import Foundation

@MainActor
final class MockProfileService: ProfileServicing {
    private var profiles: [String: ProfileIdentity]
    private let initialName: (@MainActor (String) -> String?)?
    private var photos: [String: URL] = [:]
    private let photoDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("tyfe-mock-profile-\(UUID().uuidString)", isDirectory: true)
    private var photoSequence = 0

    init(profiles: [ProfileIdentity] = [], initialName: (@MainActor (String) -> String?)? = nil) {
        self.profiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })
        self.initialName = initialName
    }

    deinit {
        try? FileManager.default.removeItem(at: photoDirectory)
    }

    func fetchProfile(userId: String) async throws -> ProfileIdentity {
        if profiles[userId] == nil, let name = initialName?(userId) {
            profiles[userId] = ProfileIdentity(userId: userId, displayName: name)
        }
        guard let profile = profiles[userId] else { throw ProfileServiceError.profileNotFound }
        return profile
    }

    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity {
        guard ProfileValidation.isValidName(name) else { throw ProfileServiceError.invalidName }
        let existing = try await fetchProfile(userId: userId)
        if let avatarPath, !avatarPath.hasPrefix("\(userId)/") { throw ProfileServiceError.invalidPath }
        let profile = ProfileIdentity(
            userId: userId, displayName: ProfileValidation.trimmedName(name),
            avatarToken: existing.avatarToken, avatarPath: avatarPath
        )
        profiles[userId] = profile
        return profile
    }

    func uploadPhoto(userId: String, jpeg: Data) async throws -> String {
        try ProfileValidation.validateJPEG(jpeg)
        photoSequence += 1
        let suffix = String(format: "%012d", photoSequence)
        let path = "\(userId)/00000000-0000-0000-0000-\(suffix).jpg"
        try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        let fileURL = photoDirectory.appendingPathComponent("\(suffix).jpg")
        try jpeg.write(to: fileURL, options: .atomic)
        photos[path] = fileURL
        return path
    }

    func removePhoto(path: String) async throws {
        if let fileURL = photos[path] { try FileManager.default.removeItem(at: fileURL) }
        photos[path] = nil
    }

    func resolvePhotoURL(path: String) async throws -> URL {
        guard let url = photos[path], FileManager.default.fileExists(atPath: url.path) else {
            throw ProfileServiceError.invalidPath
        }
        return url
    }

    func removeAllPhotos(userId: String) async throws {
        for path in Array(photos.keys) where path.hasPrefix("\(userId)/") {
            try await removePhoto(path: path)
        }
    }
}
