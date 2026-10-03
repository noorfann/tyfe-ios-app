import SwiftUI

@MainActor
protocol ProfileInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var currentAuthUserId: String? { get }
    var profileSessionGeneration: Int { get }
    var currentUser: UserModel? { get }
    var profilePhotoURL: URL? { get }
    var pendingEmailRegistration: PendingEmailRegistration? { get }
    var canEditProfile: Bool { get }

    func refreshProfile() async throws
    func saveProfile(name: String, photo: ProfilePhotoChange) async throws
}

extension CoreInteractor: ProfileInteractor { }
