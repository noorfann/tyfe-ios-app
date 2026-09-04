//
//  Builder.swift
//  tyfe-ios-app
//
//  
//
import SwiftUI

@MainActor
protocol Builder {
    func build() -> AnyView
}
