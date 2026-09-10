import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusRepositoryTests {

    @Test func localPersistenceRoundTripsSnapshot() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFocusRepositoryPersistence(fileURL: fileURL)
        let snapshot = FocusManagerSnapshot.homeFlowMock

        try persistence.save(snapshot)

        #expect(try persistence.load() == snapshot)
    }

    @Test func versionOneSnapshotMigratesSingularPlanAndLegacySessionFields() throws {
        let plan = DailyPlanModel.mock
        let session = FocusSessionModel.readyMock
        let currentSnapshot = FocusManagerSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: plan,
            focusSessions: [session],
            progression: .mock,
            progressionAwards: [],
            nextActivityNumber: 2,
            nextSessionNumber: 2
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(currentSnapshot)
            ) as? [String: Any]
        )
        object["schemaVersion"] = 1
        if let plans = object["dailyPlans"] as? [[String: Any]], let firstPlan = plans.first {
            object["dailyPlan"] = firstPlan
        }
        object.removeValue(forKey: "dailyPlans")
        object["completedSessionCount"] = 0
        if var legacyPlan = (object["dailyPlan"] as? [[String: Any]])?.first {
            legacyPlan.removeValue(forKey: "local_day")
            legacyPlan["local_date"] = plan.localDate.timeIntervalSince1970
            object["dailyPlan"] = legacyPlan
        }
        if var sessions = object["focusSessions"] as? [[String: Any]],
           var legacySession = sessions.first {
            legacySession.removeValue(forKey: "local_day")
            legacySession.removeValue(forKey: "daily_plan_id_at_start")
            sessions[0] = legacySession
            object["focusSessions"] = sessions
        }

        let data = try JSONSerialization.data(withJSONObject: object)
        let migrated = try JSONDecoder().decode(FocusManagerSnapshot.self, from: data)

        #expect(migrated.schemaVersion == 2)
        #expect(migrated.dailyPlans.count == 1)
        #expect(migrated.focusSessions.count == 1)
        #expect(migrated.creditLedger.balance == currentSnapshot.creditLedger.balance)
        #expect(migrated.progression == currentSnapshot.progression)
    }
}
