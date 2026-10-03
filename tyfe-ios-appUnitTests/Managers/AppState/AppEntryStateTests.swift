import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct AppEntryStateTests {
    @Test func freshAndAnonymousLaunchStayOnWelcome() {
        #expect(AppState(startingModuleId: "", userDefaults: nil).entryPhase == .welcome)
        #expect(AppState(startingModuleId: "", auth: .mock(isAnonymous: true), userDefaults: nil).entryPhase == .welcome)
    }

    @Test func legacyModulesAndRestoredAccountsKeepTheirDestination() {
        #expect(AppState(startingModuleId: Constants.tabbarModuleId, userDefaults: nil).entryPhase == .core)
        #expect(AppState(startingModuleId: Constants.onboardingModuleId, userDefaults: nil).entryPhase == .onboarding)
        #expect(AppState(startingModuleId: "", auth: .mock(), userDefaults: nil).entryPhase == .core)
        #expect(AppState(startingModuleId: "", auth: .mock(), hasPendingRegistration: true, userDefaults: nil).entryPhase == .welcome)
    }

    @Test func guestChoiceAndCompletionSurviveRestart() throws {
        let suite = "tyfe.tests.entry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(startingModuleId: "", userDefaults: defaults)
        state.setEntryPhase(.onboarding)
        let resumed = AppState(startingModuleId: "", auth: .mock(isAnonymous: true), userDefaults: defaults)
        #expect(resumed.entryPhase == .onboarding)
        resumed.setEntryPhase(.core)
        #expect(AppState(startingModuleId: "", userDefaults: defaults).entryPhase == .core)
    }

    @Test func authenticationSavesNextRouteWithoutHidingAccountReady() throws {
        let suite = "tyfe.tests.entry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(startingModuleId: "", userDefaults: defaults)
        state.prepareEntryTransition(to: .onboarding)
        state.prepareEntryTransition(to: .core)
        #expect(state.entryPhase == .welcome)
        #expect(AppState(startingModuleId: "", userDefaults: defaults).entryPhase == .onboarding)
        state.completeEntryTransition()
        state.completeEntryTransition()
        #expect(state.entryPhase == .onboarding)
    }

    @Test func explicitResetOverridesLegacyModuleAndLateCompletion() throws {
        let suite = "tyfe.tests.entry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(startingModuleId: "", userDefaults: defaults)
        state.prepareEntryTransition(to: .core)
        state.setEntryPhase(.welcome)
        state.completeEntryTransition()
        #expect(state.entryPhase == .welcome)
        let resumed = AppState(startingModuleId: Constants.tabbarModuleId, auth: .mock(), userDefaults: defaults)
        #expect(resumed.entryPhase == .welcome)
    }
}
