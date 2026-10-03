import Foundation
import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct AppearancePersistenceTests {
    @Test func darkModeSurvivesRestartAndCanBeDisabled() throws {
        let suite = "tyfe.tests.appearance.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(startingModuleId: "", userDefaults: nil, appearanceDefaults: defaults)
        state.setDarkMode(true)
        let resumed = AppState(startingModuleId: "", userDefaults: nil, appearanceDefaults: defaults)
        #expect(resumed.colorScheme == .dark)
        resumed.setDarkMode(false)
        #expect(AppState(startingModuleId: "", userDefaults: nil, appearanceDefaults: defaults).colorScheme == .light)
    }

    @Test func existingSavedAppearanceIsPreservedWithoutChangingEntryChoice() throws {
        let suite = "tyfe.tests.appearance.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "tyfe.appearance.isDark")
        let state = AppState(startingModuleId: "", userDefaults: defaults, appearanceDefaults: defaults)
        #expect(state.colorScheme == .dark)
        state.setDarkMode(false)
        #expect(state.entryPhase == .welcome)
        #expect(defaults.string(forKey: AppState.entryPhaseKey) == AppEntryPhase.welcome.rawValue)
    }
}
