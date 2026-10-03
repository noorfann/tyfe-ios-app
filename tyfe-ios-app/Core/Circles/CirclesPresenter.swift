import SwiftUI

@Observable
@MainActor
final class CirclesPresenter {

    private let interactor: CirclesInteractor
    private let router: CirclesRouter

    private(set) var refreshTask: Task<Void, Never>?
    private var photoRenewalTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var isVisible = false
    private var visibleUserId: String?
    private var refreshGeneration = 0
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
    var isEditCirclePresented = false
    var createCircleName = ""
    var editCircleName = ""
    var joinCode = ""

    init(interactor: CirclesInteractor, router: CirclesRouter) {
        self.interactor = interactor
        self.router = router
    }

    var canAccessCircles: Bool { interactor.canAccessCircles }

    var accountActionTitle: String {
        interactor.pendingEmailRegistration == nil ? "Create account" : "Finish creating account"
    }

    var selectedCircle: CircleModel? {
        circles.first { $0.circleId == selectedCircleId }
    }

    var currentUserId: String? {
        interactor.currentAuthUserId?.lowercased()
    }

    var isSelectedCircleOwner: Bool {
        canAccessCircles && selectedCircle?.ownerId.lowercased() == currentUserId
    }

    var focusStatusByUser: [String: CircleFocusStatus] {
        let entries = interactor.socialFocusStatuses[selectedCircleId ?? ""] ?? []
        return entries.reduce(into: [String: CircleFocusStatus]()) { result, entry in
            result[entry.userId.lowercased()] = entry.status
        }
    }

    var lastSyncedText: String? {
        guard let lastSyncedAt else { return nil }
        return lastSyncedAt.formatted(.relative(presentation: .named))
    }

    func onRetry() {
        onAccountStatusChanged()
    }

    func memberProgress(for userId: String) -> CircleMemberProgressModel? {
        progressByUser[userId]
    }

    func focusStatus(for userId: String) -> CircleFocusStatus? {
        focusStatusByUser[userId.lowercased()]
    }

    func photoURL(for member: CircleMemberModel) -> URL? {
        interactor.circlePhotoURL(for: member)
    }

    // MARK: Lifecycle

    func onViewAppear(delegate: CirclesDelegate) {
        isVisible = true
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        onAccountStatusChanged()
    }

    func onViewDisappear(delegate: CirclesDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
        isVisible = false
        refreshGeneration += 1
        refreshTask?.cancel()
        selectionTask?.cancel()
        photoRenewalTask?.cancel()
        photoRenewalTask = nil
    }

    func onSceneBecameActive() {
        guard isVisible else { return }
        onAccountStatusChanged()
    }

    // MARK: Account

    func onCreateAccountTapped() {
        interactor.trackEvent(event: Event.createAccount)
        router.showSignUpView(delegate: SignUpDelegate(onDidSignIn: { [weak self] in
            self?.onAccountStatusChanged()
        }))
    }

    func onSignInTapped() {
        interactor.trackEvent(event: Event.signIn)
        router.showCirclesSignInView(onDidSignIn: { [weak self] in
            self?.onAccountStatusChanged()
        })
    }

    func onAccountStatusChanged() {
        refreshGeneration += 1
        refreshTask?.cancel()
        selectionTask?.cancel()
        photoRenewalTask?.cancel()
        if !canAccessCircles || visibleUserId != currentUserId { resetLocalState() }
        visibleUserId = currentUserId
        refreshTask = Task { await refresh() }
        if isVisible && canAccessCircles {
            photoRenewalTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(240)) } catch { return }
                    guard !Task.isCancelled, let self, self.isVisible, self.canAccessCircles else { return }
                    await self.loadSelectedCircle()
                }
            }
        }
    }

    // MARK: Circles

    func onSelectCircle(_ circleId: String) {
        guard canAccessCircles else { return }
        selectionTask?.cancel()
        selectedCircleId = circleId
        members = []
        progressByUser = [:]
        selectionTask = Task { await loadSelectedCircle() }
    }

    func onCreateCircleTapped() {
        guard canAccessCircles else { return }
        createCircleName = ""
        isCreateCirclePresented = true
    }

    func onSubmitCreateCircle() {
        guard canAccessCircles else { return }
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

    func onEditCircleTapped() {
        guard isSelectedCircleOwner, let circle = selectedCircle else { return }
        editCircleName = circle.name
        isEditCirclePresented = true
    }

    func onSubmitEditCircle() {
        guard canAccessCircles else { return }
        let name = editCircleName
        isEditCirclePresented = false
        Task {
            guard let circleId = selectedCircleId else { return }
            do {
                _ = try await interactor.updateCircle(circleId: circleId, name: name)
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onDeleteCircleTapped() {
        guard isSelectedCircleOwner, let circle = selectedCircle else { return }
        router.showAlert(
            .alert,
            title: "Delete \(circle.name)?",
            subtitle: "This removes the Circle for everyone. This can't be undone.",
            buttons: {
                AnyView(
                    Group {
                        Button("Delete Circle", role: .destructive) {
                            self.onDeleteCircleConfirmed()
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func onDeleteCircleConfirmed() {
        guard canAccessCircles else { return }
        Task {
            guard let circleId = selectedCircleId else { return }
            do {
                try await interactor.deleteCircle(circleId: circleId)
                selectedCircleId = nil
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onJoinCircleTapped() {
        guard canAccessCircles else { return }
        joinCode = ""
        isJoinCirclePresented = true
    }

    func onSubmitJoinCode() {
        guard canAccessCircles else { return }
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
        guard canAccessCircles else { return }
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
        guard canAccessCircles else { return }
        Task {
            do {
                try await interactor.sendCheer(kind, recipientId: userId)
                try await interactor.refreshSocialCheers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func sentCheerKinds(to userId: String) -> Set<CheerKind> {
        CheerModel.sentKinds(
            in: interactor.socialCheers,
            from: currentUserId,
            to: userId
        )
    }

    func onLeaveCircleTapped() {
        guard canAccessCircles else { return }
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

    func onRemoveMemberTapped(_ userId: String) {
        guard isSelectedCircleOwner,
              let member = members.first(where: { $0.userId == userId }) else { return }
        let circleName = selectedCircle?.name ?? "this Circle"
        router.showAlert(
            .alert,
            title: "Remove \(member.displayName)?",
            subtitle: "They'll be removed from \(circleName). You can invite them again later.",
            buttons: {
                AnyView(
                    Group {
                        Button("Remove", role: .destructive) {
                            self.onRemoveMemberConfirmed(userId)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func onDismissError() {
        errorMessage = nil
    }

    // MARK: Private

    private func onRemoveMemberConfirmed(_ userId: String) {
        guard canAccessCircles else { return }
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

    private func refresh() async {
        guard canAccessCircles, let userId = interactor.currentAuthUserId else {
            resetLocalState()
            await interactor.syncSocialRealtime()
            return
        }
        let generation = refreshGeneration
        isLoading = true
        defer { if generation == refreshGeneration { isLoading = false } }
        do {
            try await interactor.refreshSocialCircles(userId: userId)
            guard generation == refreshGeneration, !Task.isCancelled,
                  canAccessCircles, currentUserId == userId.lowercased() else { return }
            circles = interactor.socialCircles
            if selectedCircleId == nil || !circles.contains(where: { $0.circleId == selectedCircleId }) {
                selectedCircleId = circles.first?.circleId
            }
            lastSyncedAt = .now
            isOffline = false
            await loadSelectedCircle()
            guard generation == refreshGeneration, !Task.isCancelled,
                  canAccessCircles, currentUserId == userId.lowercased() else { return }
            await interactor.syncSocialRealtime()
            try? await interactor.refreshSocialCheers()
        } catch {
            guard generation == refreshGeneration, !Task.isCancelled,
                  canAccessCircles, currentUserId == userId.lowercased() else { return }
            isOffline = true
        }
    }

    private func loadSelectedCircle() async {
        guard canAccessCircles, let userId = currentUserId, let circleId = selectedCircleId else {
            members = []
            progressByUser = [:]
            return
        }
        let generation = refreshGeneration
        do {
            let fetchedMembers = try await interactor.circleMembers(circleId: circleId)
            guard generation == refreshGeneration, !Task.isCancelled,
                  canAccessCircles, currentUserId == userId, selectedCircleId == circleId else { return }
            members = fetchedMembers
            let progress = try await interactor.circleMemberProgress(circleId: circleId)
            guard generation == refreshGeneration, !Task.isCancelled,
                  canAccessCircles, currentUserId == userId, selectedCircleId == circleId else { return }
            progressByUser = Dictionary(uniqueKeysWithValues: progress.map { ($0.userId, $0) })
        } catch {
            guard generation == refreshGeneration, !Task.isCancelled,
                  canAccessCircles, currentUserId == userId, selectedCircleId == circleId else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func resetLocalState() {
        circles = []
        selectedCircleId = nil
        members = []
        progressByUser = [:]
        isOffline = false
        lastSyncedAt = nil
        errorMessage = nil
        inviteCode = nil
        isCreateCirclePresented = false
        isJoinCirclePresented = false
        isInvitePresented = false
        isEditCirclePresented = false
    }
}

extension CirclesPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: CirclesDelegate)
        case onDisappear(delegate: CirclesDelegate)
        case createAccount
        case signIn

        var eventName: String {
            switch self {
            case .onAppear:    return "CirclesView_Appear"
            case .onDisappear: return "CirclesView_Disappear"
            case .createAccount: return "CirclesView_CreateAccount"
            case .signIn: return "CirclesView_SignIn"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createAccount, .signIn:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
