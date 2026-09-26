import Foundation

#if os(iOS) && canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

@MainActor
final class SystemFocusLiveActivityScheduler: FocusLiveActivityScheduling {

#if os(iOS) && canImport(ActivityKit)
    private let userDefaults: UserDefaults
    private let dismissedSessionIdsKey = "tyfe.focus-live-activity.dismissed-session-ids"
    private var dismissedSessionIds: Set<String>
    private var stateTasks: [String: Task<Void, Never>] = [:]
#endif

    init(userDefaults: UserDefaults = .standard) {
#if os(iOS) && canImport(ActivityKit)
        self.userDefaults = userDefaults
        self.dismissedSessionIds = Set(
            userDefaults.stringArray(forKey: dismissedSessionIdsKey) ?? []
        )
#else
        _ = userDefaults
#endif
    }

    func start(for session: FocusSessionModel, activityTitle: String) {
#if os(iOS) && canImport(ActivityKit)
        let existingActivities = activities(for: session.focusSessionId)
        endImmediately(Array(existingActivities.dropFirst()))

        guard session.state == .running,
              let focusEndsAt = session.focusEndsAt,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard !dismissedSessionIds.contains(session.focusSessionId) else { return }

        let content = content(
            phase: .running,
            startedAt: session.startedAt,
            endsAt: focusEndsAt
        )

        if let existingActivity = existingActivities.first {
            Task { @MainActor [existingActivity] in
                await existingActivity.update(content)
            }
            observe(existingActivity)
            return
        }

        do {
            let activity = try Activity.request(
                attributes: FocusLiveActivityAttributes(
                    focusSessionId: session.focusSessionId,
                    activityTitle: activityTitle
                ),
                content: content,
                pushType: nil
            )
            observe(activity)
        } catch {
            return
        }
#else
        _ = (session, activityTitle)
#endif
    }

    func end(for session: FocusSessionModel, reason: FocusLiveActivityEndReason) {
#if os(iOS) && canImport(ActivityKit)
        let phase: FocusLiveActivityAttributes.Phase = switch reason {
        case .completed: .completed
        case .abandoned: .abandoned
        }
        let endsAt = session.focusEndsAt ?? session.startedAt
        let content = content(phase: phase, startedAt: session.startedAt, endsAt: endsAt)
        let dismissalPolicy: ActivityUIDismissalPolicy = switch reason {
        case .completed:
            .after(Date.now.addingTimeInterval(15 * 60))
        case .abandoned:
            .immediate
        }

        for activity in activities(for: session.focusSessionId) {
            Task { @MainActor [activity] in
                await activity.end(content, dismissalPolicy: dismissalPolicy)
            }
        }
#else
        _ = (session, reason)
#endif
    }

    func reconcile(activeSession: FocusSessionModel?, activityTitle: String?) {
#if os(iOS) && canImport(ActivityKit)
        guard let activeSession,
              activeSession.state == .running,
              let focusEndsAt = activeSession.focusEndsAt,
              Date.now < focusEndsAt,
              let activityTitle else {
            endImmediately(Activity<FocusLiveActivityAttributes>.activities)
            return
        }

        dismissedSessionIds.remove(activeSession.focusSessionId)
        persistDismissedSessionIds()
        start(for: activeSession, activityTitle: activityTitle)
#else
        _ = (activeSession, activityTitle)
#endif
    }

#if os(iOS) && canImport(ActivityKit)
    private func content(
        phase: FocusLiveActivityAttributes.Phase,
        startedAt: Date,
        endsAt: Date
    ) -> ActivityContent<FocusLiveActivityAttributes.ContentState> {
        ActivityContent(
            state: FocusLiveActivityAttributes.ContentState(
                phase: phase,
                startedAt: startedAt,
                endsAt: endsAt
            ),
            staleDate: endsAt,
            relevanceScore: 100
        )
    }

    private func activities(for sessionId: String) -> [Activity<FocusLiveActivityAttributes>] {
        Activity<FocusLiveActivityAttributes>.activities.filter {
            $0.attributes.focusSessionId == sessionId
        }
    }

    private func endImmediately(_ activities: [Activity<FocusLiveActivityAttributes>]) {
        for activity in activities {
            Task { @MainActor [activity] in
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }

    private func observe(_ activity: Activity<FocusLiveActivityAttributes>) {
        stateTasks[activity.id]?.cancel()
        stateTasks[activity.id] = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if state == .dismissed {
                    dismissedSessionIds.insert(activity.attributes.focusSessionId)
                    persistDismissedSessionIds()
                    return
                }
                if state == .ended {
                    return
                }
            }
        }
    }

    private func persistDismissedSessionIds() {
        userDefaults.set(
            Array(dismissedSessionIds),
            forKey: dismissedSessionIdsKey
        )
    }
#endif
}
