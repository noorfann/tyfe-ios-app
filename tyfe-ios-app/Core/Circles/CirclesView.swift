import SwiftUI
import SwiftfulUI
import SwiftfulRouting

struct CirclesDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct CirclesView: View {

    @State private var presenter: CirclesPresenter
    let delegate: CirclesDelegate

    init(presenter: CirclesPresenter, delegate: CirclesDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        @Bindable var presenter = presenter

        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    if presenter.isSignedIn {
                        content
                    } else {
                        TyfeCircleEnableCardView(onEnable: { presenter.onEnableCirclesTapped() })
                    }
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .tyfeBottomSheet(
            isPresented: $presenter.isCreateCirclePresented,
            detents: [.medium],
            title: "New Circle"
        ) {
            TyfeCircleNameSheetCardView(
                label: "Circle name",
                placeholder: "Family",
                value: $presenter.createCircleName,
                actionTitle: "Create Circle",
                onSave: { presenter.onSubmitCreateCircle() }
            )
        }
        .tyfeBottomSheet(
            isPresented: $presenter.isJoinCirclePresented,
            detents: [.medium],
            title: "Join a Circle"
        ) {
            TyfeCircleNameSheetCardView(
                label: "Invite code",
                placeholder: "ABCD2345",
                value: $presenter.joinCode,
                actionTitle: "Join Circle",
                onSave: { presenter.onSubmitJoinCode() }
            )
        }
        .tyfeBottomSheet(
            isPresented: $presenter.isInvitePresented,
            detents: [.medium],
            title: "Invite Code",
            onClose: { presenter.onDismissInvite() },
            content: {
                TyfeCircleInviteCardView(code: presenter.inviteCode ?? "")
            }
        )
        .alert("Something went wrong", isPresented: Binding(
            get: { presenter.errorMessage != nil },
            set: { if !$0 { presenter.onDismissError() } }
        )) {
            Button("OK", role: .cancel) { presenter.onDismissError() }
        } message: {
            Text(presenter.errorMessage ?? "")
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    @ViewBuilder
    private var content: some View {
        if presenter.isLoading && presenter.circles.isEmpty {
            TyfeStatusView(kind: .loading)
        } else if presenter.isOffline && presenter.circles.isEmpty {
            TyfeStatusView(kind: .offline, onRetry: { presenter.onRetry() })
        } else {
            if presenter.isOffline {
                offlineBanner
            }
            circlesSection
            if presenter.selectedCircle != nil {
                circleDetail
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Circles")
                .font(TyfeTypography.display)
                .tracking(-1.6)

            Text("Private accountability, when you want it.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var offlineBanner: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            TyfeStatusView(kind: .offline, onRetry: { presenter.onRetry() })
            if let lastSyncedText = presenter.lastSyncedText {
                Text("Last synced \(lastSyncedText)")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
    }

    private var circlesSection: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            Text("Your Circles")
                .font(TyfeTypography.interfaceStrong)

            if presenter.circles.isEmpty {
                TyfeStatusView(kind: .empty)
            } else {
                TyfeCirclePillRowView(
                    circles: presenter.circles,
                    selectedCircleId: presenter.selectedCircleId,
                    onSelect: { presenter.onSelectCircle($0) }
                )
            }

            HStack(spacing: TyfeSpacing.small) {
                TyfeActionButtonView(
                    title: "New Circle",
                    systemImage: "plus",
                    role: .primary,
                    onTap: { presenter.onCreateCircleTapped() }
                )
                TyfeActionButtonView(
                    title: "Join with code",
                    systemImage: "key.fill",
                    role: .secondary,
                    onTap: { presenter.onJoinCircleTapped() }
                )
            }
        }
    }

    private var circleDetail: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            if let circle = presenter.selectedCircle {
                Text(circle.name)
                    .font(TyfeTypography.displayCompact)
            }

            ForEach(presenter.members) { member in
                TyfeCircleMemberRowView(
                    member: member,
                    progress: presenter.memberProgress(for: member.userId),
                    focusStatus: presenter.focusStatus(for: member.userId),
                    isSelf: member.userId == presenter.currentUserId,
                    isViewerOwner: presenter.isSelectedCircleOwner,
                    onCheer: { presenter.onSendCheer($0, to: member.userId) },
                    onRemove: { presenter.onRemoveMember(member.userId) }
                )
            }

            TyfeActionButtonView(
                title: "Invite",
                systemImage: "person.badge.plus",
                role: .primary,
                onTap: { presenter.onGenerateInviteTapped() }
            )

            if !presenter.isSelectedCircleOwner {
                TyfeActionButtonView(
                    title: "Leave Circle",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    role: .destructive,
                    onTap: { presenter.onLeaveCircleTapped() }
                )
            }
        }
    }
}

#Preview("Circles") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.circlesView(router: router, delegate: CirclesDelegate())
    }
}

extension CoreBuilder {

    func circlesView(router: AnyRouter, delegate: CirclesDelegate) -> some View {
        CirclesView(
            presenter: CirclesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {

    func showCirclesView(delegate: CirclesDelegate = CirclesDelegate()) {
        router.showScreen(.push) { router in
            builder.circlesView(router: router, delegate: delegate)
        }
    }
}
