import Foundation

extension CoreInteractor {
    func getAllStreakFreezes() async throws -> [StreakFreeze] {
        if let userId = auth?.uid, effortStreakManager.hasBaseline(userId: userId) {
            return effortStreakManager.freezes(userId: userId)
        }
        return try await streakManager.getAllStreakFreezes()
    }

    func synchronizeCurrentDay() {
        do {
            try todoManager.prepare()
            rewardManager.synchronizeCreditDay()
            todayManager.materializeCurrentDay()
            try habitManager.prepare()
            reconcileEffortStreak()
        } catch {
            trackEvent(eventName: "Today_DayPreparation_Fail", parameters: nil, type: .severe)
        }
    }

    func refreshStreakAccount(userId: String) async {
        guard auth?.uid == userId else { return }
        if effortStreakManager.hasBaseline(userId: userId) {
            synchronizeCurrentDay()
            return
        }
        do {
            try await streakManager.logIn(userId: userId)
            let legacy = streakManager.currentStreakData
            let events = try await streakManager.getAllStreakEvents()
            let freezes = try await streakManager.getAllStreakFreezes()
            guard auth?.uid == userId else { return }
            synchronizeCurrentDay()
            try effortStreakManager.seed(userId: userId, legacy: legacy, events: events, freezes: freezes)
        } catch {
            trackEvent(eventName: "Account_StreakRefreshFailed", parameters: nil, type: .warning)
        }
    }
}
