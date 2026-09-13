import SwiftUI
import Testing
@testable import tyfe_ios_app

struct DesignSystemTests {

    @Test func primitiveComponentsAcceptInjectedData() {
        let surface = TyfeSurfaceView(role: .paper) {
            Text("Surface")
        }
        let action = TyfeActionButtonView(
            title: "Start",
            systemImage: "play.fill",
            role: .primary,
            onTap: {}
        )
        let pill = TyfePillView(
            label: "Focusing",
            systemImage: "timer",
            tone: .success
        )
        let metric = TyfeMetricCardView(
            title: "Credits",
            value: "2",
            detail: "available",
            systemImage: "circle.fill",
            accent: TyfeEditorialPalette.saffron
        )
        let badge = TyfeStateBadgeView(state: .paused)

        _ = Group {
            surface
            action
            pill
            metric
            badge
        }
    }

    @Test func phaseOneComponentsAcceptDomainFixtures() {
        let activity = TyfeActivityCardView(
            activity: .mock,
            sessionCount: 1,
            timeBlock: nil,
            onStart: {}
        )
        let timer = TyfeFocusTimerView(
            session: .pausedMock,
            activityTitle: "Study Swift",
            timeText: "04:32",
            onBegin: {},
            onPause: {},
            onResume: {},
            onAbandon: {}
        )
        let status = TyfeStatusView(kind: .offline, onRetry: {})
        let motif = TyfeMotifView(kind: .completion)

        _ = Group {
            activity
            timer
            status
            motif
        }
    }

    @Test func rewardsComponentsAcceptDomainFixtures() {
        let reward = TyfeRewardCardView(reward: .mock, balance: 2, onTap: {})
        let readyClaim = TyfeClaimCardView(
            claim: .mock,
            remainingSeconds: 0,
            endText: "3:05 PM",
            onStart: {}
        )
        let activeClaim = TyfeClaimCardView(
            claim: .activeMock,
            remainingSeconds: 300,
            endText: "3:05 PM",
            onStart: {}
        )
        let tiers = TyfeTierLegendView()
        let statusBar = TyfeRewardStatusBarView(
            title: "Reward in progress",
            timeText: "12:30",
            systemImage: "clock.fill"
        )

        _ = Group {
            reward
            readyClaim
            activeClaim
            tiers
            statusBar
        }
    }

    @Test func circlesCardsAcceptDomainFixtures() {
        let enable = TyfeCircleEnableCardView(onEnable: {})
        let pills = TyfeCirclePillRowView(
            circles: [CircleModel(circleId: "c1", name: "Family", ownerId: "u1", createdAt: .now, updatedAt: .now)],
            selectedCircleId: "c1",
            onSelect: { _ in }
        )
        let blocked = TyfeCircleBlockedListView(blockedUserIds: ["u3"], onUnblock: { _ in })
        let invite = TyfeCircleInviteCardView(code: "ABCD2345", onDone: {})
        let sheet = TyfeCircleNameSheetCardView(
            title: "New Circle",
            placeholder: "Family",
            value: .constant(""),
            onSave: {},
            onCancel: {}
        )
        let error = TyfeCircleErrorCardView(message: "Expired", onDismiss: {})

        _ = Group {
            enable
            pills
            blocked
            invite
            sheet
            error
        }
    }

    @Test func circleMemberRowAcceptsDomainFixtures() {
        let member = CircleMemberModel(
            userId: "u2",
            displayName: "Alex",
            avatarToken: nil,
            role: .member,
            joinedAt: .now
        )
        let progress = CircleMemberProgressModel(
            circleId: "c1",
            userId: "u2",
            displayName: "Alex",
            avatarToken: nil,
            isOwner: false,
            latestDate: "2026-09-13",
            todayPlanned: 3,
            todayCompleted: 1,
            sevenDayCompleted: 4,
            cheersToday: 0,
            progressUpdatedAt: .now
        )
        let memberRow = TyfeCircleMemberRowView(
            member: member,
            progress: progress,
            focusStatus: .focusing,
            isSelf: false,
            isViewerOwner: true,
            isBlocked: false,
            onCheer: { _ in },
            onRemove: {},
            onBlock: {},
            onUnblock: {}
        )

        _ = memberRow
    }
}
