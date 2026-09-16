import SwiftUI

@MainActor
protocol FocusInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }

    func setFocusScreenVisible(_ isVisible: Bool)
    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh
    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func pauseFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func resumeFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel
    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel
#if MOCK
    func markFocusSessionCompleteForTesting(focusSessionId: String) throws -> FocusSessionModel
#endif
}

extension CoreInteractor: FocusInteractor {
    var activeFocusSession: FocusSessionModel? {
        focusManager.activeFocusSession
    }

    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh {
        let refresh = try focusManager.refreshFocusSession(focusSessionId: focusSessionId)
        if refresh.completion != nil {
            scheduleStreakRecording(for: refresh.session)
            scheduleSharedProgressSync(for: refresh.session.localDay)
            Task { await updateSocialFocusStatus(.available) }
        }
        return refresh
    }

    func recordFocusCompletionForStreak(_ session: FocusSessionModel) async throws {
        guard session.state == .completed else { return }

        let existingEvents = try await getAllStreakEvents()
        let focusSessionId = GamificationDictionaryValue.string(session.focusSessionId)
        let alreadyRecorded = existingEvents.contains(where: {
            $0.metadata["focus_session_id"] == focusSessionId
        })

        if !alreadyRecorded {
            try await addStreakEvent(metadata: [
                "focus_session_id": focusSessionId,
                "source": .string("focus_session")
            ])
        }

        await awardStreakFreezeIfEligible(focusSessionId: session.focusSessionId)
    }

    private func awardStreakFreezeIfEligible(focusSessionId: String) async {
        let streakData = currentStreakData
        guard let currentStreak = streakData.currentStreak,
              currentStreak > 0,
              currentStreak.isMultiple(of: StreakFreezePolicy.milestoneInterval),
              let streakStart = streakData.dateStreakStart else { return }

        do {
            let freezes = try await getAllStreakFreezes()
            let freezeId = StreakFreezePolicy.freezeId(
                streakStart: streakStart,
                milestone: currentStreak
            )
            guard !freezes.contains(where: { $0.id == freezeId }) else { return }
            guard freezes.filter(\.isAvailable).count < StreakFreezePolicy.maximumAvailableFreezes else { return }
            try await addStreakFreeze(id: freezeId)
        } catch {
            var parameters = error.eventParameters
            parameters["focus_session_id"] = focusSessionId
            parameters["streak_count"] = currentStreak
            trackEvent(
                eventName: "Focus_StreakFreezeAward_Fail",
                parameters: parameters,
                type: .severe
            )
        }
    }

    private func scheduleStreakRecording(for session: FocusSessionModel) {
        Task {
            do {
                try await recordFocusCompletionForStreak(session)
            } catch {
                var parameters = error.eventParameters
                parameters["focus_session_id"] = session.focusSessionId
                trackEvent(
                    eventName: "Focus_StreakRecording_Fail",
                    parameters: parameters,
                    type: .severe
                )
            }
        }
    }

    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        guard !isRewardInProgress else { throw FocusManagerError.rewardInProgress }
        let session = try focusManager.beginFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.focusing) }
        return session
    }

    func pauseFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try focusManager.pauseFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.available) }
        return session
    }

    func resumeFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        guard !isRewardInProgress else { throw FocusManagerError.rewardInProgress }
        let session = try focusManager.resumeFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.focusing) }
        return session
    }

    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try focusManager.abandonFocusSession(focusSessionId: focusSessionId)
        Task { await updateSocialFocusStatus(.available) }
        return session
    }

    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel {
        guard !isRewardInProgress else { throw FocusManagerError.rewardInProgress }
        return try focusManager.startAnotherFocusSession(activityId: activityId)
    }

#if MOCK
    func markFocusSessionCompleteForTesting(focusSessionId: String) throws -> FocusSessionModel {
        try focusManager.markFocusSessionCompleteForTesting(focusSessionId: focusSessionId)
    }
#endif
}
