import Foundation

struct ProfileIdentity: Codable, Equatable, Sendable {
    let userId: String
    let displayName: String
    let avatarToken: String?
    let avatarPath: String?

    init(userId: String, displayName: String, avatarToken: String? = nil, avatarPath: String? = nil) {
        self.userId = userId
        self.displayName = displayName
        self.avatarToken = avatarToken
        self.avatarPath = avatarPath
    }

    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case displayName = "display_name"
        case avatarToken = "avatar_token"
        case avatarPath = "avatar_path"
    }
}

enum ProfilePhotoChange: Equatable, Sendable {
    case unchanged
    case replace(Data)
    case remove
}

enum ProfileValidation {
    static let maximumPhotoBytes = 1_048_576

    static func trimmedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func isValidName(_ name: String) -> Bool {
        (1...60).contains(trimmedName(name).unicodeScalars.count)
    }

    static func validateJPEG(_ data: Data) throws {
        guard data.count >= 4, data.count <= maximumPhotoBytes,
              data.starts(with: [0xFF, 0xD8]), data.suffix(2).elementsEqual([0xFF, 0xD9]) else {
            throw ProfileServiceError.invalidPhoto
        }
    }
}

@MainActor
protocol ProfileServicing {
    func fetchProfile(userId: String) async throws -> ProfileIdentity
    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity
    func uploadPhoto(userId: String, jpeg: Data) async throws -> String
    func removePhoto(path: String) async throws
    func resolvePhotoURL(path: String) async throws -> URL
    func removeAllPhotos(userId: String) async throws
}

enum ProfileServiceError: LocalizedError, Equatable {
    case unavailable
    case invalidName
    case invalidPhoto
    case invalidPath
    case profileNotFound
    case accountChanged

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Profile editing is unavailable. Please try again later."
        case .invalidName: return "Enter a name between 1 and 60 characters."
        case .invalidPhoto: return "Choose a JPEG photo no larger than 1 MB."
        case .invalidPath: return "This profile photo cannot be accessed."
        case .profileNotFound: return "Your profile could not be loaded. Please try again."
        case .accountChanged: return "Your account changed. Reopen your profile to continue."
        }
    }
}
