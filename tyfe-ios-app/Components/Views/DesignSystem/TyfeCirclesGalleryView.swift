import SwiftUI

@Observable
@MainActor
final class TyfeCirclesGalleryPresenter {
    let circles = [
        CircleModel(circleId: "circle-family", name: "Family", ownerId: "user-owner", createdAt: .now, updatedAt: .now),
        CircleModel(circleId: "circle-study", name: "Study Group", ownerId: "user-owner", createdAt: .now, updatedAt: .now)
    ]

    let owner = CircleMemberModel(userId: "user-owner", displayName: "You", avatarToken: nil, role: .owner, joinedAt: .now)
    let focusingMember = CircleMemberModel(userId: "user-focus", displayName: "Alex", avatarToken: nil, role: .member, joinedAt: .now)
    let availableMember = CircleMemberModel(userId: "user-idle", displayName: "Jordan", avatarToken: nil, role: .member, joinedAt: .now)
    let quietMember = CircleMemberModel(userId: "user-quiet", displayName: "Sam", avatarToken: nil, role: .member, joinedAt: .now)

    let ownerProgress = CircleMemberProgressModel(
        circleId: "circle-family", userId: "user-owner", displayName: "You", avatarToken: nil,
        isOwner: true, latestDate: "2026-09-13", todayPlanned: 3, todayCompleted: 2,
        sevenDayCompleted: 11, cheersToday: 1, progressUpdatedAt: .now
    )
    let focusingProgress = CircleMemberProgressModel(
        circleId: "circle-family", userId: "user-focus", displayName: "Alex", avatarToken: nil,
        isOwner: false, latestDate: "2026-09-13", todayPlanned: 4, todayCompleted: 4,
        sevenDayCompleted: 18, cheersToday: 2, progressUpdatedAt: .now
    )
    let availableProgress = CircleMemberProgressModel(
        circleId: "circle-family", userId: "user-idle", displayName: "Jordan", avatarToken: nil,
        isOwner: false, latestDate: "2026-09-13", todayPlanned: 3, todayCompleted: 1,
        sevenDayCompleted: 5, cheersToday: 0, progressUpdatedAt: .now
    )
    let quietProgress = CircleMemberProgressModel(
        circleId: "circle-family", userId: "user-quiet", displayName: "Sam", avatarToken: nil,
        isOwner: false, latestDate: "2026-09-12", todayPlanned: 2, todayCompleted: 2,
        sevenDayCompleted: 9, cheersToday: 0, progressUpdatedAt: .now
    )

    let inviteCode = "ABCD2345"
    let errorMessage = "That invite code has expired or was already used."

    init() {}
}

struct TyfeCirclesGalleryView: View {
    @State private var presenter: TyfeCirclesGalleryPresenter
    @State private var sheetValue = ""

    init(presenter: TyfeCirclesGalleryPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                galleryHeader
                enableSection
                statusSection
                selectionSection
                ownerDetailSection
                memberDetailSection
                inviteSection
                sheetSection
                errorSection
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.vertical, TyfeSpacing.card)
        }
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .navigationTitle("Circles gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var galleryHeader: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Circles view states")
                .font(TyfeTypography.displayCompact)
            Text("Mock-only review surface for every Circles state.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var enableSection: some View {
        gallerySection("Local-only · enable") {
            TyfeCircleEnableCardView(onEnable: {})
        }
    }

    private var statusSection: some View {
        gallerySection("Loading · Offline · Empty · Error") {
            TyfeStatusView(kind: .loading)
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                TyfeStatusView(kind: .offline, onRetry: {})
                Text("Last synced 5 minutes ago")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
            TyfeStatusView(kind: .empty)
        }
    }

    private var selectionSection: some View {
        gallerySection("Circle selection") {
            Text("Your Circles")
                .font(TyfeTypography.interfaceStrong)
            TyfeCirclePillRowView(
                circles: presenter.circles,
                selectedCircleId: presenter.circles.first?.circleId,
                onSelect: { _ in }
            )
            HStack(spacing: TyfeSpacing.small) {
                TyfeActionButtonView(title: "New Circle", systemImage: "plus", role: .primary, onTap: {})
                TyfeActionButtonView(title: "Join with code", systemImage: "key.fill", role: .secondary, onTap: {})
            }
        }
    }

    private var ownerDetailSection: some View {
        gallerySection("Owner view · members") {
            memberRow(TyfeCirclesGalleryMemberFixture(member: presenter.owner, progress: presenter.ownerProgress, focus: nil, isSelf: true, isViewerOwner: true))
            memberRow(TyfeCirclesGalleryMemberFixture(member: presenter.focusingMember, progress: presenter.focusingProgress, focus: .focusing, isSelf: false, isViewerOwner: true))
            memberRow(TyfeCirclesGalleryMemberFixture(member: presenter.availableMember, progress: presenter.availableProgress, focus: .available, isSelf: false, isViewerOwner: true))
            memberRow(TyfeCirclesGalleryMemberFixture(member: presenter.quietMember, progress: presenter.quietProgress, focus: nil, isSelf: false, isViewerOwner: true))
            TyfeActionButtonView(title: "Invite", systemImage: "person.badge.plus", role: .primary, onTap: {})
        }
    }

    private var memberDetailSection: some View {
        gallerySection("Member view · non-owner") {
            memberRow(TyfeCirclesGalleryMemberFixture(member: presenter.availableMember, progress: presenter.availableProgress, focus: .available, isSelf: false, isViewerOwner: false))
            TyfeActionButtonView(
                title: "Leave Circle",
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive,
                onTap: {}
            )
        }
    }

    private var inviteSection: some View {
        gallerySection("Invite code") {
            TyfeCircleInviteCardView(code: presenter.inviteCode)
        }
    }

    private var sheetSection: some View {
        gallerySection("Create · Join sheets") {
            TyfeCircleNameSheetCardView(
                label: "Circle name",
                placeholder: "Family",
                value: $sheetValue,
                actionTitle: "Create Circle",
                onSave: {}
            )
            TyfeCircleNameSheetCardView(
                label: "Invite code",
                placeholder: "ABCD2345",
                value: $sheetValue,
                actionTitle: "Join Circle",
                onSave: {}
            )
        }
    }

    private var errorSection: some View {
        gallerySection("Social error") {
            TyfeCircleErrorCardView(message: presenter.errorMessage, onDismiss: {})
        }
    }

    private func memberRow(_ fixture: TyfeCirclesGalleryMemberFixture) -> some View {
        TyfeCircleMemberRowView(
            member: fixture.member,
            progress: fixture.progress,
            focusStatus: fixture.focus,
            isSelf: fixture.isSelf,
            isViewerOwner: fixture.isViewerOwner,
            onCheer: { _ in },
            onRemove: {}
        )
    }

    private func gallerySection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            Text(title)
                .font(TyfeTypography.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(TyfeEditorialPalette.muted)
            content()
        }
    }
}

private struct TyfeCirclesGalleryMemberFixture {
    let member: CircleMemberModel
    let progress: CircleMemberProgressModel?
    let focus: CircleFocusStatus?
    let isSelf: Bool
    let isViewerOwner: Bool
}

#Preview("Circles gallery") {
    NavigationStack {
        TyfeCirclesGalleryView(presenter: TyfeCirclesGalleryPresenter())
    }
}

#Preview("Circles gallery — Dark") {
    NavigationStack {
        TyfeCirclesGalleryView(presenter: TyfeCirclesGalleryPresenter())
    }
    .preferredColorScheme(.dark)
}

#Preview("Circles gallery — Large Dynamic Type") {
    NavigationStack {
        TyfeCirclesGalleryView(presenter: TyfeCirclesGalleryPresenter())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Circles gallery — Reduce Motion") {
    NavigationStack {
        TyfeCirclesGalleryView(presenter: TyfeCirclesGalleryPresenter())
    }
    .transaction { transaction in
        transaction.animation = nil
    }
}

#if MOCK || DEV
extension CoreBuilder {
    func circlesGalleryView(router: AnyRouter) -> some View {
        TyfeCirclesGalleryView(presenter: TyfeCirclesGalleryPresenter())
    }
}
#endif
