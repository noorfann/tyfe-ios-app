//
//  AppState.swift
//  tyfe-ios-app
//
//  
//
import SwiftUI
import SwiftfulRouting

@MainActor
@Observable
class AppState {
    
    let startingModuleId: String
    var isFocusScreenVisible = false
    
    var colorScheme: ColorScheme {
        didSet {
            UserDefaults.standard.set(colorScheme == .dark, forKey: Self.appearanceKey)
        }
    }

    private static let appearanceKey = "tyfe.appearance.isDark"

    init(startingModuleId: String = UserDefaults.lastModuleId) {
        self.startingModuleId = startingModuleId
        // Default to light appearance; system appearance is not used.
        self.colorScheme = UserDefaults.standard.bool(forKey: Self.appearanceKey) ? .dark : .light
    }

    func toggleColorScheme() {
        colorScheme = colorScheme == .dark ? .light : .dark
    }
    
}
