import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayHabitViewPreferenceTests {
    @Test func missingAndInvalidPreferenceDefaultToWeek() throws {
        let suiteName = "TodayHabitViewPreferenceTests.defaults.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(TodayManager(userDefaults: defaults).habitViewPeriod == .week)
        defaults.set("unknown", forKey: "tyfe.today-habit-view-period")
        #expect(TodayManager(userDefaults: defaults).habitViewPeriod == .week)
    }

    @Test(arguments: HabitViewPeriod.allCases)
    func preferenceRestoresAfterManagerRecreation(_ period: HabitViewPeriod) throws {
        let suiteName = "TodayHabitViewPreferenceTests.restoration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let manager = TodayManager(userDefaults: defaults)
        let snapshot = manager.repository.snapshot
        manager.setHabitViewPeriod(period)
        #expect(TodayManager(userDefaults: defaults).habitViewPeriod == period)
        #expect(manager.repository.snapshot == snapshot)
    }

    @Test func mockPreferenceStaysInMemoryWithoutLeakingToAnotherManager() {
        let manager = TodayManager()
        #expect(manager.habitViewPeriod == .week)
        manager.setHabitViewPeriod(.year)
        #expect(manager.habitViewPeriod == .year)
        #expect(TodayManager().habitViewPeriod == .week)
    }
}
