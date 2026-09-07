import Foundation
import Observation

@Observable
@MainActor
final class FocusManager {

    private let repository: FocusRepository
    private let clock: FocusClock

    init(
        repository: FocusRepository = MockFocusRepository(),
        clock: FocusClock = SystemFocusClock()
    ) {
        self.repository = repository
        self.clock = clock
    }

    var activities: [ActivityModel] {
        repository.snapshot.activities
    }

    var dailyPlan: DailyPlanModel? {
        repository.snapshot.dailyPlan
    }

    var completedSessionCount: Int {
        repository.snapshot.completedSessionCount
    }

    var rewardCredits: Int {
        repository.snapshot.rewardCredits
    }

    var progression: ProgressionSnapshotModel {
        repository.snapshot.progression
    }

    var focusSessions: [FocusSessionModel] {
        repository.snapshot.focusSessions
    }

    var creditLedger: [RewardCreditLedgerEntry] {
        repository.snapshot.creditLedger
    }

    var progressionAwards: [ProgressionAwardModel] {
        repository.snapshot.progressionAwards
    }

    var activeFocusSession: FocusSessionModel? {
        focusSessions.last { session in
            session.state == .ready || session.state == .running || session.state == .paused
        }
    }

    @discardableResult
    func startFocusSession(activityId: String) -> FocusSessionModel? {
        let snapshot = repository.snapshot
        guard snapshot.activities.contains(where: { $0.activityId == activityId && !$0.isArchived }) else {
            return nil
        }

        if let activeFocusSession {
            return activeFocusSession.activityId == activityId ? activeFocusSession : nil
        }

        let isBonusSession = snapshot.dailyPlan.map { plan in
            guard let item = plan.planItems.first(where: { $0.activityId == activityId }) else {
                return true
            }
            return completedSessionCount(for: activityId) >= item.plannedSessionCount
        } ?? true

        let session = FocusSessionModel(
            focusSessionId: "focus-session-" + String(snapshot.nextSessionNumber),
            activityId: activityId,
            state: .ready,
            startedAt: clock.now,
            isBonusSession: isBonusSession
        )

        do {
            try repository.transaction { snapshot in
                snapshot.focusSessions.append(session)
                snapshot.nextSessionNumber += 1
            }
            return session
        } catch {
            return nil
        }
    }

    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel {
        guard activeFocusSession == nil else {
            throw FocusManagerError.activeSessionExists
        }
        guard let session = startFocusSession(activityId: activityId) else {
            throw FocusManagerError.persistenceFailed
        }
        return session
    }

    @discardableResult
    func beginFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state == .ready else {
            guard session.state == .running else { throw FocusManagerError.invalidState }
            return session
        }

        let runningSession = session.updated(
            state: .running,
            focusEndsAt: clock.now.addingTimeInterval(TimeInterval(session.durationSeconds))
        )
        try replace(runningSession)
        return runningSession
    }

    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh {
        var session = try session(for: focusSessionId)

        if session.state == .running, session.focusEndsAt == nil {
            let focusEndsAt = session.startedAt.addingTimeInterval(TimeInterval(session.durationSeconds))
            session = session.updated(state: .running, focusEndsAt: focusEndsAt)
            try replace(session)
        }

        if session.state == .running,
           let focusEndsAt = session.focusEndsAt,
           clock.now >= focusEndsAt {
            let completedSession = try completeNaturally(session)
            return FocusSessionRefresh(
                session: completedSession,
                remainingFocusSeconds: 0,
                remainingPauseSeconds: 0,
                completion: completionResult(for: completedSession)
            )
        }

        let remainingFocusSeconds: Int
        switch session.state {
        case .ready:
            remainingFocusSeconds = session.durationSeconds
        case .running, .paused, .completed, .abandoned:
            remainingFocusSeconds = remainingSeconds(
                until: session.focusEndsAt ?? session.startedAt.addingTimeInterval(TimeInterval(session.durationSeconds))
            )
        }

        let remainingPauseSeconds = pauseRemaining(for: session)
        let visibleSession = session.updated(
            state: session.state,
            pauseRemainingSeconds: remainingPauseSeconds
        )
        return FocusSessionRefresh(
            session: visibleSession,
            remainingFocusSeconds: remainingFocusSeconds,
            remainingPauseSeconds: remainingPauseSeconds,
            completion: session.state == .completed ? completionResult(for: session) : nil
        )
    }

    @discardableResult
    func pauseFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let refresh = try refreshFocusSession(focusSessionId: focusSessionId)
        guard refresh.session.state == .running else {
            if refresh.session.state == .completed { throw FocusManagerError.invalidState }
            throw refresh.session.pauseUsed ? FocusManagerError.pauseAlreadyUsed : FocusManagerError.invalidState
        }
        guard !refresh.session.pauseUsed else { throw FocusManagerError.pauseAlreadyUsed }

        let pausedSession = refresh.session.updated(
            state: .paused,
            pausedAt: clock.now,
            pauseUsed: true,
            pauseRemainingSeconds: FocusSessionModel.pauseAllowanceSeconds
        )
        try replace(pausedSession)
        return pausedSession
    }

    @discardableResult
    func resumeFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state == .paused, let pausedAt = session.pausedAt else {
            throw FocusManagerError.invalidState
        }

        let elapsedPause = min(
            max(clock.now.timeIntervalSince(pausedAt), 0),
            TimeInterval(FocusSessionModel.pauseAllowanceSeconds)
        )
        let resumedSession = session.updated(
            state: .running,
            focusEndsAt: (session.focusEndsAt ?? clock.now).addingTimeInterval(elapsedPause),
            pauseRemainingSeconds: FocusSessionModel.pauseAllowanceSeconds - Int(elapsedPause)
        )
        try replace(resumedSession)
        return resumedSession
    }

    @discardableResult
    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state != .completed && session.state != .abandoned else {
            return session
        }

        let abandonedSession = session.updated(state: .abandoned)
        try replace(abandonedSession)
        return abandonedSession
    }

#if MOCK
    @discardableResult
    func markFocusSessionCompleteForTesting(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state != .completed && session.state != .abandoned else {
            return session
        }

        let runningSession = session.updated(
            state: .running,
            focusEndsAt: clock.now
        )
        return try completeNaturally(runningSession)
    }
#endif

    func completedSessionCount(for activityId: String) -> Int {
        focusSessions.filter {
            $0.activityId == activityId && $0.state == .completed
        }.count
    }

    private func session(for focusSessionId: String) throws -> FocusSessionModel {
        guard let session = focusSessions.first(where: { $0.focusSessionId == focusSessionId }) else {
            throw FocusManagerError.sessionNotFound
        }
        return session
    }

    private func replace(_ session: FocusSessionModel) throws {
        guard repository.snapshot.focusSessions.contains(where: { $0.focusSessionId == session.focusSessionId }) else {
            throw FocusManagerError.sessionNotFound
        }
        try repository.transaction { snapshot in
            guard let index = snapshot.focusSessions.firstIndex(where: { $0.focusSessionId == session.focusSessionId }) else {
                return
            }
            snapshot.focusSessions[index] = session
        }
    }

    private func remainingSeconds(until endDate: Date?) -> Int {
        guard let endDate else { return FocusSessionModel.durationMinutes * 60 }
        return max(Int(ceil(endDate.timeIntervalSince(clock.now))), 0)
    }

    private func pauseRemaining(for session: FocusSessionModel) -> Int {
        guard session.state == .paused, let pausedAt = session.pausedAt else {
            return session.state == .completed || session.state == .abandoned ? 0 : session.pauseRemainingSeconds
        }
        return max(
            FocusSessionModel.pauseAllowanceSeconds - Int(ceil(max(clock.now.timeIntervalSince(pausedAt), 0))),
            0
        )
    }

    private func completeNaturally(_ session: FocusSessionModel) throws -> FocusSessionModel {
        guard session.state == .running else { return session }

        let completedSession = session.updated(
            state: .completed,
            completedAt: clock.now,
            pauseRemainingSeconds: 0
        )
        let creditKey = "focus-session-" + session.focusSessionId + "-credit"
        let xpKey = "focus-session-" + session.focusSessionId + "-xp"

        try repository.transaction { snapshot in
            guard let index = snapshot.focusSessions.firstIndex(where: { $0.focusSessionId == session.focusSessionId }) else {
                return
            }
            guard snapshot.focusSessions[index].state != .completed else { return }

            snapshot.focusSessions[index] = completedSession
            snapshot.completedSessionCount += 1

            if !snapshot.creditLedger.contains(where: { $0.idempotencyKey == creditKey }) {
                snapshot.creditLedger.append(
                    RewardCreditLedgerEntry(
                        ledgerEntryId: "credit-" + session.focusSessionId,
                        focusSessionId: session.focusSessionId,
                        amount: 1,
                        awardedAt: clock.now,
                        idempotencyKey: creditKey
                    )
                )
                snapshot.rewardCredits += 1
            }

            if !snapshot.progressionAwards.contains(where: { $0.idempotencyKey == xpKey }) {
                snapshot.progressionAwards.append(
                    ProgressionAwardModel(
                        awardId: "progression-award-" + session.focusSessionId,
                        focusSessionId: session.focusSessionId,
                        source: session.isBonusSession ? .bonusSession : .focusSession,
                        awardedAt: clock.now,
                        idempotencyKey: xpKey
                    )
                )
                snapshot.progression = ProgressionSnapshotModel(totalXP: snapshot.progression.totalXP + 10)
            }
        }
        return completedSession
    }

    private func completionResult(for session: FocusSessionModel) -> FocusCompletionResult {
        let snapshot = repository.snapshot
        return FocusCompletionResult(
            focusSessionId: session.focusSessionId,
            rewardCreditsAwarded: snapshot.creditLedger.contains(where: { $0.focusSessionId == session.focusSessionId }) ? 1 : 0,
            xpAwarded: snapshot.progressionAwards.first(where: { $0.focusSessionId == session.focusSessionId })?.points ?? 0,
            rewardCreditBalance: snapshot.rewardCredits,
            progression: snapshot.progression
        )
    }
}
