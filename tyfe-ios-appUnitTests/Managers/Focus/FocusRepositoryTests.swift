import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusRepositoryTests {

    @Test func localPersistenceRoundTripsSnapshot() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFileRepositoryPersistence(fileURL: fileURL)
        let snapshot = LocalAppSnapshot.homeFlowMock

        try persistence.save(snapshot)

        #expect(try persistence.load() == snapshot)
    }

    @Test func versionOneSnapshotMigratesSingularPlanAndLegacySessionFields() throws {
        let plan = DailyPlanModel.mock
        let session = FocusSessionModel.readyMock
        let currentSnapshot = LocalAppSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: plan,
            focusSessions: [session],
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
        let migrated = try JSONDecoder().decode(LocalAppSnapshot.self, from: data)

        #expect(migrated.schemaVersion == 4)
        #expect(migrated.dailyPlans.count == 1)
        #expect(migrated.focusSessions.count == 1)
        #expect(migrated.creditLedger.balance == currentSnapshot.creditLedger.balance)
    }

    @Test func legacyRewardTiersMigrateToTheSingleTenMinuteTier() throws {
        let legacyTiers = try ["fifteenMinutes", "thirtyMinutes", "sixtyMinutes"].map {
            try JSONDecoder().decode(RewardDurationTier.self, from: Data("\"\($0)\"".utf8))
        }
        #expect(legacyTiers == [.tenMinutes, .tenMinutes, .tenMinutes])

        let customReward = RewardModel(
            rewardId: "legacy-custom-reward",
            name: "Read for a while",
            kind: .custom,
            durationTier: .tenMinutes,
            availability: .available
        )
        let claim = RewardClaimModel(
            rewardClaimId: "legacy-claim",
            rewardId: customReward.rewardId,
            durationTier: .tenMinutes,
            state: .ready
        )
        let snapshot = LocalAppSnapshot(
            activities: [ActivityModel.mock],
            customRewards: [customReward],
            rewardClaims: [claim],
            focusSessions: [],
            nextActivityNumber: 2,
            nextSessionNumber: 1
        )
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(snapshot)
            ) as? [String: Any]
        )
        object["schemaVersion"] = 3
        var rewards = try #require(object["customRewards"] as? [[String: Any]])
        rewards[0]["durationTier"] = "thirtyMinutes"
        object["customRewards"] = rewards
        var claims = try #require(object["rewardClaims"] as? [[String: Any]])
        claims[0]["durationTier"] = "sixtyMinutes"
        object["rewardClaims"] = claims

        let migratedData = try JSONSerialization.data(withJSONObject: object)
        let migrated = try JSONDecoder().decode(LocalAppSnapshot.self, from: migratedData)

        #expect(migrated.schemaVersion == 4)
        #expect(migrated.customRewards.first?.durationTier == .tenMinutes)
        #expect(migrated.rewardClaims.first?.durationTier == .tenMinutes)
    }
}
