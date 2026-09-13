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
                        accountCard
                        circlesSection
                        if presenter.selectedCircle != nil {
                            circleDetail
                        }
                        blockedSection
                    } else {
                        enableCard
                    }
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $presenter.isCreateCirclePresented) {
            nameSheet(
                title: "New Circle",
                placeholder: "Family",
                value: $presenter.createCircleName,
                onSave: { presenter.onSubmitCreateCircle() },
                onCancel: { presenter.isCreateCirclePresented = false }
            )
        }
        .sheet(isPresented: $presenter.isJoinCirclePresented) {
            nameSheet(
                title: "Join a Circle",
                placeholder: "Invite code",
                value: $presenter.joinCode,
                onSave: { presenter.onSubmitJoinCode() },
                onCancel: { presenter.isJoinCirclePresented = false }
            )
        }
        .sheet(isPresented: $presenter.isInvitePresented) {
            inviteSheet
        }
        .alert("Delete account?", isPresented: $presenter.isDeleteAccountConfirmPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { presenter.onConfirmDeleteAccount() }
        } message: {
            Text("This removes your Circles, shared progress, and Cheers from the server. Your private progress stays on this device.")
        }
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

    private var enableCard: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Label("Turn on Circles", systemImage: "person.3.fill")
                    .font(TyfeTypography.displayCompact)

                Text("Circles share only today's planned and completed session counts, an available/focusing status, and Cheers. Activities, notes, credits, and rewards stay private.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeActionButtonView(
                    title: "Turn on Circles",
                    systemImage: "checkmark.circle.fill",
                    role: .primary,
                    onTap: { presenter.onEnableCirclesTapped() }
                )
            }
        }
    }

    private var accountCard: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("Signed in")
                    .font(TyfeTypography.interfaceStrong)

                Text("Cheers today: \(presenter.cheersToday)")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
                    .accessibilityLabel(Text("Cheers today, \(presenter.cheersToday)"))

                Text("Your Circles sync quietly in the background.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.small) {
                    TyfeActionButtonView(
                        title: presenter.globalSharingPaused ? "Resume sharing" : "Pause all sharing",
                        systemImage: presenter.globalSharingPaused ? "play.fill" : "pause.fill",
                        role: .secondary,
                        onTap: { presenter.onToggleGlobalSharing() }
                    )
                    TyfeActionButtonView(
                        title: "Sign out",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        role: .secondary,
                        onTap: { presenter.onSignOutTapped() }
                    )
                }

                TyfeActionButtonView(
                    title: "Delete account",
                    systemImage: "trash",
                    role: .destructive,
                    onTap: { presenter.onDeleteAccountTapped() }
                )
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
                ScrollView(.horizontal) {
                    HStack(spacing: TyfeSpacing.small) {
                        ForEach(presenter.circles) { circle in
                            Button {
                                presenter.onSelectCircle(circle.circleId)
                            } label: {
                                TyfePillView(
                                    label: circle.name,
                                    systemImage: presenter.selectedCircleId == circle.circleId ? "checkmark.circle.fill" : "person.3",
                                    tone: presenter.selectedCircleId == circle.circleId ? .accent : .neutral
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
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
                memberRow(member)
            }

            HStack(spacing: TyfeSpacing.small) {
                TyfeActionButtonView(
                    title: "Invite",
                    systemImage: "person.badge.plus",
                    role: .primary,
                    onTap: { presenter.onGenerateInviteTapped() }
                )
                TyfeActionButtonView(
                    title: presenter.selectedCircleSharingPaused ? "Resume this Circle" : "Pause this Circle",
                    systemImage: presenter.selectedCircleSharingPaused ? "play.fill" : "pause.fill",
                    role: .secondary,
                    onTap: { presenter.onToggleCircleSharing() }
                )
            }

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

    private func memberRow(_ member: CircleMemberModel) -> some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                memberHeader(member)
                memberProgress(member)
                if member.userId != presenter.currentUserId {
                    memberActions(member)
                }
            }
        }
    }

    private func memberHeader(_ member: CircleMemberModel) -> some View {
        HStack {
            Text(member.displayName)
                .font(TyfeTypography.interfaceStrong)
            if member.role == .owner {
                TyfePillView(label: "Owner", systemImage: "crown.fill", tone: .warning)
            }
            Spacer()
            if let status = presenter.focusStatus(for: member.userId) {
                TyfePillView(
                    label: status.displayName,
                    systemImage: status.symbolName,
                    tone: status == .focusing ? .accent : .neutral
                )
            }
        }
    }

    @ViewBuilder
    private func memberProgress(_ member: CircleMemberModel) -> some View {
        if let progress = presenter.memberProgress(for: member.userId) {
            Text("Today \(progress.todayCompleted)/\(progress.todayPlanned) · 7 days \(progress.sevenDayCompleted)")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private func memberActions(_ member: CircleMemberModel) -> some View {
        HStack(spacing: TyfeSpacing.small) {
            cheerMenu(member)
            if presenter.isSelectedCircleOwner {
                Button("Remove", role: .destructive) {
                    presenter.onRemoveMember(member.userId)
                }
                .font(TyfeTypography.caption)
            }
            if presenter.blockedUserIds.contains(member.userId) {
                Button("Unblock") { presenter.onUnblockUser(member.userId) }
                    .font(TyfeTypography.caption)
            } else {
                Button("Block", role: .destructive) { presenter.onBlockUser(member.userId) }
                    .font(TyfeTypography.caption)
            }
        }
    }

    private func cheerMenu(_ member: CircleMemberModel) -> some View {
        Menu {
            ForEach(CheerKind.allCases, id: \.self) { kind in
                Button {
                    presenter.onSendCheer(kind, to: member.userId)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        } label: {
            Label("Cheer", systemImage: "hands.clap")
                .font(TyfeTypography.caption)
        }
    }

    private var blockedSection: some View {
        Group {
            if !presenter.blockedUserIds.isEmpty {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    Text("Blocked")
                        .font(TyfeTypography.interfaceStrong)
                    TyfeSurfaceView(role: .paper) {
                        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                            ForEach(presenter.blockedUserIds, id: \.self) { userId in
                                HStack {
                                    Text(userId)
                                        .font(TyfeTypography.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Button("Unblock") { presenter.onUnblockUser(userId) }
                                        .font(TyfeTypography.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var inviteSheet: some View {
        VStack(spacing: TyfeSpacing.control) {
            Text("Invite code")
                .font(TyfeTypography.displayCompact)
            Text(presenter.inviteCode ?? "")
                .font(TyfeTypography.timer)
                .textSelection(.enabled)
                .accessibilityLabel(Text("Invite code \(presenter.inviteCode ?? "")"))
            Text("Single use. Expires in 7 days.")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
            TyfeActionButtonView(title: "Done", role: .primary, onTap: { presenter.onDismissInvite() })
        }
        .padding(TyfeSpacing.card)
        .presentationDetents([.medium])
    }

    private func nameSheet(
        title: String,
        placeholder: String,
        value: Binding<String>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(spacing: TyfeSpacing.control) {
            Text(title)
                .font(TyfeTypography.displayCompact)
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            HStack(spacing: TyfeSpacing.small) {
                TyfeActionButtonView(title: "Cancel", role: .secondary, onTap: onCancel)
                TyfeActionButtonView(
                    title: "Save",
                    role: .primary,
                    isEnabled: !value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onTap: onSave
                )
            }
        }
        .padding(TyfeSpacing.card)
        .presentationDetents([.medium])
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
