import Foundation

@MainActor
struct UnavailableProfileService: ProfileServicing {
    func fetchProfile(userId: String) async throws -> ProfileIdentity { throw ProfileServiceError.unavailable }
    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity {
        throw ProfileServiceError.unavailable
    }
    func uploadPhoto(userId: String, jpeg: Data) async throws -> String { throw ProfileServiceError.unavailable }
    func removePhoto(path: String) async throws { throw ProfileServiceError.unavailable }
    func resolvePhotoURL(path: String) async throws -> URL { throw ProfileServiceError.unavailable }
    func removeAllPhotos(userId: String) async throws { throw ProfileServiceError.unavailable }
}
