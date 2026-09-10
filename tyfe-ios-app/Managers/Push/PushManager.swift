import Foundation
import Observation

@MainActor
@Observable
final class PushManager: LocalTimerNotificationScheduling {

    @ObservationIgnored private let service: LocalNotificationService
    @ObservationIgnored private let logManager: LogManager?
    @ObservationIgnored private let clock: FocusClock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let userDefaults: UserDefaults?
    @ObservationIgnored private var pendingOperations: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var desiredGroups: [String: PendingLocalNotificationGroup] = [:]

    private(set) var preferences: NotificationPreferences

    private static let preferencesKey = "tyfe.notification-preferences"
    private static let planPrefix = "tyfe.plan."
    private static let focusPrefix = "tyfe.focus."
    private static let rewardPrefix = "tyfe.reward."

    init(
        service: LocalNotificationService = SystemLocalNotificationService(),
        logManager: LogManager? = nil,
        clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent,
        preferences: NotificationPreferences = .default,
        userDefaults: UserDefaults? = nil
    ) {
        self.service = service
        self.logManager = logManager
        self.clock = clock
        self.calendar = calendar
        self.preferences = Self.loadPreferences(from: userDefaults) ?? preferences
        self.userDefaults = userDefaults
    }

    func requestAuthorization() async throws -> Bool {
        let isAuthorized = try await service.requestAuthorization()
        logManager?.addUserProperties(
            dict: ["push_is_authorized": isAuthorized],
            isHighPriority: true
        )
        if isAuthorized {
            synchronizeDesiredGroups()
        }
        return isAuthorized
    }

    func canRequestAuthorization() async -> Bool {
        await service.authorizationStatus() == .notDetermined
    }

    func updatePreferences(_ preferences: NotificationPreferences) {
        self.preferences = preferences
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults?.set(data, forKey: Self.preferencesKey)
        synchronizeDesiredGroups()
    }

    func schedulePlanReminders(for plan: DailyPlanModel) {
        let operationKey = planOperationKey(dailyPlanId: plan.dailyPlanId)
        let prefix = planIdentifierPrefix(dailyPlanId: plan.dailyPlanId)
        let requests = plan.timeBlocks?.compactMap {
            planReminderRequest(for: $0, dailyPlanId: plan.dailyPlanId)
        } ?? []
        setDesiredGroup(
            PendingLocalNotificationGroup(
                identifierPrefix: prefix,
                kind: .planReminder,
                requests: requests
            ),
            operationKey: operationKey
        )
    }

    func cancelPlanReminders(dailyPlanId: String) {
        cancelRequests(
            operationKey: planOperationKey(dailyPlanId: dailyPlanId),
            matching: planIdentifierPrefix(dailyPlanId: dailyPlanId)
        )
    }

    func scheduleFocusCompletion(for session: FocusSessionModel) {
        guard let focusEndsAt = session.focusEndsAt, session.state == .running else {
            cancelFocusCompletion(focusSessionId: session.focusSessionId)
            return
        }

        let identifier = focusIdentifier(focusSessionId: session.focusSessionId)
        let requests = [LocalNotificationRequest(
                identifier: identifier,
                title: "Focus Session complete",
                body: "Nice work. Your Reward Credit is ready.",
                deliveryDate: focusEndsAt
            )]
        setDesiredGroup(
            PendingLocalNotificationGroup(
                identifierPrefix: identifier,
                kind: .focusCompletion,
                requests: requests
            ),
            operationKey: identifier
        )
    }

    func cancelFocusCompletion(focusSessionId: String) {
        let identifier = focusIdentifier(focusSessionId: focusSessionId)
        cancelRequests(operationKey: identifier, matching: identifier)
    }

    func scheduleRewardExpiry(for claim: RewardClaimModel) {
        guard let endsAt = claim.endsAt, claim.state == .active else {
            cancelRewardExpiry(rewardClaimId: claim.rewardClaimId)
            return
        }

        let identifier = rewardIdentifier(rewardClaimId: claim.rewardClaimId)
        let requests = [LocalNotificationRequest(
                identifier: identifier,
                title: "Reward time is complete",
                body: "Hope the break helped. Come back whenever you’re ready.",
                deliveryDate: endsAt
            )]
        setDesiredGroup(
            PendingLocalNotificationGroup(
                identifierPrefix: identifier,
                kind: .rewardExpiry,
                requests: requests
            ),
            operationKey: identifier
        )
    }

    func cancelRewardExpiry(rewardClaimId: String) {
        let identifier = rewardIdentifier(rewardClaimId: rewardClaimId)
        cancelRequests(operationKey: identifier, matching: identifier)
    }

    private func planReminderRequest(
        for timeBlock: PlanTimeBlockModel,
        dailyPlanId: String
    ) -> LocalNotificationRequest? {
        guard let plannedStart = timeBlock.plannedStart else { return nil }
        return LocalNotificationRequest(
            identifier: planIdentifierPrefix(dailyPlanId: dailyPlanId) + timeBlock.timeBlockId,
            title: "Ready when you are",
            body: "Your planned Focus Session is waiting whenever it feels right.",
            deliveryDate: plannedStart
        )
    }

    private func allowedDeliveryDate(for date: Date) -> Date {
        preferences.quietHours?.nextAllowedDate(for: date, calendar: calendar) ?? date
    }

    private func replaceOperation(
        for key: String,
        operation: @escaping @MainActor () async -> Void
    ) {
        pendingOperations[key]?.cancel()
        pendingOperations[key] = Task {
            await operation()
        }
    }

    private func setDesiredGroup(
        _ group: PendingLocalNotificationGroup,
        operationKey: String
    ) {
        desiredGroups[operationKey] = group
        synchronize(group, operationKey: operationKey)
    }

    private func synchronizeDesiredGroups() {
        for (operationKey, group) in desiredGroups {
            synchronize(group, operationKey: operationKey)
        }
    }

    private func synchronize(
        _ group: PendingLocalNotificationGroup,
        operationKey: String
    ) {
        replaceOperation(for: operationKey) { [weak self] in
            guard let self else { return }
            await replaceRequests(
                group.requests,
                matching: group.identifierPrefix,
                kind: group.kind
            )
        }
    }

    private func cancelRequests(operationKey: String, matching identifierOrPrefix: String) {
        pendingOperations[operationKey]?.cancel()
        desiredGroups[operationKey] = nil
        replaceOperation(for: operationKey) { [weak self] in
            guard let self else { return }
            await removeRequests(matching: identifierOrPrefix)
        }
    }

    private func replaceRequests(
        _ requests: [LocalNotificationRequest],
        matching identifierOrPrefix: String,
        kind: LocalNotificationKind
    ) async {
        await removeRequests(matching: identifierOrPrefix)
        guard !Task.isCancelled else { return }
        guard notificationsEnabled(for: kind) else { return }
        guard await service.authorizationStatus() == .authorized else { return }
        guard !Task.isCancelled else { return }

        do {
            for request in requests {
                guard !Task.isCancelled else { return }
                let deliveryDate = allowedDeliveryDate(for: request.deliveryDate)
                guard deliveryDate > clock.now else { continue }
                try await service.schedule(LocalNotificationRequest(
                    identifier: request.identifier,
                    title: request.title,
                    body: request.body,
                    deliveryDate: deliveryDate
                ))
            }
            logManager?.trackEvent(event: Event.scheduleSuccess(kind: kind))
        } catch {
            logManager?.trackEvent(event: Event.scheduleFail(kind: kind, error: error))
        }
    }

    private func notificationsEnabled(for kind: LocalNotificationKind) -> Bool {
        switch kind {
        case .planReminder:
            return preferences.planRemindersEnabled
        case .focusCompletion:
            return preferences.focusCompletionEnabled
        case .rewardExpiry:
            return preferences.rewardExpiryEnabled
        }
    }

    private func removeRequests(matching identifierOrPrefix: String) async {
        let identifiers = await service.pendingRequestIdentifiers().filter {
            $0 == identifierOrPrefix || $0.hasPrefix(identifierOrPrefix)
        }
        guard !identifiers.isEmpty else { return }
        service.removePendingRequests(withIdentifiers: identifiers)
    }

    private func planOperationKey(dailyPlanId: String) -> String {
        Self.planPrefix + dailyPlanId
    }

    private func planIdentifierPrefix(dailyPlanId: String) -> String {
        Self.planPrefix + dailyPlanId + "."
    }

    private func focusIdentifier(focusSessionId: String) -> String {
        Self.focusPrefix + focusSessionId + ".completion"
    }

    private func rewardIdentifier(rewardClaimId: String) -> String {
        Self.rewardPrefix + rewardClaimId + ".expiry"
    }

    private static func loadPreferences(from userDefaults: UserDefaults?) -> NotificationPreferences? {
        guard let data = userDefaults?.data(forKey: preferencesKey) else { return nil }
        return try? JSONDecoder().decode(NotificationPreferences.self, from: data)
    }

    enum Event: LoggableEvent {
        case scheduleSuccess(kind: LocalNotificationKind)
        case scheduleFail(kind: LocalNotificationKind, error: Error)

        var eventName: String {
            switch self {
            case .scheduleSuccess:
                return "PushMan_Schedule_Success"
            case .scheduleFail:
                return "PushMan_Schedule_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .scheduleSuccess(kind: let kind):
                return ["notification_kind": kind.rawValue]
            case .scheduleFail(kind: let kind, error: let error):
                return [
                    "notification_kind": kind.rawValue,
                    "error": error.localizedDescription
                ]
            }
        }

        var type: LogType {
            switch self {
            case .scheduleSuccess:
                return .analytic
            case .scheduleFail:
                return .severe
            }
        }
    }
}
