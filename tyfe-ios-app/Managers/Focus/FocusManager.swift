import Foundation
import Observation

@Observable
@MainActor
final class FocusManager {

    private let repository: LocalAppRepository
    private let clock: FocusClock
    private let calendar: Calendar
    private let notificationScheduler: LocalTimerNotificationScheduling?
    private let liveActivityScheduler: FocusLiveActivityScheduling?

    private(set) var stateRevision = 0

    init(
        repository: LocalAppRepository = MockLocalAppRepository(),
        clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent,
        notificationScheduler: LocalTimerNotificationScheduling? = nil,
        liveActivityScheduler: FocusLiveActivityScheduling? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.notificationScheduler = notificationScheduler
        self.liveActivityScheduler = liveActivityScheduler

        if let activeFocusSession {
            if activeFocusSession.state == .running {
                notificationScheduler?.scheduleFocusCompletion(for: activeFocusSession)
            } else if activeFocusSession.isResting {
                notificationScheduler?.scheduleFocusRestCompletion(for: activeFocusSession)
            }
        }
        reconcileLiveActivity()
    }

    var activities: [ActivityModel] {
        observableSnapshot.activities
    }

    var dailyPlan: DailyPlanModel? {
        dailyPlan(for: currentLocalDay)
    }

    var completedSessionCount: Int {
        focusSessions.filter { $0.state == .completed }.count
    }

    var rewardCredits: Int {
        observableSnapshot.creditLedger.balance
    }

    var focusSessions: [FocusSessionModel] {
        observableSnapshot.focusSessions
    }

    var creditLedger: [RewardCreditLedgerEntry] {
        observableSnapshot.creditLedger.entries
    }

    var activeFocusSession: FocusSessionModel? {
        focusSessions.last { session in
            session.state == .ready || session.state == .running || session.isResting
        }
    }

    func reconcileLiveActivity() {
        guard let session = activeFocusSession,
              session.state == .running,
              let focusEndsAt = session.focusEndsAt,
              clock.now < focusEndsAt else {
            liveActivityScheduler?.reconcile(activeSession: nil)
            return
        }

        liveActivityScheduler?.reconcile(activeSession: session)
    }

    var currentLocalDay: LocalDay {
        LocalDay(containing: clock.now, calendar: calendar)
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

        let plan = snapshot.dailyPlans.last { $0.localDay == currentLocalDay }
        let plannedItem = plan?.planItems.first { item in
            item.activityId == activityId
        }
        let hasPlannedCapacity = plannedItem.map { item in
            completedSessionCount(for: activityId, on: currentLocalDay) < item.plannedSessionCount
        } ?? false
        let dailyPlanIdAtStart = hasPlannedCapacity ? plan?.dailyPlanId : nil
        let isBonusSession = dailyPlanIdAtStart == nil

        let session = FocusSessionModel(
            focusSessionId: "focus-session-" + String(snapshot.nextSessionNumber),
            activityId: activityId,
            state: .ready,
            startedAt: clock.now,
            localDay: currentLocalDay,
            dailyPlanIdAtStart: dailyPlanIdAtStart,
            isBonusSession: isBonusSession
        )

        do {
            try repository.transaction { snapshot in
                snapshot.focusSessions.append(session)
                snapshot.nextSessionNumber += 1
            }
            stateRevision += 1
            return session
        } catch {
            return nil
        }
    }

    func dailyPlan(for localDay: LocalDay) -> DailyPlanModel? {
        observableSnapshot.dailyPlans.last { $0.localDay == localDay }
    }

    func completedSessionCount(on localDay: LocalDay) -> Int {
        focusSessions.filter {
            $0.localDay == localDay && $0.state == .completed && !$0.isBonusSession
        }.count
    }

    func completedSessionCount(for activityId: String, on localDay: LocalDay) -> Int {
        focusSessions.filter {
            $0.localDay == localDay
                && $0.activityId == activityId
                && $0.state == .completed
                && !$0.isBonusSession
        }.count
    }

    private func legacyBonusStatus(for session: FocusSessionModel, in snapshot: LocalAppSnapshot) -> Bool {
        guard !session.isBonusSession else { return true }
        let plan = snapshot.dailyPlans.last { plan in
            plan.localDay == session.localDay
                && (session.dailyPlanIdAtStart == nil || plan.dailyPlanId == session.dailyPlanIdAtStart)
        }
        guard let item = plan?.planItems.first(where: { $0.activityId == session.activityId }) else {
            return true
        }
        let completedCount = snapshot.focusSessions.filter {
            $0.focusSessionId != session.focusSessionId
                && $0.localDay == session.localDay
                && $0.activityId == session.activityId
                && $0.state == .completed
                && !$0.isBonusSession
        }.count
        return completedCount >= item.plannedSessionCount
    }

    func startAnotherFocusSession(activityId: String) throws -> FocusSessionModel {
        if let activeFocusSession {
            guard activeFocusSession.isResting else {
                throw FocusManagerError.activeSessionExists
            }
            _ = try skipFocusRest(focusSessionId: activeFocusSession.focusSessionId)
        } else if let pendingRestSession = focusSessions.last(where: {
            $0.activityId == activityId
                && $0.state == .completed
                && ($0.restState == .pending || $0.restState == .active)
        }) {
            _ = try skipFocusRest(focusSessionId: pendingRestSession.focusSessionId)
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
        notificationScheduler?.scheduleFocusCompletion(for: runningSession)
        liveActivityScheduler?.start(for: runningSession)
        return runningSession
    }

    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh {
        var session = try session(for: focusSessionId)

        if session.state == .running, session.focusEndsAt == nil {
            let focusEndsAt = session.startedAt.addingTimeInterval(TimeInterval(session.durationSeconds))
            session = session.updated(state: .running, focusEndsAt: focusEndsAt)
            try replace(session)
            notificationScheduler?.scheduleFocusCompletion(for: session)
            liveActivityScheduler?.start(for: session)
        }

        if session.state == .running,
           let focusEndsAt = session.focusEndsAt,
           clock.now >= focusEndsAt {
            let completedSession = try completeNaturally(session)
            return FocusSessionRefresh(
                session: completedSession,
                remainingFocusSeconds: 0,
                remainingRestSeconds: 0,
                completion: completionResult(for: completedSession)
            )
        }

        if session.isResting,
           let restEndsAt = session.restEndsAt,
           clock.now >= restEndsAt {
            let completedRest = try completeFocusRest(focusSessionId: session.focusSessionId)
            return FocusSessionRefresh(
                session: completedRest,
                remainingFocusSeconds: 0,
                remainingRestSeconds: 0,
                completion: completionResult(for: completedRest)
            )
        }

        let remainingFocusSeconds = self.remainingFocusSeconds(for: session)
        let remainingRestSeconds = self.remainingRestSeconds(for: session)
        return FocusSessionRefresh(
            session: session,
            remainingFocusSeconds: remainingFocusSeconds,
            remainingRestSeconds: remainingRestSeconds,
            completion: session.state == .completed ? completionResult(for: session) : nil
        )
    }

    @discardableResult
    func startFocusRest(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state == .completed, session.restState == .pending else {
            throw FocusManagerError.invalidState
        }

        let restingSession = session.updated(
            state: .completed,
            restState: .active,
            restEndsAt: .some(clock.now.addingTimeInterval(TimeInterval(FocusSessionModel.restDurationSeconds)))
        )
        try replace(restingSession)
        notificationScheduler?.scheduleFocusRestCompletion(for: restingSession)
        return restingSession
    }

    @discardableResult
    func completeFocusRest(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.isResting,
              let restEndsAt = session.restEndsAt,
              clock.now >= restEndsAt else {
            throw FocusManagerError.invalidState
        }

        return try finishRest(session)
    }

    @discardableResult
    func skipFocusRest(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state == .completed else {
            throw FocusManagerError.invalidState
        }
        guard session.restState == .pending || session.restState == .active else {
            return session
        }

        let skippedSession = session.updated(
            state: .completed,
            restState: .skipped,
            restEndsAt: .some(nil)
        )
        try replace(skippedSession)
        notificationScheduler?.cancelFocusRestCompletion(focusSessionId: skippedSession.focusSessionId)
        return skippedSession
    }

    @discardableResult
    func abandonFocusSession(focusSessionId: String) throws -> FocusSessionModel {
        let session = try session(for: focusSessionId)
        guard session.state != .completed && session.state != .abandoned else {
            return session
        }

        let abandonedSession = session.updated(state: .abandoned)
        try replace(abandonedSession)
        notificationScheduler?.cancelFocusCompletion(focusSessionId: abandonedSession.focusSessionId)
        liveActivityScheduler?.end(for: abandonedSession, reason: .abandoned)
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
        completedSessionCount(for: activityId, on: currentLocalDay)
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
        stateRevision += 1
    }

    private func remainingSeconds(until endDate: Date?) -> Int {
        guard let endDate else { return FocusSessionModel.durationMinutes * 60 }
        return max(Int(ceil(endDate.timeIntervalSince(clock.now))), 0)
    }

    private func remainingFocusSeconds(for session: FocusSessionModel) -> Int {
        switch session.state {
        case .ready:
            return session.durationSeconds
        case .running:
            return remainingSeconds(until: session.focusEndsAt)
        case .completed, .abandoned:
            return 0
        }
    }

    private func remainingRestSeconds(for session: FocusSessionModel) -> Int {
        guard session.isResting, let restEndsAt = session.restEndsAt else { return 0 }
        return remainingSeconds(until: restEndsAt)
    }

    private func completeNaturally(_ session: FocusSessionModel) throws -> FocusSessionModel {
        guard session.state == .running else { return session }

        let isBonusSession = legacyBonusStatus(for: session, in: repository.snapshot)
        let completedSession = session.updated(
            state: .completed,
            completedAt: clock.now,
            restState: .pending,
            restEndsAt: .some(nil),
            isBonusSession: isBonusSession
        )
        let creditKey = "focus-session-" + session.focusSessionId + "-credit"

        try repository.transaction { snapshot in
            guard let index = snapshot.focusSessions.firstIndex(where: { $0.focusSessionId == session.focusSessionId }) else {
                return
            }
            guard snapshot.focusSessions[index].state != .completed else { return }

            snapshot.focusSessions[index] = completedSession

            snapshot.creditLedger.startDay(currentLocalDay, now: clock.now)
            try snapshot.creditLedger.apply(
                RewardCreditLedgerEntry(
                    ledgerEntryId: "credit-" + session.focusSessionId,
                    source: .focusSession,
                    sourceId: session.focusSessionId,
                    amount: 1,
                    recordedAt: clock.now,
                    idempotencyKey: creditKey
                )
            )
        }
        stateRevision += 1
        notificationScheduler?.cancelFocusCompletion(focusSessionId: completedSession.focusSessionId)
        liveActivityScheduler?.end(for: completedSession, reason: .completed)
        return completedSession
    }

    private func finishRest(_ session: FocusSessionModel) throws -> FocusSessionModel {
        let completedRest = session.updated(
            state: .completed,
            restState: .completed,
            restEndsAt: .some(nil)
        )
        try replace(completedRest)
        notificationScheduler?.cancelFocusRestCompletion(focusSessionId: completedRest.focusSessionId)
        return completedRest
    }

    private func completionResult(for session: FocusSessionModel) -> FocusCompletionResult {
        let snapshot = observableSnapshot
        return FocusCompletionResult(
            focusSessionId: session.focusSessionId,
            rewardCreditsAwarded: snapshot.creditLedger.entries.contains {
                $0.source == .focusSession && $0.sourceId == session.focusSessionId
            } ? 1 : 0,
            rewardCreditBalance: snapshot.creditLedger.balance
        )
    }

    private var observableSnapshot: LocalAppSnapshot {
        _ = stateRevision
        return repository.snapshot
    }
}
