//
//  SettingsInteractor.swift
//  
//
//  
//

@MainActor
protocol SettingsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var currentAuthUserId: String? { get }
    var isPremium: Bool { get }
    var socialCheers: [CheerModel] { get }
    var isGlobalSharingPaused: Bool { get }

    func refreshSocialCheers() async throws
    func refreshSocialProfile() async throws
    func setGlobalSharingPaused(_ paused: Bool, userId: String) async throws
    func signOut() async throws
    func deleteAccount() async throws
}

extension CoreInteractor: SettingsInteractor { }
