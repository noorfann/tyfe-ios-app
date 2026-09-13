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
    func switchToOnboardingModule()
}

extension CoreRouter: SettingsRouter { }
