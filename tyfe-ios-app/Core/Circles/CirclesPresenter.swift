import SwiftUI

@Observable
@MainActor
final class CirclesPresenter {

    private let interactor: CirclesInteractor
    private let router: CirclesRouter

    private(set) var isSignedIn = false
    private(set) var circles: [CircleModel] = []
    private(set) var selectedCircleId: String?
    private(set) var members: [CircleMemberModel] = []
    private(set) var progressByUser: [String: CircleMemberProgressModel] = [:]
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var lastSyncedAt: Date?
    private(set) var errorMessage: String?
    private(set) var inviteCode: String?

    var isCreateCirclePresented = false
    var isJoinCirclePresented = false
    var isInvitePresented = false
    var createCircleName = ""
    var joinCode = ""

    init(interactor: CirclesInteractor, router: CirclesRouter) {
        self.interactor = interactor
        self.router = router
    }

    var selectedCircle: CircleModel? {
        circles.first { $0.circleId == selectedCircleId }
    }

    var currentUserId: String? {
        interactor.currentAuthUserId
    }

    var isSelectedCircleOwner: Bool {
        selectedCircle?.ownerId == interactor.currentAuthUserId
    }

    var focusStatusByUser: [String: CircleFocusStatus] {
        let entries = interactor.socialFocusStatuses[selectedCircleId ?? ""] ?? []
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.userId, $0.status) })
    }

    var lastSyncedText: String? {
        guard let lastSyncedAt else { return nil }
        return lastSyncedAt.formatted(.relative(presentation: .named))
    }

    func onRetry() {
        Task { await refresh() }
    }

    func memberProgress(for userId: String) -> CircleMemberProgressModel? {
        progressByUser[userId]
    }

    func focusStatus(for userId: String) -> CircleFocusStatus? {
        focusStatusByUser[userId]
    }

    // MARK: Lifecycle

    func onViewAppear(delegate: CirclesDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        Task { await refresh() }
    }

    func onViewDisappear(delegate: CirclesDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onSceneBecameActive() {
        Task { await refresh() }
    }

    // MARK: Account

    func onEnableCirclesTapped() {
        Task {
            do {
                _ = try await interactor.signInAnonymously()
                try await interactor.migrateLocalToSocial()
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Circles

    func onSelectCircle(_ circleId: String) {
        selectedCircleId = circleId
        Task { await loadSelectedCircle() }
    }

    func onCreateCircleTapped() {
        createCircleName = ""
        isCreateCirclePresented = true
    }

    func onSubmitCreateCircle() {
        let name = createCircleName
        isCreateCirclePresented = false
        Task {
            guard let userId = interactor.currentAuthUserId else { return }
            do {
                let circle = try await interactor.createCircle(name: name, ownerId: userId)
                selectedCircleId = circle.circleId
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onJoinCircleTapped() {
        joinCode = ""
        isJoinCirclePresented = true
    }

    func onSubmitJoinCode() {
        let code = joinCode
        isJoinCirclePresented = false
        Task {
            do {
                let circleId = try await interactor.acceptCircleInvite(code: code)
                selectedCircleId = circleId
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onGenerateInviteTapped() {
        Task {
            guard let userId = interactor.currentAuthUserId,
                  let circleId = selectedCircleId else { return }
            do {
                let invite = try await interactor.createCircleInvite(
                    circleId: circleId,
                    createdBy: userId,
                    expiresAt: Date().addingTimeInterval(7 * 86_400)
                )
                inviteCode = invite.code
                isInvitePresented = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onDismissInvite() {
        isInvitePresented = false
        inviteCode = nil
    }

    func onSendCheer(_ kind: CheerKind, to userId: String) {
        Task {
            do {
                try await interactor.sendCheer(kind, recipientId: userId)
                try await interactor.refreshSocialCheers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onLeaveCircleTapped() {
        Task {
            guard let userId = interactor.currentAuthUserId,
                  let circleId = selectedCircleId else { return }
            do {
                try await interactor.leaveCircle(circleId: circleId, userId: userId)
                selectedCircleId = nil
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onRemoveMember(_ userId: String) {
        Task {
            guard let circleId = selectedCircleId else { return }
            do {
                try await interactor.removeCircleMember(circleId: circleId, userId: userId)
                await loadSelectedCircle()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onDismissError() {
        errorMessage = nil
    }

    // MARK: Private

    private func refresh() async {
        guard let userId = interactor.currentAuthUserId else {
            resetLocalState()
            return
        }
        isSignedIn = true
        isLoading = true
        defer { isLoading = false }
        do {
            try await interactor.refreshSocialCircles(userId: userId)
            try await interactor.refreshSocialCheers()
            circles = interactor.socialCircles
            if selectedCircleId == nil || !circles.contains(where: { $0.circleId == selectedCircleId }) {
                selectedCircleId = circles.first?.circleId
            }
            lastSyncedAt = .now
            isOffline = false
            await interactor.syncSocialRealtime()
            await loadSelectedCircle()
        } catch {
            isOffline = true
        }
    }

    private func loadSelectedCircle() async {
        guard let circleId = selectedCircleId else {
            members = []
            progressByUser = [:]
            return
        }
        do {
            members = try await interactor.circleMembers(circleId: circleId)
            let progress = try await interactor.circleMemberProgress(circleId: circleId)
            progressByUser = Dictionary(uniqueKeysWithValues: progress.map { ($0.userId, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetLocalState() {
        isSignedIn = false
        circles = []
        selectedCircleId = nil
        members = []
        progressByUser = [:]
        isOffline = false
        lastSyncedAt = nil
    }
}

extension CirclesPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: CirclesDelegate)
        case onDisappear(delegate: CirclesDelegate)

        var eventName: String {
            switch self {
            case .onAppear:    return "CirclesView_Appear"
            case .onDisappear: return "CirclesView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
