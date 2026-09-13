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

    func toggleColorScheme()
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func syncSocialRealtime() async
}

extension CoreInteractor: AppViewInteractor { }
