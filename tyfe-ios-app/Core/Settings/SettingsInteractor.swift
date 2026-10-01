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
    var socialCheers: [CheerModel] { get }

    func refreshSocialCheers() async throws
    func signOut() async throws
    func deleteAccount() async throws
}

extension CoreInteractor: SettingsInteractor { }
