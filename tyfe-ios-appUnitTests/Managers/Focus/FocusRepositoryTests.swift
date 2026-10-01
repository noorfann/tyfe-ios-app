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

    @Test func recurrenceAndMaterializationMarkerRoundTrip() throws {
        var snapshot = LocalAppSnapshot.mock
        snapshot.activities[0].recurrence = ActivityRecurrenceModel(
            kind: .weekly,
            weekdays: [2, 4],
            defaultSessionCount: 3
        )
        snapshot.lastMaterializedLocalDay = LocalDay(
            year: 2026,
            month: 3,
            day: 2,
            timeZoneIdentifier: "GMT"
        )

        let restored = try JSONDecoder().decode(
            LocalAppSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        #expect(restored.schemaVersion == 7)
        #expect(restored.activities[0].recurrence == snapshot.activities[0].recurrence)
        #expect(restored.lastMaterializedLocalDay == snapshot.lastMaterializedLocalDay)
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
            sessions[0] = legacySession
            object["focusSessions"] = sessions
        }

        let data = try JSONSerialization.data(withJSONObject: object)
        let migrated = try JSONDecoder().decode(LocalAppSnapshot.self, from: data)

        #expect(migrated.schemaVersion == 7)
        #expect(migrated.dailyPlans.count == 1)
        #expect(migrated.focusSessions.count == 1)
        #expect(migrated.creditLedger.balance == currentSnapshot.creditLedger.balance)
    }

    @Test(arguments: [true, false])
    func legacySessionMetadataIsIgnoredWithoutChangingHistoryOrCredits(_ legacyFlag: Bool) throws {
        // Given
        let session = FocusSessionModel.completedMock
        let snapshot = LocalAppSnapshot(
            activities: [ActivityModel.mock],
            dailyPlan: DailyPlanModel.mock,
            focusSessions: [session],
            creditLedger: .openingBalance(amount: 3, recordedAt: session.startedAt),
            nextActivityNumber: 2,
            nextSessionNumber: 2
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        var sessions = try #require(object["focusSessions"] as? [[String: Any]])
        sessions[0]["isBonusSession"] = legacyFlag
        sessions[0]["daily_plan_id_at_start"] = DailyPlanModel.mock.dailyPlanId
        object["focusSessions"] = sessions
        let legacySessionData = try JSONSerialization.data(withJSONObject: sessions[0])

        // When
        let restored = try JSONDecoder().decode(
            LocalAppSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let encoded = try JSONEncoder().encode(restored)
        let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let encodedSessions = try #require(encodedObject["focusSessions"] as? [[String: Any]])
        let roundTripped = try JSONDecoder().decode(LocalAppSnapshot.self, from: encoded)
        let clock = TestFocusClock(now: session.startedAt)
        let repository = MockLocalAppRepository(snapshot: restored)
        let today = TodayManager(repository: repository, clock: clock)
        let focus = FocusManager(repository: repository, clock: clock)

        // Then
        #expect(try JSONDecoder().decode(FocusSessionModel.self, from: legacySessionData) == session)
        #expect(restored == snapshot)
        #expect(roundTripped == snapshot)
        #expect(restored.creditLedger == snapshot.creditLedger)
        #expect(encodedSessions[0]["isBonusSession"] == nil)
        #expect(encodedSessions[0]["daily_plan_id_at_start"] == nil)
        #expect(today.completedSessionCount(for: session.activityId, on: session.localDay) == 1)
        #expect(focus.completedSessionCount(for: session.activityId, on: session.localDay) == 1)
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

        #expect(migrated.schemaVersion == 7)
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

        #expect(migrated.schemaVersion == 7)
        #expect(migrated.projects.isEmpty)
        #expect(migrated.nextProjectNumber == 1)
        #expect(migrated.activities.first?.projectId == nil)
    }
}
