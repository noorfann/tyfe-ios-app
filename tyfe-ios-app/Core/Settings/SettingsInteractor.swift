//
//  SettingsInteractor.swift
//  
//
//  
//

import SwiftUI

@MainActor
protocol SettingsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var currentAuthUserId: String? { get }
    var currentUser: UserModel? { get }
    var profilePhotoURL: URL? { get }
    var pendingEmailRegistration: PendingEmailRegistration? { get }
    var canEditProfile: Bool { get }
    var colorScheme: ColorScheme { get }

    func refreshProfile() async throws
    func setDarkMode(_ enabled: Bool)
    func signOut() async throws
    func deleteAccount() async throws
}

extension CoreInteractor: SettingsInteractor { }
