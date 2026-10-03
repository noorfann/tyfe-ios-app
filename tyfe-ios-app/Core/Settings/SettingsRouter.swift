//
//  SettingsRouter.swift
//  
//
//  
//
import SwiftUI

@MainActor
protocol SettingsRouter: GlobalRouter {
    func showSignUpView(delegate: SignUpDelegate)
    func showProfileView(delegate: ProfileDelegate)
    func switchToWelcome()
}

extension CoreRouter: SettingsRouter { }
