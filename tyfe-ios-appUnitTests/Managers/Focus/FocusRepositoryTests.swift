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

    @Test func projectMembershipRoundTripsSnapshot() throws {
        var snapshot = LocalAppSnapshot.mock
        let project = ProjectModel(
            projectId: "project-custom-color",
            name: "Reading",
            iconToken: "leaf.fill",
            colorToken: "#12ABCD"
        )
        snapshot.projects = [project]
        snapshot.activities[0].projectId = project.projectId

        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(LocalAppSnapshot.self, from: data)

        #expect(restored.projects == [project])
        #expect(restored.activities.first?.projectId == project.projectId)
    }

    @Test func legacyProjectWithoutAppearanceDecodesWithDisplayDefaults() throws {
        let data = Data(#"{"projectId":"project-legacy","name":"Writing"}"#.utf8)
        let project = try JSONDecoder().decode(ProjectModel.self, from: data)

        #expect(project.iconToken == nil)
        #expect(project.colorToken == nil)
        #expect(project.resolvedIconToken == ProjectModel.defaultIconToken)
        #expect(project.resolvedColorToken == ProjectModel.defaultColorToken)
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

        #expect(migrated.schemaVersion == 5)
        #expect(migrated.dailyPlans.count == 1)
        #expect(migrated.focusSessions.count == 1)
        #expect(migrated.creditLedger.balance == currentSnapshot.creditLedger.balance)
    }

    @Test func legacyRewardTiersDecodeToTheirTenMinuteBlocks() throws {
        let legacyTiers = try ["fifteenMinutes", "thirtyMinutes", "sixtyMinutes"].map {
            try JSONDecoder().decode(RewardDurationTier.self, from: Data("\"\($0)\"".utf8))
        }
        #expect(legacyTiers == [.tenMinutes, .thirtyMinutes, .sixtyMinutes])
        #expect(legacyTiers.map(\.creditCost) == [1, 3, 6])

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

        #expect(migrated.schemaVersion == 5)
        #expect(migrated.customRewards.first?.durationTier == .thirtyMinutes)
        #expect(migrated.rewardClaims.first?.durationTier == .sixtyMinutes)
    }

    @Test func olderSnapshotMigratesExistingActivitiesToUnassigned() throws {
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(LocalAppSnapshot.mock)
            ) as? [String: Any]
        )
        object["schemaVersion"] = 4
        object.removeValue(forKey: "projects")
        object.removeValue(forKey: "nextProjectNumber")
        var activities = try #require(object["activities"] as? [[String: Any]])
        activities[0].removeValue(forKey: "projectId")
        object["activities"] = activities

        let data = try JSONSerialization.data(withJSONObject: object)
        let migrated = try JSONDecoder().decode(LocalAppSnapshot.self, from: data)

        #expect(migrated.schemaVersion == 5)
        #expect(migrated.projects.isEmpty)
        #expect(migrated.nextProjectNumber == 1)
        #expect(migrated.activities.first?.projectId == nil)
    }
}
