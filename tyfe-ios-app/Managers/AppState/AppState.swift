//
//  AppState.swift
//  tyfe-ios-app
//
//  
//
import SwiftUI
import SwiftfulRouting

enum AppEntryPhase: String, Sendable {
    case welcome, onboarding, core
}

@MainActor
@Observable
class AppState {
    
    private(set) var entryPhase: AppEntryPhase
    @ObservationIgnored private let entryDefaults: UserDefaults?
    @ObservationIgnored private let appearanceDefaults: UserDefaults
    @ObservationIgnored private var preparedEntryPhase: AppEntryPhase?
    static let entryPhaseKey = "tyfe.entry.phase"

    var startingModuleId: String {
        entryPhase == .core ? Constants.tabbarModuleId : Constants.onboardingModuleId
    }
    var isFocusScreenVisible = false
    
    var colorScheme: ColorScheme {
        didSet {
            appearanceDefaults.set(colorScheme == .dark, forKey: Self.appearanceKey)
        }
    }

    private static let appearanceKey = "tyfe.appearance.isDark"

    init(
        startingModuleId: String = UserDefaults.lastModuleId,
        auth: UserAuthInfo? = nil,
        hasPendingRegistration: Bool = false,
        userDefaults: UserDefaults? = .standard,
        appearanceDefaults: UserDefaults = .standard
    ) {
        entryDefaults = userDefaults
        self.appearanceDefaults = appearanceDefaults
        if let saved = userDefaults?.string(forKey: Self.entryPhaseKey), let phase = AppEntryPhase(rawValue: saved) {
            entryPhase = phase
        } else if auth?.isAnonymous == false && !hasPendingRegistration {
            entryPhase = .core
        } else if startingModuleId == Constants.tabbarModuleId {
            entryPhase = .core
        } else if startingModuleId == Constants.onboardingModuleId {
            entryPhase = .onboarding
        } else {
            entryPhase = .welcome
        }
        // Default to light appearance; system appearance is not used.
        self.colorScheme = appearanceDefaults.bool(forKey: Self.appearanceKey) ? .dark : .light
        userDefaults?.set(entryPhase.rawValue, forKey: Self.entryPhaseKey)
    }

    func setDarkMode(_ isDark: Bool) {
        colorScheme = isDark ? .dark : .light
    }

    func setEntryPhase(_ phase: AppEntryPhase) {
        preparedEntryPhase = nil
        entryDefaults?.set(phase.rawValue, forKey: Self.entryPhaseKey)
        entryPhase = phase
    }

    func prepareEntryTransition(to phase: AppEntryPhase) {
        guard entryPhase == .welcome, preparedEntryPhase == nil else { return }
        preparedEntryPhase = phase
        // Persist completion now, but leave Account ready visible until the sheet closes.
        entryDefaults?.set(phase.rawValue, forKey: Self.entryPhaseKey)
    }

    func completeEntryTransition() {
        guard let phase = preparedEntryPhase else { return }
        setEntryPhase(phase)
    }
    
}
