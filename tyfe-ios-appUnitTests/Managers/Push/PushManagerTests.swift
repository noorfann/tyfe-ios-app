import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct PushManagerTests {

    @Test func authorizedManagerSchedulesPlanReminder() async {
        let clock = TestFocusClock()
        let service = MockLocalNotificationService(status: .authorized)
        let manager = PushManager(service: service, clock: clock, preferences: enabledPreferences())
        let plan = DailyPlanModel(
            dailyPlanId: "daily-plan-test",
            localDate: clock.now,
            intendedSessionCount: 1,
            originalIntendedSessionCount: 1,
            activityIds: [ActivityModel.mock.activityId],
            timeBlocks: [
                PlanTimeBlockModel(
                    timeBlockId: "time-block-test",
                    activityId: ActivityModel.mock.activityId,
                    plannedStart: clock.now.addingTimeInterval(600)
                )
            ]
        )

        manager.schedulePlanReminders(for: plan)
        await waitForRequestCount(1, service: service)

        #expect(service.scheduledRequests.first?.identifier == "tyfe.plan.daily-plan-test.time-block-test")
        assertCopyIsWarm(service.scheduledRequests)
    }

    @Test func authorizedManagerSchedulesFocusCompletion() async {
        let clock = TestFocusClock()
        let service = MockLocalNotificationService(status: .authorized)
        let manager = PushManager(service: service, clock: clock, preferences: enabledPreferences())
        let focusSession = FocusSessionModel(
            focusSessionId: "focus-session-test",
            activityId: ActivityModel.mock.activityId,
            state: .running,
            startedAt: clock.now,
            focusEndsAt: clock.now.addingTimeInterval(1_500)
        )

        manager.scheduleFocusCompletion(for: focusSession)
        await waitForRequestCount(1, service: service)

        #expect(service.scheduledRequests.first?.identifier == "tyfe.focus.focus-session-test.completion")
        assertCopyIsWarm(service.scheduledRequests)
    }

    @Test func authorizedManagerSchedulesRewardExpiry() async {
        let clock = TestFocusClock()
        let service = MockLocalNotificationService(status: .authorized)
        let manager = PushManager(service: service, clock: clock, preferences: enabledPreferences())
        let rewardClaim = RewardClaimModel(
            rewardClaimId: "reward-claim-test",
            rewardId: RewardModel.mock.rewardId,
            durationTier: .fifteenMinutes,
            state: .active,
            startsAt: clock.now,
            endsAt: clock.now.addingTimeInterval(900)
        )

        manager.scheduleRewardExpiry(for: rewardClaim)
        await waitForRequestCount(1, service: service)

        #expect(service.scheduledRequests.first?.identifier == "tyfe.reward.reward-claim-test.expiry")
        assertCopyIsWarm(service.scheduledRequests)
    }

    @Test func deniedAuthorizationLeavesNoPendingTimerNotifications() async {
        let clock = TestFocusClock()
        let service = MockLocalNotificationService(status: .denied)
        let manager = PushManager(service: service, clock: clock)
        let session = FocusSessionModel(
            focusSessionId: "focus-session-denied",
            activityId: ActivityModel.mock.activityId,
            state: .running,
            startedAt: clock.now,
            focusEndsAt: clock.now.addingTimeInterval(1_500)
        )

        manager.scheduleFocusCompletion(for: session)
        await allowPendingOperationsToFinish()

        #expect(service.scheduledRequests.isEmpty)
    }

    @Test func grantingAuthorizationSchedulesPreviouslyRequestedCompletion() async throws {
        let clock = TestFocusClock()
        let service = MockLocalNotificationService(status: .notDetermined)
        let manager = PushManager(service: service, clock: clock)
        let session = FocusSessionModel(
            focusSessionId: "focus-session-after-consent",
            activityId: ActivityModel.mock.activityId,
            state: .running,
            startedAt: clock.now,
            focusEndsAt: clock.now.addingTimeInterval(1_500)
        )

        manager.scheduleFocusCompletion(for: session)
        await allowPendingOperationsToFinish()
        #expect(service.scheduledRequests.isEmpty)

        _ = try await manager.requestAuthorization()
        await waitForRequestCount(1, service: service)

        #expect(service.scheduledRequests.first?.identifier == "tyfe.focus.focus-session-after-consent.completion")
    }

    @Test func quietHoursDelayFocusCompletionUntilConfiguredEnd() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 10,
            hour: 22
        )))
        let expectedDate = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 11,
            hour: 7
        )))
        let clock = TestFocusClock(now: now)
        let service = MockLocalNotificationService(status: .authorized)
        let manager = PushManager(
            service: service,
            clock: clock,
            calendar: calendar,
            preferences: NotificationPreferences(
                planRemindersEnabled: false,
                focusCompletionEnabled: true,
                rewardExpiryEnabled: true,
                quietHours: NotificationQuietHours(
                    startMinuteOfDay: 22 * 60,
                    endMinuteOfDay: 7 * 60
                )
            )
        )
        let session = FocusSessionModel(
            focusSessionId: "focus-session-quiet",
            activityId: ActivityModel.mock.activityId,
            state: .running,
            startedAt: now,
            focusEndsAt: now.addingTimeInterval(1_500)
        )

        manager.scheduleFocusCompletion(for: session)
        await waitForRequestCount(1, service: service)

        #expect(service.scheduledRequests.first?.deliveryDate == expectedDate)
    }

    private func waitForRequestCount(
        _ count: Int,
        service: MockLocalNotificationService
    ) async {
        for _ in 0..<20 where service.scheduledRequests.count < count {
            await Task.yield()
        }
    }

    private func allowPendingOperationsToFinish() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }

    private func enabledPreferences() -> NotificationPreferences {
        NotificationPreferences(
            planRemindersEnabled: true,
            focusCompletionEnabled: true,
            rewardExpiryEnabled: true,
            quietHours: nil
        )
    }

    private func assertCopyIsWarm(_ requests: [LocalNotificationRequest]) {
        let copy = requests.map { $0.title + " " + $0.body }.joined().lowercased()
        #expect(!copy.contains("failed"))
        #expect(!copy.contains("lazy"))
        #expect(!copy.contains("quota"))
    }
}
