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
    
    init(startingModuleId: String = UserDefaults.lastModuleId) {
        self.startingModuleId = startingModuleId
    }
    
}
