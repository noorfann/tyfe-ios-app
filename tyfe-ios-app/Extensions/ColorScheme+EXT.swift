//
//  ColorScheme+EXT.swift
//  tyfe-ios-app
//
//  
//
import SwiftUI

extension ColorScheme {
    
    var backgroundPrimary: Color {
        self == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }
    
    var backgroundSecondary: Color {
        self == .dark ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground)
    }
    
}
