//
//  AppViewInteractor.swift
//  
//
//  
//
import SwiftUI

@MainActor
protocol AppViewInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var startingModuleId: String { get }
    var colorScheme: ColorScheme { get }
    var pendingReceivedCheerCount: Int { get }

    func toggleColorScheme()
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func syncSocialRealtime() async
    func consumePendingReceivedCheers() -> [CheerModel]
    func discardPendingReceivedCheers()
    func synchronizeRewardCreditDay()
    func reconcileFocusLiveActivity()
}

extension CoreInteractor: AppViewInteractor { }
