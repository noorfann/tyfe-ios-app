import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SocialMigrationTests {

    @Test func migrationRequiresAuthentication() async {
        let interactor = makeInteractor(isSignedIn: false)

        do {
            try await interactor.migrateLocalToSocial()
            Issue.record("Expected notAuthenticated")
        } catch let error as SocialServiceError {
            #expect(error == .notAuthenticated)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!interactor.isSocialMigrationComplete)
    }

    @Test func migrationPreservesLocalDataAndCompletes() async throws {
        let interactor = makeInteractor(isSignedIn: true)
        let activityId = ActivityModel.mock.activityId

        _ = interactor.acceptPhase1DailyPlan(
            intendedSessionCount: 3,
            activityIds: [activityId],
            timeBlocks: nil
        )
        let activitiesBefore = interactor.todayManager.activities.count
        let plansBefore = interactor.phase1DailyPlan?.intendedSessionCount
        let creditsBefore = interactor.phase1RewardCredits

        try await interactor.migrateLocalToSocial()

        #expect(interactor.isSocialMigrationComplete)
        #expect(interactor.todayManager.activities.count == activitiesBefore)
        #expect(interactor.phase1DailyPlan?.intendedSessionCount == plansBefore)
        #expect(interactor.phase1RewardCredits == creditsBefore)
    }

    private func makeInteractor(isSignedIn: Bool) -> CoreInteractor {
        let dependencies = Dependencies(config: .mock(isSignedIn: isSignedIn, addLogging: false))
        return CoreInteractor(container: dependencies.container)
    }
}
